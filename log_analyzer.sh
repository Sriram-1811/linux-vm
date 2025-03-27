#Task: Log File Analyzer Script
#Objective:
#Write a Bash script that analyzes system log files, extracts important information, and generates a summary report.

#Requirements:
#User Input & Arguments Handling
#Accepts a log file path as an argument (default: /var/log/syslog).
#Allows filtering by date, keyword, or severity level.

#Variables & Constants
#Store paths, patterns, and output file locations.

#Functions
#count_log_entries(): Count the number of log entries.
#filter_by_keyword(): Extract logs matching a specific keyword.
#filter_by_severity(): Extract logs with severity levels like ERROR, WARNING.
#generate_summary(): Provide a report with counts of different log levels.

#Loops & Conditionals
#Ensure the log file exists before processing.
#If filters are used, apply them iteratively.

#File Handling & Logging
#Save the extracted logs and summary to an output file.

#Process Management
#Allow users to monitor logs in real-time using tail -f.

#!/bin/bash
default_log_file=/var/log/messages
default_result=/tmp/log_analyzer.log

read -p "Enter the  log file that you want to analyze (press enter to use deafault file $default_log_file): " log_file
log_file=${log_file:-$default_log_file}

read -p "enter the date you want to filter (yyyy-mm-dd): " date_f
read -p "enter the keyword you want to filter: " keyword
read -p "enter the severity level like ERROR, WARNING,etc.: " severity
read -p "enter the file path to store the result (press enter to use the default file $default_result): " result
result=${result:-$default_result}

echo "filtering the log file: $log_file"
echo "filtering the file on date: $date_f"
echo "filtering out the keyword: $keyword"
echo "filtering out the severity: $severity"
echo "storing the result in: $result"

count_log_entries() {
        echo "Total log entries:" | tee -a $result
        wc -l < cat "$log_file" | tee -a $result
}

filter_by_keyword() {
        if [[ -n "$keyword" ]]; then
                echo "Filtering logs by keyword: $keyword" | tee -a "$result"
                grep -i "$keyword" "$log_file" | tee -a "$result"
        fi
}

filter_by_severity() {
        if [[ -n "$severity" ]]; then
                echo "Filtering logs by severity: $severity" | tee -a "$result"
                grep -i "$severity" "$log_file" | tee -a "$result"
        fi
}

filter_by_date() {
        if [[ -n "$date_f" ]]; then
                echo "Filtering logs by date: $date_f" | tee -a "$result"
                grep -E "$(date -d "$date_f" '+%b %e')" "$log_file" | tee -a "$result"
        fi
}

main(){
        count_log_entries
        filter_by_keyword
        filter_by_severity
        filter_by_date
}
main
