from django.conf.urls.defaults import *
from apps.statistics import views

urlpatterns = patterns('',
    url(r'^dashboard_graphs', views.dashboard_graphs, name='statistics-graphs'),
)
