import os
import time

import requests
from locust import HttpUser, between, task


class NB_PerfTest(HttpUser):
    wait_time = between(1, 2.5)

    @task
    def homepage(self):
        url = "/"
        self.client.get(url, verify=False)

    @task
    def river(self):
        url = "/api#/reader/river_stories"
        self.client.get(url, verify=False)

    @task
    def load_single_feed(self):
        url = "/site/1186180/best-of-metafilter"
