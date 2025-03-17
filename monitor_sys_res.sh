#!/bin/bash

cpu_threshold=1
memory_threshold=5
email=belovoj494@isorax.com

cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
memory_usage=$(free | awk '/Mem/{print int($3/$2*100)}')

if (( cpu_usage > cpu_threshold)); then
	echo "high CPU Usage: ${cpu_usage}% detected!" | mail -s "CPU Alert" $email
fi
if (( memory_usage > memory_threshold)); then
	echo "high Memory Usage: ${memory_usage}% detected!" | mail -s "Memory Alert" $email
fi
