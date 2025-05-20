#Task: Automated Service Health Check Script
#Objective:
#Write a Bash script that monitors the status of critical system services, restarts them if they fail, and logs all actions taken.

#Requirements:
#User Input & Arguments Handling
#Accepts a list of service names as arguments.
#If no arguments are given, monitor a default list of services (nginx, apache2, ssh, etc.).

#Variables & Constants
#Store service names, log file path, and retry limits.

#Functions
#check_service(): Check if a service is active.
#restart_service(): Restart a failed service and log the action.
#log_message(): Log events with timestamps.

#Loops & Conditionals
#Validate that the service exists before checking.
#If a service fails, attempt to restart it up to 3 times.

#File Handling & Logging
#Save service status and restart attempts to a log file.

#Process Management
#Allow users to run the script in monitoring mode (--watch) to check services every X seconds.

#!/bin/bash

default_services=("nginx" "httpd" "sshd")
log_file=/tmp/service_monitor.log
retry_limit=3

if [ $# -gt 0 ]; then # $# represents the number of arguments passed to the script
        target=("$@") # $@ expands to all arguments as separate elements
else
        read -p "enter a list of services that you would like to check. mention it in ( ) and without ," -a user_services
        if [ ${#user_services[@]} -eq 0 ]; then
                target=("${default_services[@]}")
        else
                target=("${user_services[@]}")
        fi

fi

echo "services going to be checked: ${target[@]}"
echo "log file: $log_file"

log_message() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

check_service() {
        log_message "checking the status of the services ${target[@]}"
        for service in "${target[@]}"; do
                log_message "checking status of the service $service..."
                if [ $(systemctl is-active ${service}) = "active" ]; then
                        log_message "$service service is currently active"
                else
                        log_message "$service service is inactive. now we are going to restart the service"
                fi
        done
}

restart_service() {
        log_message "attempting to restart the services: ${target[@]}"
        for service in "${target[@]}"; do
                log_message "restarting the service $service...."
                attempt=1
                while [ $attempt -le $retry_limit ]; do
                        systemctl restart $service | tee -a $log_file
                        sleep 1
                        if systemctl is-active --quiet $service; then
                                log_message "$service restart successfully on attempt $attempt."
                                break
                        else
                                log_message "$service restart failed on attempt $attempt."
                        fi
                        attempt=$((attempt+1))
                done
                if ! systemctl is-active --quiet "$service"; then
                        log_message "ERROR: $service could not be restarted after $retry_limit attempts."
                fi
        done

}

main() {
        check_service
        restart_service
}

main
