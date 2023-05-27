# This script fits the full-predictor multinomial random forests model using all non-first-term observations.

import pickle
import pandas as pd
import numpy as np
from collections import Counter
import sklearn
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import precision_recall_curve, roc_auc_score, confusion_matrix, precision_score, recall_score
from sklearn.model_selection import KFold, StratifiedKFold, cross_val_score
from scipy.stats.mstats import gmean
import seaborn as sns
import matplotlib.pyplot as plt
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
		   

df0 = pd.read_csv("LMS_data_final_full_new.csv")
df1 = pd.read_csv("course_specific_predictors_new.csv")
df2 = pd.read_csv("term_specific_predictors_new.csv")
for v in [int(e) for e in np.unique(df2.cip) if e != 0]:
    df2.loc[:,'cip_'+str(v)] = (df2.cip == v).astype(int)
for v in [int(e) for e in np.unique(df2.degree_level) if e != 4]:
    df2.loc[:,'degree_level_'+str(v)] = (df2.degree_level == v).astype(int)
df2 = df2.drop(['cip', 'degree_level'], axis=1)
df3 = pd.read_csv("cluster_specific_predictors.csv")
df4 = pd.read_stata("instructor_related_predictors.dta")
df5 = df0.loc[:,['vccsid','strm','college','course','section']].copy()
df5.loc[:,'college_new'] = df5.college.apply(lambda x: sn_dict[x])
for sn in [e for e in sn_dict.values() if e != "BRCC"]:
    df5.loc[:,'college_'+sn] = (df5.college_new == sn).astype(int)
df5 = df5.drop(['college_new'], axis=1)
df = df0.merge(df1, how='inner', on=['vccsid','strm','college','course','section'])\
.merge(df2, how='inner', on=['vccsid','strm'])\
.merge(df3, how='inner', on=['vccsid','strm','college','course','section'])\
.merge(df4, how='inner', on=['vccsid','strm','college','course','section'])\
.merge(df5, how='inner', on=['vccsid','strm','college','course','section'])
predictors = [e for e in list(df.columns)[5:] if e != "grade"]


assert pd.isnull(df).any().any() == False


train_df = df[df.strm != 2212]
test_df = df[df.strm == 2212]


k_fold = StratifiedKFold(n_splits=5, random_state = 12345, shuffle=True)


def calc_cw(y):
    # Calculate the weight of each letter grade to be used in the modeling fitting procedure: the weight is inversely proportional to the square root of the frequency of the letter grade in the training sample
    cw = Counter(y)
    class_weight = {k:np.sqrt(cw.most_common()[0][-1]/v, dtype=np.float32) for k,v in cw.items()}
    return class_weight # The output is a dictionary mapping letter grade to the corresponding weight
	
	
### Using grid search to find the optimal maximum tree depth
ba_by_d=[]
running_ba = -math.inf
for d in range(2,31):
    rf = RandomForestClassifier(n_estimators=200, criterion="entropy", 
                                max_depth=d,
                                random_state=0, n_jobs=-1, max_features="auto",
                                class_weight = calc_cw(train_df.grade))
    val_score = cross_val_score(rf, train_df.loc[:,predictors], train_df.grade, cv=k_fold, scoring="balanced_accuracy")
    ba_by_d.append(np.mean(val_score))
    print("Max_depth =", d)
    print("Mean CV Balanced Accuracy:", round(np.mean(val_score), 4))
    print("")
    if np.mean(val_score) - running_ba >= 0.0001:
        running_ba = np.mean(val_score)
    else:
        optimal_d = d - 1
        break
else:
    optimal_d = d
print("Optimal max_depth = {}\n\n\n".format(optimal_d))


### Using grid search to find the optimal maximum tree depth
ba_by_n=[]
running_ba = -math.inf
for n in range(100,320,20):
    rf = RandomForestClassifier(n_estimators=n, criterion="entropy", 
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features="auto",
                                class_weight = calc_cw(train_df.grade))
    val_score = cross_val_score(rf, train_df.loc[:,predictors], train_df.grade, cv=k_fold, scoring="balanced_accuracy")
    ba_by_n.append(np.mean(val_score))
    print("Number of Trees =", n)
    print("Mean CV Balanced Accuracy:", round(np.mean(val_score), 4))
    print("")
    if np.mean(val_score) - running_ba >= 0.0001:
        running_ba = np.mean(val_score)
    else:
        optimal_n = n - 10
        break
else:
    optimal_n = n
print("Optimal n_estimators = {}\n\n\n".format(optimal_n))


### Using grid search to find the optimal maximum tree depth
ba_by_nf=[]
running_ba = -math.inf
max_nf = int(np.floor(2*np.sqrt(len(predictors))))
for nf in range(2,max_nf+1):
    rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy", 
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features=nf,
                                class_weight = calc_cw(train_df.grade))
    val_score = cross_val_score(rf, train_df.loc[:,predictors], train_df.grade, cv=k_fold, scoring="balanced_accuracy")
    ba_by_nf.append(round(np.mean(val_score),4))
    print("Max_features =", nf)
    print("Mean CV Balanced Accuracy:", round(np.mean(val_score), 4))
    print("")
    if np.mean(val_score) - running_ba >= 0.0001:
        running_ba = np.mean(val_score)
    else:
        optimal_nf = nf - 1
        break
else:
    optimal_nf = nf
print("Optimal max_features = {}\n\n\n".format(optimal_nf))


full_y = []
full_w_proba = []
full_pred_score = []
for train_indices, test_indices in k_fold.split(train_df, train_df.grade):
    train_part = train_df.iloc[train_indices,:]
    test_part = train_df.iloc[test_indices,:]
    X_1 = train_part.loc[:,predictors]
    y_1 = train_part.grade
    X_2 = test_part.loc[:,predictors]
    y_2 = test_part.grade
    rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy",
                                max_depth=optimal_d,
                                random_state=0, n_jobs=-1, max_features=optimal_nf,
                                class_weight = calc_cw(train_df.grade))
    rf.fit(X_1, y_1)
    raw_predictions = rf.predict_proba(X_2)
    w_proba = raw_predictions[:,-1]
    g_proba = raw_predictions[:,:-1]
    g_pred = 4 - g_proba.argmax(axis=1)
    pred_score = g_pred*5+np.dot(g_proba, np.array([4,3,2,1,0]))
    full_y.extend(y_2)
    full_w_proba.extend(w_proba)
    full_pred_score.extend(pred_score)
w_threshold = np.array(full_w_proba)[np.argsort(full_w_proba)[::-1]][Counter(full_y)['W']]


nw_pred_score = np.array(full_pred_score)[np.argsort(full_w_proba)[::-1][Counter(full_y)['W']:]]
nw_y = np.array(full_y)[np.argsort(full_w_proba)[::-1][Counter(full_y)['W']:]]
g_cnt = Counter([e for e in full_y if e != "W"]) # Count the total number of each letter grade in the entire training sample
tl = []
indx = 0
ranked_indices = np.argsort(nw_pred_score)[::-1] # Find the indices of the concatenated predicted score list, in an increasing order
# Find the cut-off values for predicted scores for letter grade D,C,B,A respectively:
# So that when using those cut-off values to convert predicted scores into predicted letter grades,
# in total the distribution of predicted letter grades will be equal to the distribution of actual letter grades
# in the entire training sample
for i in ['A','B','C','D']: 
    indx += g_cnt[i] # The number of courses corresponding to the numeric grade i
    tl.append(nw_pred_score[ranked_indices[indx-1]]) # y_pred[ranked_indices[indx-1]] corresponds to the highest predicted score that we should assign numeric grade i, which aligns with the cut-off value above which we'll predict numeric grade as i+1 
    print(nw_pred_score[ranked_indices[indx-1]])
tl = tl[::-1]
# The 4 cut-off values will be used to determine the predicted letter grades for courses in the validation sample,
# as well as the predicted letter grades of potential eligible courses to be recommended to students


def cal_grade(s):
    # Convert predicted score into the calibrated letter grade based on the cut-off values found through cross-validation
    if s > tl[3]:
        return "A"
    elif s > tl[2]:
        return "B"
    elif s > tl[1]:
        return "C"
    elif s > tl[0]:
        return "D"
    else:
        return "F"
		
		
rf = RandomForestClassifier(n_estimators=optimal_n, criterion="entropy",
                            max_depth=optimal_d,
                            random_state=0, n_jobs=-1, max_features=optimal_nf,
                            class_weight = calc_cw(train_df.grade))
rf.fit(train_df.loc[:,predictors], train_df.grade)
raw_predictions = rf.predict_proba(test_df.loc[:,predictors])
w_proba = raw_predictions[:,-1]
g_proba = raw_predictions[:,:-1]
g_pred = 4 - g_proba.argmax(axis=1)
pred_score = g_pred*5+np.dot(g_proba, np.array([4,3,2,1,0]))
pred_grade = np.where(np.array(w_proba) >= w_threshold, "W", "NW")
new_pred_grade = []
for indx,g in enumerate(pred_grade):
    if g == "W":
        new_pred_grade.append(g)
    else:
        new_pred_grade.append(cal_grade(pred_score[indx]))
		

cm = confusion_matrix(test_df.grade, new_pred_grade, labels = ['A','B','C','D','F','W'])
cm_df = pd.DataFrame(cm, columns = ['pred_' + g for g in ['A','B','C','D','F','W']],
                     index = ['real_' + g for g in ['A','B','C','D','F','W']])
cm_df.loc[:,""] = cm_df.sum(axis=1)
cm_df.loc["",:] = cm_df.sum(axis=0)		
cm_df_new = pd.DataFrame({"Pred_ABC": cm_df.iloc[:,:3].sum(axis=1), "Pred_DFW":cm_df.iloc[:,3:6].sum(axis=1), "":cm_df.iloc[:,-1]}).loc[["real_W","real_F","real_D","real_C","real_B","real_A",""],['Pred_DFW','Pred_ABC',""]]
cm_df_new.index = [e.replace("real_", "Actual_") for e in list(cm_df_new.index)]
print("\n\n\n")
print(cm_df_new)
cm_df_new.to_csv("RF_3_full_cm_6x2.csv")