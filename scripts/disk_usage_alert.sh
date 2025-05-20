#!/bin/bash
threshold=80
usage=$(df / | awk 'NR==2 {print $5}'| sed 's/%//')
echo "current usage is $usage%"
echo
if ((usage >= threshold)); then 
	echo "warning: Disk usage is above $threshold"
fi
