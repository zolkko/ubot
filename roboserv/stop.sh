#!/bin/bash

pid=$(dirname $0)/roboserv.pid
if [ -e ${pid} ]
then
    kill -s SIGTERM $(cat $pid)
fi

