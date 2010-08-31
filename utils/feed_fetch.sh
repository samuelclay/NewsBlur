#!/bin/sh

ps aux | grep refresh_feeds | egrep -v grep | awk '{print $2}' | xargs kill > /dev/null 2>&1
python /home/conesus/newsblur/manage.py refresh_feeds -s &
python /home/conesus/newsblur/manage.py refresh_feeds -s &
python /home/conesus/newsblur/manage.py refresh_feeds -s &
python /home/conesus/newsblur/manage.py refresh_feeds -s &
python /home/conesus/newsblur/manage.py refresh_feeds -s &
python /home/conesus/newsblur/manage.py refresh_feeds -s &
