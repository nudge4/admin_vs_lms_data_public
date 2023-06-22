import pandas as pd
from typing import List, Callable
import numpy as np


class Measures:

    def __init__(self, course_dates, study_session, assignment_submission, discussion_post):

        self.df = {}
        self.df['crs_dt'] = course_dates
        self.df['study_session'] = study_session
        self.df['assignment'] = assignment_submission
        self.df['discussion'] = discussion_post

        ### Process study_session table ###
        # Convert timestamps to US/Eastern time
        self.df['study_session']['start_timestamp'] = pd.to_datetime(self.df['study_session']['start_timestamp'],
                                                                     utc=True,
                                                                     infer_datetime_format=True).dt.tz_convert(
            'US/Eastern')
        self.df['study_session']['end_timestamp'] = pd.to_datetime(self.df['study_session']['end_timestamp'], utc=True,
                                                                   infer_datetime_format=True).dt.tz_convert(
            'US/Eastern')
        print('Study session timestamps converted.')

        # Set a cap of 5 hours for any session longer than 5 hours
        self.df['study_session'].loc[
            (self.df['study_session']['end_timestamp'] - self.df['study_session']['start_timestamp']) > pd.Timedelta(
                '5 hours'), 'duration'] = 18000  # 5 hours in seconds

        # Set up table to refernce for term/date/week calculations
        self.study_session = self.df['study_session'].merge(self.df['crs_dt'], how='inner', on='course_id')
        for col in ['start_date', 'end_date']:
            self.study_session[col] = pd.to_datetime(self.study_session[col]).dt.tz_localize('US/Eastern')
        print('Course dates merged with study session converted.')

        # Clean study_session table to only have rows where the start_timestamp is between start_date AND end_date
        self.study_session = self.__loc(self.study_session, lambda df: (df['start_timestamp'] >= df['start_date']) & (
                df['start_timestamp'] <= df['end_date']))
        self.study_session['tot_days'] = (self.study_session.end_date - self.study_session.start_date) / np.timedelta64(
            1, 'D')
        self.study_session['tot_weeks'] = (
                (self.study_session['end_date'] - self.study_session['start_date']) / np.timedelta64(1, 'W')).apply(
            np.ceil)  # If total weeks is not whole, round up

        # Subset of study_session in the first quarter of course period
        self.study_session_q1 = self.study_session
        self.study_session_q1['q1_end_date'] = self.study_session_q1['start_date'] + (
                self.study_session_q1['tot_weeks'] / 4).apply(np.ceil).apply(
            lambda x: pd.Timedelta(x, unit='W'))  # first quarter date
        self.study_session_q1 = self.__loc(self.study_session_q1, lambda df: (
            (df['start_timestamp'] <= df['q1_end_date'])))  # sessions that are within the first quarter

        ### Process assignment table ###
        # Convert timestamps to US/Eastern time
        for col in ['created_at', 'submitted_at', 'assignment_due_at', 'assignment_due_at_overridden']:
            self.df['assignment'][col] = pd.to_datetime(self.df['assignment'][col], utc=True, infer_datetime_format=
            True, errors='coerce').dt.tz_convert('US/Eastern')
        print('Assignment timestamps converted.')

        # Set up table to refernce for term/date/week calculations
        self.df['assignment'] = self.df['assignment'].merge(self.df['crs_dt'], how='inner', on='sis_course_code')
        for col in ['start_date', 'end_date']:
            self.df['assignment'][col] = pd.to_datetime(self.df['assignment'][col], errors='coerce').dt.tz_localize(
                'US/Eastern')
        print('Course dates merged with assignment converted.')

        # Clean table to only have rows where created_at is between start_date AND end_date
        self.df['assignment'] = self.__loc(self.df['assignment'], lambda df: (df['created_at'] >= df['start_date']) & (
                df['created_at'] <= df['end_date']))
        self.df['assignment']['tot_days'] = (self.df['assignment']['end_date'] - self.df['assignment'][
            'start_date']) / np.timedelta64(1, 'D')
        self.df['assignment']['tot_weeks'] = ((self.df['assignment']['end_date'] - self.df['assignment'][
            'start_date']) / np.timedelta64(1, 'W')).apply(np.ceil)  # If total weeks is not whole, rounds up

        ### Process discussion table ###
        # Convert timestamps to US/Eastern time
        for col in ['created_at', 'updated_at', 'deleted_at', 'topic_created_at', 'topic_updated_at',
                    'topic_delayed_post_at']:
            self.df['discussion'][col] = pd.to_datetime(self.df['discussion'][col], utc=True, errors='coerce',
                                                        infer_datetime_format=True).dt.tz_convert('US/Eastern')
        print('Discussion timestamps converted.')

        # Set up table to refernce for term/date/week calculations
        self.df['discussion'] = self.df['discussion'].merge(self.df['crs_dt'], how='inner', on='sis_course_code')
        for col in ['start_date', 'end_date']:
            self.df['discussion'][col] = pd.to_datetime(self.df['discussion'][col], errors='coerce').dt.tz_localize(
                'US/Eastern')
        print('Course dates merged with discussion converted.')

        # Clean table to only have rows where created_at is between start_date AND end_date
        self.df['discussion'] = self.__loc(self.df['discussion'],
                                           lambda df: (df['created_at'] >= df['start_date']) & (
                                                   df['created_at'] <= df['end_date']))
        # Get replies vs posts
        self.replies = self.__loc(self.df['discussion'], lambda df: df['parent_discussion_entry_id'].notnull())
        self.posts = self.__loc(self.df['discussion'], lambda df: df['parent_discussion_entry_id'].isnull())

        ### Create result dataframe
        self.result = self.study_session[['sis_course_code', 'canvas_id']].drop_duplicates()

    def __loc(self, table: pd, f: Callable) -> pd:
        return table.loc[f]


    ### Study session measures BEGIN ###

    def click_count(self):
        df = self.study_session.groupby(['sis_course_code', 'canvas_id'], as_index=False)['event_count'].sum().rename(
            columns={
                'event_count': 'tot_click_cnt'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def session_count(self):
        df = self.study_session.groupby(['sis_course_code', 'canvas_id'], as_index=False).size().rename(
            columns={'size': 'tot_session_cnt'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def total_time(self):
        df = self.study_session.groupby(['sis_course_code', 'canvas_id'], as_index=False)['duration'].sum().rename(
            columns={
                'duration': 'tot_time'})
        df['tot_time'] = df.tot_time.div(60)  # Convert seconds to minutes
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_session_duration(self):
        self.result['avg_session_len'] = self.result['tot_time'] / self.result['tot_session_cnt']

    def avg_clicks(self):
        self.result['avg_click_cnt_per_session'] = self.result['tot_click_cnt'] / self.result['tot_session_cnt']

    def days_active(self):
        df = self.study_session.copy()
        df.loc[:, 'start_timestamp'] = df['start_timestamp'].dt.date
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['start_timestamp'].nunique().rename(columns={
            'start_timestamp': 'tot_act_day_cnt'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_day_duration(self):
        df = self.study_session.groupby(['sis_course_code', 'canvas_id', 'tot_days'], as_index=False)['duration'].sum()
        df['avg_time_per_day'] = (df['duration'] / 60) / df['tot_days']  # duration is seconds -> convert to mins
        self.result = self.result.merge(df[['sis_course_code', 'canvas_id', 'avg_time_per_day']], how='outer',
                                        on=['sis_course_code',
                                            'canvas_id'])

    def logins_halfterm(self):
        df = self.study_session
        df['half_date'] = df['start_date'] + (df['tot_weeks'] / 2).apply(np.ceil).apply(lambda x: pd.Timedelta(x,
                                                                                                               unit='W'))  # Consider when weeks are not even (rounded up to the nearest whole week)
        df = self.__loc(df, lambda df: (df['start_timestamp'] <= df['half_date']))
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False).size().rename(
            columns={'size': 'session_cnt_halfterm'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def start_term_to_first_activity(self):
        df = self.study_session.groupby(['sis_course_code', 'canvas_id', 'start_date'], as_index=False).agg(
            {'start_timestamp': np.min})
        df['time_until_first_act'] = (pd.to_datetime(df.start_timestamp, utc=True,
                                                     infer_datetime_format=True).dt.tz_convert(
            'US/Eastern') - df.start_date) / np.timedelta64(1, 'm')
        df = df[['sis_course_code', 'canvas_id', 'time_until_first_act']]
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def largest_inactivity(self):
        # Start and end dates
        term = self.study_session.drop_duplicates(['sis_course_code', 'canvas_id', 'start_date', 'end_date'])[
            ['sis_course_code', 'canvas_id', 'start_date', 'end_date']]
        first = self.study_session.groupby(['sis_course_code', 'canvas_id'])[['start_timestamp', 'end_timestamp']].agg(
            {'start_timestamp': np.min, 'end_timestamp': np.max})
        first = first.merge(term, how='outer', on=['sis_course_code', 'canvas_id'])
        first['start_inac'] = first['start_timestamp'] - first[
            'start_date']  # gets the inactivity between first start timestamp and start_date
        first['end_inac'] = first['end_date'] - first[
            'end_timestamp']  # gets the inactivity between last end timestamp andd end_date

        # Sort the dataframe in ascending order of start_timestamps
        times = self.study_session.groupby(['sis_course_code', 'canvas_id'])[
            ['start_timestamp', 'end_timestamp']].apply(
            lambda x: x.sort_values(['start_timestamp'])).reset_index()
        times['inactivity'] = times['start_timestamp'] - times['end_timestamp'].shift(1)

        # Merge the inactivity between first inactivity and last inactvity
        df = pd.concat([times[['sis_course_code', 'canvas_id', 'inactivity']],
                        first[['sis_course_code', 'canvas_id', 'start_inac']].rename(
                            columns={'start_inac': 'inactivity'})], ignore_index=True)
        df = pd.concat(
            [df, first[['sis_course_code', 'canvas_id', 'end_inac']].rename(columns={'end_inac': 'inactivity'})],
            ignore_index=True)

        # Get the longest inactvity and convert to minutes
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['inactivity'].max()
        df['inactivity'] = df['inactivity'].dt.total_seconds() / 60
        df = df.rename(columns={'inactivity': 'longest_inact'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def total_participated_weeks(self):
        times = self.study_session.copy()
        times['week'] = times['start_timestamp'].dt.week
        df = times.groupby(['sis_course_code', 'canvas_id'], as_index=False)['week'].nunique().rename(
            columns={'week': 'tot_act_wk_cnt'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def irregularity_study_session_length(self):
        df = self.study_session.groupby(['sis_course_code', 'canvas_id'], as_index=False)['duration'].agg(np.std,
                                                                                                          ddof=1).rename(
            columns={'duration': 'irreg_session_len'})
        df['irreg_session_len'] = df['irreg_session_len'].div(60)  # Convert seconds to minutes
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def irregularity_of_study_interval(self):
        times = self.study_session[['sis_course_code', 'canvas_id', 'start_timestamp', 'end_timestamp']]
        times['time_diff'] = (times['end_timestamp'] - times['start_timestamp']).dt.total_seconds()
        times['time_diff'] = times['time_diff'].div(60)  # Convert seconds to minutes
        df = times.groupby(['sis_course_code', 'canvas_id'], as_index=False)['time_diff'].agg(np.std, ddof=1).rename(
            columns={'time_diff': 'irreg_session_gap'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def cumulative_active_days(self):
        dt = self.study_session[
            ['sis_course_code', 'canvas_id', 'start_timestamp', 'start_date', 'end_date', 'tot_weeks']]
        dt['q2_end_date'] = dt['start_date'] + ((dt['tot_weeks'] / 4).apply(np.ceil) * 2).apply(
            lambda x: pd.Timedelta(x, unit='W'))
        dt['q3_end_date'] = dt['start_date'] + ((dt['tot_weeks'] / 4).apply(np.ceil) * 3).apply(
            lambda x: pd.Timedelta(x, unit='W'))  # third quarter date

        d2 = self.__loc(dt, lambda df: ((df['start_timestamp'] <= df['q2_end_date'])))
        d3 = self.__loc(dt, lambda df: ((df['start_timestamp'] <= df['q3_end_date'])))

        d1 = self.study_session_q1.groupby(['sis_course_code', 'canvas_id'], as_index=False).size().rename(columns={
            'size': 'cum_act_day_cnt_qrt1'})
        d2 = d2.groupby(['sis_course_code', 'canvas_id'], as_index=False).size().rename(columns={
            'size': 'cum_act_day_cnt_qrt2'})
        d3 = d3.groupby(['sis_course_code', 'canvas_id'], as_index=False).size().rename(columns={
            'size': 'cum_act_day_cnt_qrt3'})

        self.result = self.result.merge(d1, how='outer', on=['sis_course_code', 'canvas_id'])
        self.result = self.result.merge(d2, how='outer', on=['sis_course_code', 'canvas_id'])
        self.result = self.result.merge(d3, how='outer', on=['sis_course_code', 'canvas_id'])

    ### Study session measures END ###


    ### Study session measures (Q1) BEGIN ###
    def click_count_quarter(self):
        df = self.study_session_q1
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['event_count'].sum().rename(columns={
            'event_count': 'tot_click_cnt_qrt1'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_clicks_quarter(self):
        df = self.study_session_q1
        ds = df.groupby(['sis_course_code', 'canvas_id'], as_index=False).size().rename(
            columns={'size': 'tot_session_cnt_qrt1'})
        dc = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['event_count'].sum().rename(columns={
            'event_count': 'tot_click_cnt_qrt1'})
        df = ds.merge(dc, how='outer', on=['sis_course_code', 'canvas_id'])
        df['avg_click_cnt_per_session_qrt1'] = df.tot_click_cnt_qrt1 / df.tot_session_cnt_qrt1
        self.result = self.result.merge(df[['sis_course_code', 'canvas_id', 'avg_click_cnt_per_session_qrt1']],
                                        how='outer', on=['sis_course_code', 'canvas_id'])

    def total_time_quarter(self):
        df = self.study_session_q1
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['duration'].sum().rename(
            columns={'duration': 'tot_time_qrt1'})
        df['tot_time_qrt1'] = df.tot_time_qrt1.div(60)
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_session_duration_quarter(self):
        df = self.study_session_q1
        ds = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(
            name='tot_session_cnt_qrt1')
        d_time = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['duration'].sum().rename(
            columns={'duration': 'tot_time_qrt1'})
        df = ds.merge(d_time, how='outer', on=['sis_course_code', 'canvas_id'])
        df['avg_session_len_qrt1'] = (df.tot_time_qrt1.div(60) / df.tot_session_cnt_qrt1)
        self.result = self.result.merge(df[['sis_course_code', 'canvas_id', 'avg_session_len_qrt1']], how='outer',
                                        on=['sis_course_code', 'canvas_id'])

    def avg_day_duration_quarter(self):
        df = self.study_session_q1
        df = df.groupby(['sis_course_code', 'canvas_id', 'tot_days'], as_index=False)['duration'].sum().rename(
            columns={'duration': 'tot_time_qrt1'})
        df['avg_time_per_day_qrt1'] = (
                df.tot_time_qrt1.div(60) / df.tot_days)
        self.result = self.result.merge(df[['sis_course_code', 'canvas_id', 'avg_time_per_day_qrt1']], how='outer',
                                        on=['sis_course_code', 'canvas_id'])

    def largest_inactivity_quarter(self):
        df = self.study_session_q1
        # Start and end dates
        term = df.drop_duplicates(['sis_course_code', 'canvas_id', 'start_date', 'end_date'])[
            ['sis_course_code', 'canvas_id', 'start_date', 'end_date']]
        first = df.groupby(['sis_course_code', 'canvas_id'])[['start_timestamp', 'end_timestamp']].agg(
            {'start_timestamp': np.min, 'end_timestamp': np.max})
        first = first.merge(term, how='outer', on=['sis_course_code', 'canvas_id'])
        first['start_inac'] = first['start_timestamp'] - first[
            'start_date']  # gets the inactivity between first start timestamp and start_date
        first['end_inac'] = first['end_date'] - first[
            'end_timestamp']  # gets the inactivity between last end timestamp andd end_date
        # Sort the dataframe in ascending order of start_timestamps
        times = df.groupby(['sis_course_code', 'canvas_id'])[['start_timestamp', 'end_timestamp']].apply(
            lambda x: x.sort_values(['start_timestamp'])).reset_index()
        times['inactivity'] = times['start_timestamp'] - times['end_timestamp'].shift(1)
        # Merge the inactivity between first inactivity and last inactvity
        df = pd.concat([times[['sis_course_code', 'canvas_id', 'inactivity']],
                        first[['sis_course_code', 'canvas_id', 'start_inac']].rename(
                            columns={'start_inac': 'inactivity'})], ignore_index=True)
        df = pd.concat(
            [df, first[['sis_course_code', 'canvas_id', 'end_inac']].rename(columns={'end_inac': 'inactivity'})],
            ignore_index=True)
        # Gets the longest inactvity and convert to minutes
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['inactivity'].max()
        df['inactivity'] = df['inactivity'].dt.total_seconds() / 60
        df = df.rename(columns={'inactivity': 'longest_inact_qrt1'})
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def irregularity_study_session_length_quarter(self):
        df = self.study_session_q1
        df = df.groupby(['sis_course_code', 'canvas_id'])['duration'].agg(np.std, ddof=1).reset_index(
            name='irreg_session_len_qrt1')
        df['irreg_session_len_qrt1'] = df['irreg_session_len_qrt1'].div(60)  # Convert seconds to minutes
        self.result = self.result.merge(df[['sis_course_code', 'canvas_id', 'irreg_session_len_qrt1']], how='outer',
                                        on=['sis_course_code', 'canvas_id'])


    def irregularity_of_study_interval_quarter(self):
        df = self.study_session_q1
        times = df[['sis_course_code', 'canvas_id', 'start_timestamp', 'end_timestamp']]
        times['time_diff'] = (times['end_timestamp'] - times['start_timestamp']).dt.total_seconds()
        times['time_diff'] = times['time_diff'].div(60)  # Convert seconds to minutes
        df = times.groupby(['sis_course_code', 'canvas_id'])['time_diff'].agg(np.std, ddof=1).reset_index(
            name='irreg_session_gap_qrt1')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    ### Study session measures (Q1) END ###


    ### Discussion measures BEGIN ###

    def disc_post_count(self):
        df = self.posts
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='disc_post_cnt')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def disc_reply_count(self):
        # discussion table
        df = self.replies
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='disc_reply_cnt')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def disc_tot(self):
        df = self.df['discussion']
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='disc_tot_messages')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_wordcount_per_post(self):
        df = self.posts
        df = df.groupby(['sis_course_code', 'canvas_id'])['message'].apply(lambda x: np.mean(x.str.len())).reset_index(
            name='avg_word_post')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_wordcount_per_reply(self):
        df = self.replies
        df = df.groupby(['sis_course_code', 'canvas_id'])['message'].apply(lambda x: np.mean(x.str.len())).reset_index(
            name='avg_word_reply')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_wordcount_tot(self):
        df = self.df['discussion']
        df = df.groupby(['sis_course_code', 'canvas_id'])['message'].apply(lambda x: np.mean(x.str.len())).reset_index(
            name='avg_word_tot')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def avg_post_depth(self):
        df = self.df['discussion']
        dcount = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='disc_post_cnt')
        df = df.groupby(['sis_course_code', 'canvas_id'], as_index=False)['depth'].sum()
        df = df.merge(dcount, how='outer', on=['sis_course_code', 'canvas_id'])
        df['avg_depth_post'] = df.depth / df.disc_post_cnt
        df = df[['sis_course_code', 'canvas_id', 'avg_depth_post']]
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    ### Discussion measures END ###


    ### Assignment measures BEGIN ###

    def assign_sub_cnt(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='assign_sub_cnt')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def assign_sub_cnt_day(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'].dt.hour.between(6, 18)]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='assign_sub_cnt_day')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def assign_sub_cnt_day(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'].notnull() & df['submitted_at'].dt.hour.between(6, 18)]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='assign_sub_cnt_day')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def assign_sub_cnt_pm(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'].notnull() & (df['submitted_at'].dt.hour > 18)]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='assign_sub_cnt_pm')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def assign_sub_cnt_am(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'].notnull() & (df['submitted_at'].dt.hour < 6)]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='assign_sub_cnt_am')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def on_time_assign_cnt(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'] <= df['assignment_due_at_overridden'].combine_first(df['assignment_due_at'])]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='on_time_assign_cnt')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def late_assign_cnt(self):
        df = self.df['assignment']
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'] > df['assignment_due_at_overridden'].combine_first(df['assignment_due_at'])]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='late_assign_cnt')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    def late_assign_cnt_halfterm(self):
        df = self.df['assignment']
        df['half_date'] = df['start_date'] + (df['tot_weeks'] / 2).apply(np.ceil).apply(lambda x: pd.Timedelta(x,
        df = df[df['submission_state'].isin(['graded', 'submitted', 'pending_review'])]
        df = df[df['submitted_at'] <= df['half_date']]
        df = df[df['submitted_at'] > df['assignment_due_at_overridden'].combine_first(df['assignment_due_at'])]
        df = df.groupby(['sis_course_code', 'canvas_id']).size().reset_index(name='late_assign_cnt_halfterm')
        self.result = self.result.merge(df, how='outer', on=['sis_course_code', 'canvas_id'])

    ### Assignment measures END ###


if __name__ == '__main__':
    m1 = Measures(pd.read_csv('term_table.csv'), pd.read_csv('study_session.csv'), pd.read_csv('assignment_submission.csv'),
                  pd.read_csv('discussion_post.csv'))

    m1.click_count()
    m1.session_count()
    m1.total_time()  # in min
    m1.avg_session_duration()  # in minutes
    m1.days_active()
    m1.avg_clicks()
    m1.avg_day_duration()  # in minutes
    m1.logins_halfterm()
    m1.start_term_to_first_activity()  # in minutes
    m1.largest_inactivity()  # in minutes
    m1.total_participated_weeks()
    m1.irregularity_study_session_length()  # in minutes
    m1.irregularity_of_study_interval()  # in minutes
    m1.cumulative_active_days()
    m1.click_count_quarter()
    m1.avg_clicks_quarter()
    m1.total_time_quarter()  # in minutes
    m1.avg_session_duration_quarter()  # in minutes
    m1.avg_day_duration_quarter()  # in minutes
    m1.largest_inactivity_quarter()  # in minutes
    m1.irregularity_study_session_length_quarter()  # in minutes
    m1.irregularity_of_study_interval_quarter()  # in minutes

    m1.assign_sub_cnt()
    m1.assign_sub_cnt_day()
    m1.assign_sub_cnt_pm()
    m1.assign_sub_cnt_am()
    m1.on_time_assign_cnt()
    m1.late_assign_cnt()
    m1.late_assign_cnt_halfterm()

    m1.disc_post_count()
    m1.disc_reply_count()
    m1.disc_tot()
    m1.avg_wordcount_per_post()
    m1.avg_wordcount_per_reply()
    m1.avg_wordcount_tot()
    m1.avg_post_depth()

    m1.result.to_csv('results.csv', index=False)