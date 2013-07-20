#!/bin/sh

ps aux | grep update_index | egrep -v grep | awk '{print $2}' | xargs kill > /dev/null 2>&1
python /home/newszeit/newsblur/manage.py update_index &
