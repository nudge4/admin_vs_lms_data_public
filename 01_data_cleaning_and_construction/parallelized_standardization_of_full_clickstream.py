# -*- coding: utf-8 -*-
"""
Created on Tue Oct 26 19:50:32 2021

@author: ys8mz

The purpose of this script is to use parallel processing to speed up the process of standardizing the historical LMS data by term x college x course x section.
"""

import pandas as pd
from sklearn.preprocessing import StandardScaler
import multiprocessing
import datetime as dt

fpath = "C:/Users/ys8mz/Box Sync/Clickstream/data/full"


class Standardizer(object):

    def __init__(self, indx, r, tb, std_list):
        self.indx = indx
        self.r = r
        self.df = tb
        self.std_list = std_list
        
    def do(self):
        df_sub = self.r.merge(self.df, on = ['strm', 'college', 'course', 'section'], how='inner').copy()
        del self.df
        n0 = df_sub.shape[0]
        scaler = StandardScaler()
        new_1 = scaler.fit_transform(df_sub.loc[:,self.std_list])
        for j,var in enumerate(self.std_list):
            df_sub.loc[:,var] = new_1[:,j]
        for var in ['on_time_assign_share', 'assign_sub_cnt']:
            new_2 = df_sub[df_sub['has_' + var] == 1].loc[:,['strm', 'college', 'course', 'section', 'vccsid', 'has_' + var, var]]
            if new_2.shape[0] == 0:
                pass
            else:
                new_3 = df_sub[df_sub['has_' + var] == 0].loc[:,['strm', 'college', 'course', 'section', 'vccsid', 'has_' + var, var]]
                scaler = StandardScaler()
                new_2.loc[:,var] = scaler.fit_transform(new_2.loc[:,[var]])[:,0]
                new_23 = pd.concat([new_2, new_3])
                df_sub = df_sub.drop(['has_' + var, var], axis=1)
                df_sub = df_sub.merge(new_23, on=['strm', 'college', 'course', 'section','vccsid'], how='inner')
            assert df_sub.shape[0] == n0
        df_sub.loc[:,'section'] = "@@@" + df_sub.section
        df_sub.to_csv(fpath + "/standardized_full/{}.csv".format(self.indx), index=False)

        
def standardizer_wrapper(q):
    s = Standardizer(q[0], q[1], q[2], q[3])
    s.do()
    
    
if __name__ == '__main__':
    print("Beginning Time:", dt.datetime.now())
    std_list = ['tot_click_cnt', 'tot_time',
                'avg_session_len',
                'tot_session_cnt',
                'irreg_session_len',
                'tot_act_day_cnt', 'tot_act_wk_cnt',
                'disc_post_cnt', 'disc_reply_cnt',
                'avg_word_tot', 'avg_depth_post']
    df = pd.read_stata(fpath + "/LMS_data_historical_not_standardized.dta")
    all_pairs = df.loc[:,['strm', 'college', 'course', 'section']].drop_duplicates()
    query_list = [(i,all_pairs.iloc[i:(i+1), :], df, std_list) for i in range(all_pairs.shape[0])]
    pool = multiprocessing.Pool(18) # Use parallel processing to speed up this script, as the trendline predictors of each student x term can be constructed independently
    pool.map(standardizer_wrapper, query_list)
    print("End Time:", dt.datetime.now())