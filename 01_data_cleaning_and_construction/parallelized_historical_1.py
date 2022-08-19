# -*- coding: utf-8 -*-
"""
Created on Thu Oct 28 10:49:28 2021

@author: ys8mz

The purpose of this script to use parallel processing to speed up the process of constructing the standardized historical full-term LMS predictors.
"""


import pickle
import numpy as np
import pandas as pd
import multiprocessing
import datetime as dt

fpath = "~/Box Sync/Clickstream/data/full"



class Historical_1(object):

    def __init__(self, indx):
        self.indx = indx
        self.df_new = pd.read_stata("~\\Box Sync\\Clickstream\\data\\full\\historical_1\\df_new_part{}.dta".format(self.indx))
        self.df2 = pd.read_stata("~\\Box Sync\\Clickstream\\data\\full\\historical_1\\df2_part{}.dta".format(self.indx))
        self.predictor_1 = pickle.load(open("~\\Box Sync\\Clickstream\\data\\full\\historical_1\\predictor_1.p", "rb"))
        self.predictor_2 = pickle.load(open("~\\Box Sync\\Clickstream\\data\\full\\historical_1\\predictor_2.p", "rb"))
        
    def do(self):
        all_target_pairs = [(self.df2.vccsid.iloc[indx], self.df2.target_strm.iloc[indx]) for indx in range(self.df2.shape[0])]
        historical_predictor_values = {}
        for t in all_target_pairs:
            df_sub = self.df_new[self.df_new.vccsid == t[0]]
            df_sub = df_sub[df_sub.strm < t[1]]
            if df_sub.shape[0] > 0:
                df_sub_1 = df_sub.loc[:,self.predictor_1].mean()
                new_d = {a:b for a,b in zip(list(df_sub_1.index), list(df_sub_1))}
                for p in self.predictor_2:
                    df_sub_2 = df_sub[df_sub['has_'+p] == 1]
                    if df_sub_2.shape[0] == 0:
                        new_d['has_'+p] = 0
                        new_d[p] = 0
                    else:
                        new_d['has_'+p] = 1
                        new_d[p] = np.mean(df_sub_2[p])
                historical_predictor_values[t[0]+"-"+str(t[1])] = new_d.copy()
        pickle.dump(historical_predictor_values, open("~\\Box Sync\\Clickstream\\data\\full\\historical_1\\part{}.p".format(self.indx), "wb"))

        
def historical_1_wrapper(q):
    s = Historical_1(q)
    s.do()
    
    
if __name__ == '__main__':
    print("Beginning Time:", dt.datetime.now())
    query_list = [i for i in range(100)]
    pool = multiprocessing.Pool(9) # Use parallel processing to speed up this script
    pool.map(historical_1_wrapper, query_list)
    print("End Time:", dt.datetime.now())