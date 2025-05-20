#!/bin/bash

read -p "enter the ip (or) dns of the server you want to monitor: " server
logfile="/tmp/network_log.txt"

while true; do
        if ! ping -c 1 -W 2 "$server" &> /dev/null; then #-c will send 1 packet -W wait for the responce for 2 sec, ! says if ping fails to execute, then true you can proceed
                echo "$(date): $server is down!" >> "$logfile"
                break
        else
                echo "$(date): $server is reachable!" >> "$logfile"
                break
        fi
        sleep 10
done
