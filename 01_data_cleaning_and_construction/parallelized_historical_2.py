# -*- coding: utf-8 -*-
"""
Created on Thu Oct 28 13:01:38 2021

@author: ys8mz

The purpose of this script to use parallel processing to speed up the process of constructing the standardized historical early-term LMS predictors.
"""


import pickle
import numpy as np
import pandas as pd
import multiprocessing
import datetime as dt

fpath = "~/Box Sync/Clickstream/data/full"



class Historical_2(object):

    def __init__(self, indx):
        self.indx = indx
        self.df3 = pd.read_stata("~\\Box Sync\\Clickstream\\data\\full\\historical_2\\df3_part{}.dta".format(self.indx))
        self.df2 = pd.read_stata("~\\Box Sync\\Clickstream\\data\\full\\historical_2\\df2_part{}.dta".format(self.indx))
        self.predictor_3 = pickle.load(open("~\\Box Sync\\Clickstream\\data\\full\\historical_2\\predictor_3.p", "rb"))
        self.predictor_4 = pickle.load(open("~\\Box Sync\\Clickstream\\data\\full\\historical_2\\predictor_4.p", "rb"))
        
    def do(self):
        all_target_pairs = [(self.df2.vccsid.iloc[indx], self.df2.target_strm.iloc[indx]) for indx in range(self.df2.shape[0])]
        historical_predictor_values_2 = {}
        for t in all_target_pairs:
            df_sub = self.df3[self.df3.vccsid == t[0]]
            df_sub = df_sub[df_sub.strm < t[1]]
            if df_sub.shape[0] > 0:
                df_sub_1 = df_sub.loc[:,self.predictor_3].mean()
                new_d = {a:b for a,b in zip(list(df_sub_1.index), list(df_sub_1))}
                for p in self.predictor_4:
                    df_sub_2 = df_sub[df_sub['has_'+p] == 1]
                    if df_sub_2.shape[0] == 0:
                        new_d['has_'+p] = 0
                        new_d[p] = 0
                    else:
                        new_d['has_'+p] = 1
                        new_d[p] = np.mean(df_sub_2[p])
                historical_predictor_values_2[t[0]+"-"+str(t[1])] = new_d.copy()
        pickle.dump(historical_predictor_values_2, open("~\\Box Sync\\Clickstream\\data\\full\\historical_2\\part{}.p".format(self.indx), "wb"))

        
def historical_2_wrapper(q):
    s = Historical_2(q)
    s.do()
    
    
if __name__ == '__main__':
    print("Beginning Time:", dt.datetime.now())
    query_list = [i for i in range(100)]
    pool = multiprocessing.Pool(9) # Use parallel processing to speed up this script, as the trendline predictors of each student x term can be constructed independently
    pool.map(historical_2_wrapper, query_list)
    print("End Time:", dt.datetime.now())