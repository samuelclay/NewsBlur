#!/bin/sh

ps aux | grep celery | egrep -v grep | awk '{print $2}' | xargs kill -9