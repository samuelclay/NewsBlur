#!/bin/sh

ps aux | grep gunicorn | egrep -v grep | awk '{print $2}' | xargs kill -9