#!/bin/bash
IP=${1?Error: no IP given}

while :
do
    curl -s $IP | grep h1 | sed -e 's/^[ \t]*//' -e "s/^<h1>//" -e "s/<\/h1>//"
    sleep 0.3
done