import stripe, datetime, time
from django.conf import settings

from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from optparse import make_option

from utils import log as logging
from apps.profile.models import Profile, PaymentHistory

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        # make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
        # make_option("-e", "--email", dest="email", nargs=1, help="Specify email if it doesn't exist"),
        make_option("-d", "--days", dest="days", nargs=1, type='int', default=365, help="Number of days to go back"),
        make_option("-o", "--offset", dest="offset", nargs=1, type='int', default=0, help="Offset customer (in date DESC)"),
    )

    def handle(self, *args, **options):
        stripe.api_key = settings.STRIPE_SECRET
        week = datetime.datetime.now() - datetime.timedelta(days=int(options.get('days')))
        failed = []
        limit = 100
        offset = options.get('offset')
        
        ignore_user_ids = [18759, 30189, 64184, 254899, 37485, 260097, 244361, 2386, 133148, 102747, 113990, 67222, 5665, 213213, 274, 10462, 240747, 27473, 37748, 85501, 38646, 242379, 53887, 144792, 249582, 126886, 6337, 258479, 43075, 273339, 24347, 178338, 142873, 82601, 18776, 22356, 37524, 124160, 27551, 34427, 35953, 136492, 45476, 14922, 106089, 15848, 33187, 21913, 19860, 43097, 7257, 101133, 147496, 13500, 26762, 44189, 179498, 90799, 44003, 43825, 43861, 43847, 276609, 43007, 43041, 273707, 29652, 171964, 42045, 173859, 109149, 221251, 42344, 29359, 26284, 29251, 10387, 42502, 42043, 42036, 263720, 77766, 41870, 6589, 25411, 262875, 261455, 24292, 41529, 33303, 41343, 40422, 41146, 5561, 71937, 249531, 260228, 258502, 40883, 40859, 40832, 40608, 259295, 218791, 127438, 27354, 27009, 257426, 257289, 7450, 173558, 25773, 4136, 3404, 2251, 3492, 3397, 24927, 39968, 540, 24281, 24095, 24427, 39899, 39887, 17804, 23613, 116173, 3242, 23388, 2760, 22868, 22640, 39465, 39222, 39424, 39268, 238280, 143982, 21964, 246042, 252087, 202824, 38937, 19715, 38704, 139267, 249644, 38549, 249424, 224057, 248477, 236813, 36822, 189335, 139732, 242454, 18817, 37420, 37435, 178748, 206385, 200703, 233798, 177033, 19706, 244002, 167606, 73054, 50543, 19431, 211439, 239137, 36433, 60146, 167373, 19730, 253812]
        
        while True:
            logging.debug(" ---> At %s" % offset)
            user_ids = PaymentHistory.objects.filter(payment_provider='paypal', 
                          payment_date__gte=week).values('user_id').distinct()[offset:offset+limit]
            user_ids = [u['user_id'] for u in user_ids]
            if not len(user_ids):
                logging.debug("At %s, finished" % offset)
                break
            offset += limit
            for user_id in user_ids:
                if user_id in ignore_user_ids:
                    # ignore_user_ids can be removed after 2016-05-17
                    continue
                try:
                    user = User.objects.get(pk=user_id)
                except User.DoesNotExist:
                    logging.debug(" ***> Couldn't find paypal user_id=%s" % user_id)
                    failed.append(user_id)
                    
                if not user.profile.is_premium:
                    user.profile.activate_premium()
                elif user.payments.all().count() != 1:
                    user.profile.setup_premium_history()
                elif not user.profile.premium_expire:
                    user.profile.setup_premium_history()
                elif user.profile.premium_expire > datetime.datetime.now() + datetime.timedelta(days=365):
                    user.profile.setup_premium_history()
                else:
                    logging.debug(" ---> %s is fine" % user.username)

        return failed

