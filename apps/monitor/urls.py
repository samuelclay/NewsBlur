from apps.monitor.views.monitor import MongoDBOps, MongoDBSize
from django.conf.urls import url
from apps.monitor.views import ( AppServers, AppTimes,
Classifiers, DbTimes, Errors, FeedCounts, Feeds, LoadTimes,
 Stories, TasksCodes, TasksPipeline, TasksServers, TasksTimes,
 Updates, Users, MongoDBHeapUsage, MongoDBObjects, MongoDBOpsReplsetLag,
 MongoDBSize, MongoDBOps, MongoDBPageFaults, MongoDBPageQueues
)
urlpatterns = [
    url(r'^app-servers?$', AppServers.as_view(), name="app_servers"),
    url(r'^app-times?$', AppTimes.as_view(), name="app_times"),
    url(r'^classifiers?$', Classifiers.as_view(), name="classifiers"),
    url(r'^db-times?$', DbTimes.as_view(), name="db_times"),
    url(r'^errors?$', Errors.as_view(), name="errors"),
    url(r'^feed-counts?$', FeedCounts.as_view(), name="feed_counts"),
    url(r'^feeds?$', Feeds.as_view(), name="feeds"),
    url(r'^load-times?$', LoadTimes.as_view(), name="load_times"),
    url(r'^stories?$', Stories.as_view(), name="stories"),
    url(r'^task-codes?$', TasksCodes.as_view(), name="task_codes"),
    url(r'^task-pipeline?$', TasksPipeline.as_view(), name="task_pipeline"),
    url(r'^task-servers?$', TasksServers.as_view(), name="task_servers"),
    url(r'^task-times?$', TasksTimes.as_view(), name="task_times"),
    url(r'^updates?$', Updates.as_view(), name="updates"),
    url(r'^users?$', Users.as_view(), name="users"),
    url(r'^mongo-heap-usage?$', MongoDBHeapUsage.as_view(), name="mongo_heap_usage"),
    url(r'^mongo-objects?$', MongoDBObjects.as_view(), name="mongo_db_objects"),
    url(r'^mongo-replset-lag?$', MongoDBOpsReplsetLag.as_view(), name="mongo_ops_replset_lag"),
    url(r'^mongo-size?$', MongoDBSize.as_view(), name="mongo_size"),
    url(r'^mongo-ops?$', MongoDBOps.as_view(), name="mongo_ops"),
    url(r'^mongo-page-faults?$', MongoDBPageFaults.as_view(), name="mongo_page_faults"),
    url(r'^mongo-page-queues?$', MongoDBPageQueues.as_view(), name="mongo_page_queues"),
]
