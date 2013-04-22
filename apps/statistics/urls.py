from django.conf.urls import *
from apps.statistics import views

urlpatterns = patterns('',
    url(r'^dashboard_graphs', views.dashboard_graphs, name='statistics-graphs'),
    url(r'^feedback_table', views.feedback_table, name='feedback-table'),
)
