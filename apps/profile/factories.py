import factory
from factory.django import DjangoModelFactory
from django.contrib.auth.models import User
from apps.profile.models import Profile

class UserFactory(DjangoModelFactory):
    first_name = factory.Faker('first_name')
    last_name = factory.Faker('last_name')
    username = factory.Faker('email')
    date_joined = factory.Faker('date_time')

    class Meta:
        model = User

 

class ProfileFactory(DjangoModelFactory):
    user = factory.SubFactory(UserFactory)
    class Meta:
        model = Profile
