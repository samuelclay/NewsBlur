#!/bin/sh

pkill -9 -f celery

# for i in `ps -o pid,command ax | grep celery | awk '!/awk/ && !/grep/ {print $1}'`
# do
#     if [ "${i}" != "" ]; then
#         print "Killing: ${i}";
#         kill -9 ${i};
#     fi
# done

# ps aux | grep celery | egrep -v grep | awk '{print $2}' | xargs kill -9