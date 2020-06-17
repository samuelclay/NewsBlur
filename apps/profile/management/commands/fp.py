from django.core.management.base import BaseCommand
from django.contrib.auth.models import User

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-u", "--username", dest="username", nargs=1, help="Specify user id or username")
        parser.add_argument("-e", "--email", dest="email", nargs=1, help="Specify email if it doesn't exist")

    def handle(self, *args, **options):
        username = options.get('username')
        email = options.get('email')
        user = None
        if username:
            try:
                user = User.objects.get(username__icontains=username)
            except User.MultipleObjectsReturned:
                user = User.objects.get(username__iexact=username)
            except User.DoesNotExist:
                user = User.objects.get(email__iexact=username)
            except User.DoesNotExist:
                print(" ---> No user found at: %s" % username)
        elif email:
            try:
                user = User.objects.get(email__icontains=email)
            except User.MultipleObjectsReturned:
                user = User.objects.get(email__iexact=email)
            except User.MultipleObjectsReturned:
                users = User.objects.filter(email__iexact=email)
                user = users[0]
            except User.DoesNotExist:
                print(" ---> No email found at: %s" % email)
            
        if user:
            email = options.get("email") or user.email
            user.profile.send_forgot_password_email(email)
        else:
            print(" ---> No user/email found at: %s/%s" % (username, email))
            
        