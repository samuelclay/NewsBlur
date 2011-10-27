"""
Shows some usage levels and limits for the last and previous 24 hours.
"""
import datetime
from django.core.management.base import BaseCommand
from seacucumber.util import get_boto_ses_connection

class Command(BaseCommand):
    """
    This command shows some really vague usage and quota stats from SES.
    """
    help = "Shows SES usage and quota limits."

    def handle(self, *args, **options):
        """
        Renders the output by piecing together a few methods that do the
        dirty work.
        """
        # AWS SES connection, which can be re-used for each query needed.
        conn = get_boto_ses_connection()
        self._print_quota(conn)
        self._print_daily_stats(conn)
           
    def _print_quota(self, conn):
        """
        Prints some basic quota statistics.
        """
        quota = conn.get_send_quota()
        quota = quota['GetSendQuotaResponse']['GetSendQuotaResult']
        
        print "--- SES Quota ---"
        print "  24 Hour Quota: %s" % quota['Max24HourSend']
        print "  Sent (Last 24 hours): %s" % quota['SentLast24Hours']
        print "  Max sending rate: %s/sec" % quota['MaxSendRate']
        
    def _print_daily_stats(self, conn):
        """
        Prints a Today/Last 24 hour stats section.
        """
        stats = conn.get_send_statistics()
        stats = stats['GetSendStatisticsResponse']['GetSendStatisticsResult']
        stats = stats['SendDataPoints']
        
        today = datetime.date.today()
        yesterday = today - datetime.timedelta(days=1)
        current_day = {'HeaderName': 'Current Day: %s/%s' % (today.month, 
                                                             today.day)}
        prev_day = {'HeaderName': 'Yesterday: %s/%s' % (yesterday.month,
                                                        yesterday.day)}
        
        for data_point in stats:
            if self._is_data_from_today(data_point):
                day_dict = current_day
            else:
                day_dict = prev_day
                
            self._update_day_dict(data_point, day_dict)      

        for day in [current_day, prev_day]:
            print "--- %s ---" % day.get('HeaderName', 0)
            print "  Delivery attempts: %s" % day.get('DeliveryAttempts', 0)
            print "  Bounces: %s" % day.get('Bounces', 0)
            print "  Rejects: %s" % day.get('Rejects', 0)
            print "  Complaints: %s" % day.get('Complaints', 0)
        
    def _is_data_from_today(self, data_point):
        """
        Takes a DataPoint from SESConnection.get_send_statistics() and returns
        True if it is talking about the current date, False if not.
        
        :param dict data_point: The data point to consider.
        :rtype: bool
        :returns: True if this data_point is for today, False if not (probably
            yesterday).
        """
        today = datetime.date.today()
        
        raw_timestr = data_point['Timestamp']
        dtime = datetime.datetime.strptime(raw_timestr, '%Y-%m-%dT%H:%M:%SZ')
        return today.day == dtime.day
    
    def _update_day_dict(self, data_point, day_dict):
        """
        Helper method for :meth:`_print_daily_stats`. Given a data point and
        the correct day dict, update attribs on the dict with the contents
        of the data point.
        
        :param dict data_point: The data point to add to the day's stats dict.
        :param dict day_dict: A stats-tracking dict for a 24 hour period.
        """
        for topic in ['Bounces', 'Complaints', 'DeliveryAttempts', 'Rejects']:
            day_dict[topic] = day_dict.get(topic, 0) + int(data_point[topic])