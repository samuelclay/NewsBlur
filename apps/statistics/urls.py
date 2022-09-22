from django.conf.urls import *
from apps.statistics import views

urlpatterns = [
    url(r'^dashboard_graphs', views.dashboard_graphs, name='statistics-graphs'),
    url(r'^feedback_table', views.feedback_table, name='feedback-table'),
    url(r'^revenue', views.revenue, name='revenue'),
    url(r'^slow', views.slow, name='slow'),
]
