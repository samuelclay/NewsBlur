from django.contrib.auth.models import User

def get_user(request):
    if request.user.is_authenticated():
        user = request.user
    else:
        user = User.objects.get(username='conesus')
    return user