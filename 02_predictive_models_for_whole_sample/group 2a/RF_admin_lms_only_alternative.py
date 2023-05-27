# This script fits the admin_only and lms_only RF model on all non-first-term observations without imputation of missing values -- just naturally treat missing values as one separate category.

import pickle
import pandas as pd
import numpy as np
from collections import Counter
import sklearn
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import precision_recall_curve, roc_auc_score, confusion_matrix, precision_score, recall_score
from sklearn.model_selection import KFold, StratifiedKFold
from scipy.stats.mstats import gmean
import seaborn as sns
import matplotlib.pyplot as plt
import re
import math


sn_dict = {"Blue Ridge": "BRCC",
           "Central Virginia": "CVCC",
           "Dabney S. Lancaster": "DSLCC",
           "Danville": "DCC",
           "Eastern Shore": "ESCC",
           "Germanna": "GCC",
           'J. Sargeant Reynolds': "JSRCC",
           'John Tyler': "JTCC",
           "Lord Fairfax": "LFCC",
           "Mountain Empire": "MECC",
           "New River": "NRCC",
           "Northern Virginia": "NVCC",
           "Patrick Henry": "PHCC",
           "Paul D. Camp": "PDCCC",
           "Piedmont Virginia": "PVCC",
           "Rappahannock": "RCC",
           "Southside Virginia": "SSVCC",
           "Southwest Virginia": "SWVCC",
           "Thomas Nelson": "TNCC",
           "Tidewater": "TCC",
           "Virginia Highlands": "VHCC",
           "Virginia Western": "VWCC",
           "Wytheville": "WCC"}


df0 = pd.read_stata("LMS_data_final.dta").loc[:,['vccsid','strm', 'college', 'course','section','grade']]
df1 = pd.read_csv("course_specific_predictors_new.csv")
df2 = pd.read_csv("term_specific_predictors_new.csv")
for v in [int(e) for e in np.unique(df2.cip) if e != 0]:
    df2.loc[:,'cip_'+str(v)] = (df2.cip == v).astype(int)
for v in [int(e) for e in np.unique(df2.degree_level) if e != 4]:
    df2.loc[:,'degree_level_'+str(v)] = (df2.degree_level == v).astype(int)
df2 = df2.drop(['cip', 'degree_level'], axis=1)
df3 = pd.read_csv("cluster_specific_predictors.csv")
df4 = pd.read_stata("instructor_related_predictors.dta")
df5 = df0.iloc[:,:5].copy()
df5.loc[:,'college_new'] = df5.college.apply(lambda x: sn_dict[x])
for sn in [e for e in sn_dict.values() if e != "BRCC"]:
    df5.loc[:,'college_'+sn] = (df5.college_new == sn).astype(int)
df5 = df5.drop(['college_new'], axis=1)
df = df0.merge(df1, how='inner', on=['vccsid','strm','college','course','section'])\
.merge(df2, how='inner', on=['vccsid','strm'])\
.merge(df3, how='inner', on=['vccsid','strm','college','course','section'])\
.merge(df4, how='inner', on=['vccsid','strm','college','course','section'])\
.merge(df5, how='inner', on=['vccsid','strm','college','course','section'])
predictors = list(df.columns)[6:]


l4 = [p for p in predictors if re.search("^[A-Z]{3}_[A-Z]{3}$", p)]
for p in l4:
    v = np.min(df[p+"_grade"]) - 1
    df.loc[:, p + "_grade"] = df.apply(lambda x: v if x[p] != 1 else x[p+"_grade"], axis=1)
l5 = ['has_repeat_grade', 'has_prereq_grade', 'has_avg_g_concurrent', 'has_term_gpa_1', 'has_term_gpa_2', 'has_past_avg_grade']
for p in l5:
    v = np.min(df[p.replace("has_", "")]) - 1
    df.loc[:, p.replace("has_", "")] = df.apply(lambda x: v if x[p] != 1 else x[p.replace("has_", "")], axis=1)
predictors = [p for p in predictors if p not in set(l4+l5)]
print(len(predictors))


train_df = df[df.strm != 2212]
test_df = df[df.strm == 2212]
original_train_grade = np.array(train_df.grade)
original_test_grade = np.array(test_df.grade)
train_df.loc[:,'grade'] = train_df.apply(lambda x: 1 if x.loc['grade'] in {'A','B','C'} else 0, axis=1)
test_df.loc[:,'grade'] = test_df.apply(lambda x: 1 if x.loc['grade'] in {'A','B','C'} else 0, axis=1)
print(train_df.shape,test_df.shape)


def create_cv_folds(train, n_fold = 5):
    folds = []
    k_fold = StratifiedKFold(n_splits = n_fold, random_state = 12345, shuffle=True)
    for train_indices, test_indices in k_fold.split(train, train.grade):
        train_part = train.iloc[train_indices,:]
        test_part = train.iloc[test_indices,:]
        X_1 = train_part.loc[:,predictors]
        y_1 = train_part.grade
        X_2 = test_part.loc[:,predictors]
        y_2 = test_part.grade
        folds.append([(X_1.copy(),y_1.copy()),(X_2.copy(),y_2.copy())])
    return folds
five_folds = create_cv_folds(train_df)


def cross_validation_RF(rf_model, folds):
    auc_by_fold = []
    for f in folds:
        X_1 = f[0][0]
        y_1 = f[0][1]
        X_2 = f[1][0]
        y_2 = f[1][1]
        rf_model.fit(X_1,y_1)
        y_2_pred = rf_model.predict_proba(X_2)[:,1]
        auc_by_fold.append(roc_auc_score(y_2,y_2_pred))
    return round(np.mean(auc_by_fold),4)
def calc_cw(y):
    # Calculate the weight of each letter grade to be used in the modeling fitting procedure: the weight is inversely proportional to the square root of the frequency of the letter grade in the training sample
    cw = Counter(y)
    class_weight = {k:np.sqrt(cw.most_common()[0][-1]/v, dtype=np.float32) for k,v in cw.items()}
    return class_weight # The output is a dictionary mapping letter grade to the corresponding weight
	

auc_by_d=[]
running_auc = -math.inf
for d in range(2,36):
    rf = RandomForestClassifier(n_estimators=200, criterion="entropy", 
                                max_depth=d,
                                random_state=0, n_jobs=-1, max_features="auto",
                                class_weight = calc_cw(train_df.grade))
    auc = cross_validation_RF(rf, five_folds)
    auc_by_d.append(auc)
    print("Max_depth =", d)
    print("Mean CV AUC:", auc)
    print("")
    if auc - running_auc >= 0.001:
        running_auc = auc
    else:
        optimal_d = d - 1
        break
else:
    optimal_d = d
print("Optimal max_depth = {}\n\n\n".format(optimal_d))


auc_by_n=[]
running_auc = -math.inf
for n in range(100,320,20):
    rf = RandomForestClassifier(n_estimators=n, criterion="entropy", 
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features="auto",
                                class_weight = calc_cw(train_df.grade))
    auc = cross_validation_RF(rf, five_folds)
    auc_by_n.append(auc)
    print("Number of Trees =", n)
    print("Mean CV Balanced Accuracy:", auc)
    print("")
    if auc - running_auc >= 0.0001:
        running_auc = auc
    else:
        optimal_n = n - 20
        break
else:
    optimal_n = n
print("Optimal n_estimators = {}\n\n\n".format(optimal_n))


auc_by_nf=[]
running_auc = -math.inf
max_nf = int(np.floor(2*np.sqrt(len(predictors))))
for nf in range(2,max_nf+1):
    rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy", 
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features=nf,
                                class_weight = calc_cw(train_df.grade))
    auc = cross_validation_RF(rf, five_folds)
    auc_by_nf.append(auc)
    print("Max_features =", nf)
    print("Mean CV Balanced Accuracy:", auc)
    print("")
    if auc - running_auc >= 0.0005:
        running_auc = auc
    else:
        optimal_nf = nf - 1
        break
else:
    optimal_nf = nf
print("Optimal max_features = {}\n\n\n".format(optimal_nf))


rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy",
                            max_depth=optimal_d,
                            random_state=0, n_jobs=-1, max_features=optimal_nf,
                            class_weight = calc_cw(train_df.grade))
rf.fit(train_df.loc[:,predictors], train_df.grade)
print("Random Forest:")
print("AUC = {}".format(round(roc_auc_score(test_df.grade, rf.predict_proba(test_df.loc[:,predictors])[:,1]),4)))
y_test_pred_rf = rf.predict_proba(test_df.loc[:,predictors])[:,1]
best_threshold = np.sort(y_test_pred_rf)[int(len(y_test_pred_rf) * (1-np.mean(train_df.grade)))-1]


def create_confusion_matrix(y_test_pred, threshold, fname):
    cm_arr = confusion_matrix(y_test, np.where(y_test_pred > threshold, 1, 0))
    cm_df = pd.DataFrame(cm_arr, columns=['Pred_DFW','Pred_ABC'], index=['Actual_DFW', 'Actual_ABC'])
    cm_df.loc[:,''] = cm_df.sum(axis=1)
    cm_df.loc['',:] = cm_df.sum(axis=0)
    print(cm_df)
    print("")
    p1 = cm_df.iloc[1,1]/cm_df.iloc[2,1]
    r1 = cm_df.iloc[1,1]/cm_df.iloc[1,2]
    p0 = cm_df.iloc[0,0]/cm_df.iloc[2,0]
    r0 = cm_df.iloc[0,0]/cm_df.iloc[0,2]    
    print("F1 score for A/B/C = {}".format(round(2*p1*r1/(p1+r1),4)))
    print("F1 score for D/F/W = {}".format(round(2*p0*r0/(p0+r0),4))) 
    cm_df.to_csv(fname + ".csv")
    y_test_pred_bin = np.where(y_test_pred > best_threshold, 1, 0)
    cm_dict = {}
    cm_dict['Pred_DFW'] = Counter(original_test_grade[np.where(y_test_pred_bin==0)[0]])
    cm_dict['Pred_ABC'] = Counter(original_test_grade[np.where(y_test_pred_bin==1)[0]])
    new_cm = pd.DataFrame.from_dict(cm_dict, orient='index').T.loc[['W','F','D','C','B','A'],['Pred_DFW','Pred_ABC']]
    new_cm.index = ["Actual_"+e for e in new_cm.index]
    new_cm.loc[:,''] = new_cm.sum(axis=1)
    new_cm.loc['',:] = new_cm.sum(axis=0)
    new_cm.to_csv(fname + "_6x2.csv")
    return round(p1,4),round(r1,4),round(p0,4),round(r0,4),round(2*p1*r1/(p1+r1),4),round(2*p0*r0/(p0+r0),4)
y_test = np.array(test_df.grade)
print("F1 threshold = {}:\n".format(str(round(best_threshold,4))))
pr_rf = create_confusion_matrix(y_test_pred_rf, best_threshold, "RF_admin_only_cm")
print(pr_rf)


df = pd.read_csv("LMS_data_final_full_new.csv")
predictors = [e for e in list(df.columns)[5:] if e != "grade"]


l1 = [p for p in predictors if p.endswith("_qtr1c") or p.endswith("_qrt1c")]
for p in l1:
    v = np.min(df[p]) - 1
    df.loc[:, p] = df.apply(lambda x: v if x.has_concurrent_qtr1 != 1 else x[p], axis=1)
l2 = [p for p in predictors if p.startswith("prior_") and (p.endswith("_qtr1") or p.endswith("_qrt1")) if p != 'prior_has_qtr1']
for p in l2:
    v = np.min(df[p]) - 1
    df.loc[:, p] = df.apply(lambda x: v if x.prior_has_qtr1 != 1 else x[p], axis=1)
l3 = [p for p in predictors if p.startswith("prior_") and p.endswith("_qtr1") == False and p.endswith("_qrt1") == False if p != 'prior_has_full']
for p in l3:
    v = np.min(df[p]) - 1
    df.loc[:, p] = df.apply(lambda x: v if x.prior_has_full != 1 else x[p], axis=1)
l5 = ['has_assign_sub_cnt_qtr1', 'has_on_time_assign_share_qtr1', 'has_on_time_assign_share_qtr1c', 'has_assign_sub_cnt_qtr1c']
for p in l5:
    v = np.min(df[p.replace("has_", "")]) - 1
    df.loc[:, p.replace("has_", "")] = df.apply(lambda x: v if x[p] != 1 else x[p.replace("has_", "")], axis=1)
l6 = ['prior_has_on_time_assign_share', 'prior_has_assign_sub_cnt', 'prior_has_on_time_assign_share_qtr1', 'prior_has_assign_sub_cnt_qtr1']
for p in l6:
    v = np.min(df[p.replace("prior_has_", "prior_")]) - 1
    df.loc[:, p.replace("prior_has_", "prior_")] = df.apply(lambda x: v if x[p] != 1 else x[p.replace("prior_has_", "prior_")], axis=1)
predictors = [p for p in predictors if p not in set(l5+l6+['has_concurrent_qtr1', 'prior_has_qtr1', 'prior_has_full'])]
print(len(predictors))


train_df = df[df.strm != 2212]
test_df = df[df.strm == 2212]
original_train_grade = np.array(train_df.grade)
original_test_grade = np.array(test_df.grade)
train_df.loc[:,'grade'] = train_df.apply(lambda x: 1 if x.loc['grade'] in {'A','B','C'} else 0, axis=1)
test_df.loc[:,'grade'] = test_df.apply(lambda x: 1 if x.loc['grade'] in {'A','B','C'} else 0, axis=1)
print(train_df.shape,test_df.shape)


def create_cv_folds(train, n_fold = 5):
    folds = []
    k_fold = StratifiedKFold(n_splits = n_fold, random_state = 12345, shuffle=True)
    for train_indices, test_indices in k_fold.split(train, train.grade):
        train_part = train.iloc[train_indices,:]
        test_part = train.iloc[test_indices,:]
        X_1 = train_part.loc[:,predictors]
        y_1 = train_part.grade
        X_2 = test_part.loc[:,predictors]
        y_2 = test_part.grade
        folds.append([(X_1.copy(),y_1.copy()),(X_2.copy(),y_2.copy())])
    return folds
five_folds = create_cv_folds(train_df)


def cross_validation_RF(rf_model, folds):
    auc_by_fold = []
    for f in folds:
        X_1 = f[0][0]
        y_1 = f[0][1]
        X_2 = f[1][0]
        y_2 = f[1][1]
        rf_model.fit(X_1,y_1)
        y_2_pred = rf_model.predict_proba(X_2)[:,1]
        auc_by_fold.append(roc_auc_score(y_2,y_2_pred))
    return round(np.mean(auc_by_fold),4)
def calc_cw(y):
    # Calculate the weight of each letter grade to be used in the modeling fitting procedure: the weight is inversely proportional to the square root of the frequency of the letter grade in the training sample
    cw = Counter(y)
    class_weight = {k:np.sqrt(cw.most_common()[0][-1]/v, dtype=np.float32) for k,v in cw.items()}
    return class_weight # The output is a dictionary mapping letter grade to the corresponding weight
	

auc_by_d=[]
running_auc = -math.inf
for d in range(2,36):
    rf = RandomForestClassifier(n_estimators=200, criterion="entropy", 
                                max_depth=d,
                                random_state=0, n_jobs=-1, max_features="auto",
                                class_weight = calc_cw(train_df.grade))
    auc = cross_validation_RF(rf, five_folds)
    auc_by_d.append(auc)
    print("Max_depth =", d)
    print("Mean CV AUC:", auc)
    print("")
    if auc - running_auc >= 0.001:
        running_auc = auc
    else:
        optimal_d = d - 1
        break
else:
    optimal_d = d
print("Optimal max_depth = {}\n\n\n".format(optimal_d))


auc_by_n=[]
running_auc = -math.inf
for n in range(100,320,20):
    rf = RandomForestClassifier(n_estimators=n, criterion="entropy", 
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features="auto",
                                class_weight = calc_cw(train_df.grade))
    auc = cross_validation_RF(rf, five_folds)
    auc_by_n.append(auc)
    print("Number of Trees =", n)
    print("Mean CV Balanced Accuracy:", auc)
    print("")
    if auc - running_auc >= 0.0001:
        running_auc = auc
    else:
        optimal_n = n - 20
        break
else:
    optimal_n = n
print("Optimal n_estimators = {}\n\n\n".format(optimal_n))


auc_by_nf=[]
running_auc = -math.inf
max_nf = int(np.floor(2*np.sqrt(len(predictors))))
for nf in range(2,max_nf+1):
    rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy", 
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features=nf,
                                class_weight = calc_cw(train_df.grade))
    auc = cross_validation_RF(rf, five_folds)
    auc_by_nf.append(auc)
    print("Max_features =", nf)
    print("Mean CV Balanced Accuracy:", auc)
    print("")
    if auc - running_auc >= 0.0005:
        running_auc = auc
    else:
        optimal_nf = nf - 1
        break
else:
    optimal_nf = nf
print("Optimal max_features = {}\n\n\n".format(optimal_nf))


rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy",
                            max_depth=optimal_d,
                            random_state=0, n_jobs=-1, max_features=optimal_nf,
                            class_weight = calc_cw(train_df.grade))
rf.fit(train_df.loc[:,predictors], train_df.grade)
print("Random Forest:")
print("AUC = {}".format(round(roc_auc_score(test_df.grade, rf.predict_proba(test_df.loc[:,predictors])[:,1]),4)))
y_test_pred_rf = rf.predict_proba(test_df.loc[:,predictors])[:,1]
best_threshold = np.sort(y_test_pred_rf)[int(len(y_test_pred_rf) * (1-np.mean(train_df.grade)))-1]


def create_confusion_matrix(y_test_pred, threshold, fname):
    cm_arr = confusion_matrix(y_test, np.where(y_test_pred > threshold, 1, 0))
    cm_df = pd.DataFrame(cm_arr, columns=['Pred_DFW','Pred_ABC'], index=['Actual_DFW', 'Actual_ABC'])
    cm_df.loc[:,''] = cm_df.sum(axis=1)
    cm_df.loc['',:] = cm_df.sum(axis=0)
    print(cm_df)
    print("")
    p1 = cm_df.iloc[1,1]/cm_df.iloc[2,1]
    r1 = cm_df.iloc[1,1]/cm_df.iloc[1,2]
    p0 = cm_df.iloc[0,0]/cm_df.iloc[2,0]
    r0 = cm_df.iloc[0,0]/cm_df.iloc[0,2]    
    print("F1 score for A/B/C = {}".format(round(2*p1*r1/(p1+r1),4)))
    print("F1 score for D/F/W = {}".format(round(2*p0*r0/(p0+r0),4))) 
    cm_df.to_csv(fname + ".csv")
    y_test_pred_bin = np.where(y_test_pred > best_threshold, 1, 0)
    cm_dict = {}
    cm_dict['Pred_DFW'] = Counter(original_test_grade[np.where(y_test_pred_bin==0)[0]])
    cm_dict['Pred_ABC'] = Counter(original_test_grade[np.where(y_test_pred_bin==1)[0]])
    new_cm = pd.DataFrame.from_dict(cm_dict, orient='index').T.loc[['W','F','D','C','B','A'],['Pred_DFW','Pred_ABC']]
    new_cm.index = ["Actual_"+e for e in new_cm.index]
    new_cm.loc[:,''] = new_cm.sum(axis=1)
    new_cm.loc['',:] = new_cm.sum(axis=0)
    new_cm.to_csv(fname + "_6x2.csv")
    return round(p1,4),round(r1,4),round(p0,4),round(r0,4),round(2*p1*r1/(p1+r1),4),round(2*p0*r0/(p0+r0),4)
y_test = np.array(test_df.grade)
print("F1 threshold = {}:\n".format(str(round(best_threshold,4))))
pr_rf = create_confusion_matrix(y_test_pred_rf, best_threshold, "RF_lms_only_cm")
print(pr_rf)
