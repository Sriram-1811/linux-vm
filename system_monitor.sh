#Write a Bash script named system_monitor.sh that performs the following tasks:

#Requirements
#User Input & Arguments Handling
#The script should accept command-line arguments to define log file path (default: /var/log/system_monitor.log).

#Variables & Constants
#Define necessary variables (e.g., thresholds for disk usage, CPU load, RAM usage).

#Functions
#Use functions to modularize tasks (e.g., checking CPU load, disk usage, memory usage, process count).

#Loops & Conditionals
#Use loops to monitor system parameters continuously (until the user stops it).
#Implement conditionals to check if a threshold is exceeded and take action.

#File Handling & Logging
#Log the monitoring results to a file.

#Process Management
#Show running processes and allow the user to kill a process if it consumes too much CPU/RAM.

#Automation with Cron (optional, bonus)
#Provide an option to set the script to run at regular intervals via cron.

#!/bin/bash
# Default log file path
DEFAULT_LOG_FILE="/var/log/system_monitor.log"

# Prompt user for log file path (or use default)
read -p "Enter log file path (Press Enter to use default: $DEFAULT_LOG_FILE): " LOG_FILE

# Use default if input is empty
LOG_FILE=${LOG_FILE:-$DEFAULT_LOG_FILE}

# Display the chosen log file path
echo "Using log file: $LOG_FILE"

# Define threshold values
cpu_threshold=80
ram_threshold=90
disk_threshold=95

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
# here '-' is just used as a separator, $1 given as argument, eg log_message "this text is taken as argument, it will be replaced in the place of $1"

check_cpu() {
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)
        #Log Usage
        log_message "CPU Usage: ${cpu_usage}%"

        # Checking if CPU usage exceeds the threshold
        if (( cpu_usage >= cpu_threshold )); then
                log_message "Alert: High CPU usage detected!!! ${cpu_usage}%"
        fi
}

check_ram() {
        ram_usage=$(free | awk '/Mem/{print int($3/$2*100)}')
        #Log usage
        log_message "RAM Usage: ${ram_usage}%"

        # Checking if RAM usage is exceeded or not
        if (( ram_usage >= ram_threshold )); then
                log_message "Alert: High RAM usage detected!!! ${ram_usage}%"
        fi
}

check_disk() {
        disk_usage=$(df / | awk 'NR==2 {print $5}'| sed 's/%//')
        #Log Usage
        log_message "Disk Usage: ${disk_usage}%"

        #checking if disk usage is exceeded or not
        if (( disk_usage >= disk_threshold )); then
                log_message "Alert: High Disk usage detected!!! ${disk_usage}%"
        fi
}

#creating a fuction for process management
manage_processes() {
    log_message "Listing top resource-consuming processes..."

    echo "Top 5 CPU-consuming processes:"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6

    echo "Top 5 RAM-consuming processes:"
    ps -eo pid,comm,%mem --sort=-%mem | head -n 6

    read -p "Do you want to terminate any process? (y/n): " choice

    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        read -p "Enter the PID of the process to terminate: " pid
        if [[ "$pid" -eq $(ps "$pid" | awk 'NR==2 {print $1}') ]]; then
            kill -9 "$pid"
            log_message "Process $pid terminated."
        else
            echo "Invalid PID. No such process exists."
        fi
    elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
        echo "Process termination skipped."
    else
        echo "Invalid choice. Please enter 'y' or 'n'."
    fi
}

# Continuous Monitoring Loop until user stop.
while true; do
    log_message "Checking system health..."

    check_cpu
    check_ram
    check_disk
    manage_processes

    log_message "Monitoring cycle completed. Sleeping for 5 seconds..."
    sleep 5  # Wait for 5 seconds for every cycle
done
