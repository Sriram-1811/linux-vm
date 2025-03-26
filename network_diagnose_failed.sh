#Task: Network Diagnostics & Troubleshooting Script
#Objective:
#Write a Bash script that helps diagnose network issues by performing common troubleshooting steps such as checking connectivity, resolving DNS, and measuring response times.

#Requirements:
#User Input & Arguments Handling
#Accepts a domain or IP address as an argument.
#If no argument is provided, prompt the user to enter a target.

#Variables & Constants
#Store log file paths, timeout values, and common troubleshooting commands.

#Functions
#check_ping(): Check if the target is reachable.
#check_dns(): Resolve the domain name to an IP address.
#check_traceroute(): Display the network path to the target.
#check_ports(): Scan common open ports using nc or nmap.

#Loops & Conditionals
#Validate input before proceeding.
#If a step fails, suggest corrective actions.

#File Handling & Logging
#Save results of each test to a log file for review.

#Process Management
#Check if the system has network connectivity before running tests.

#!/bin/bash

log_file=/tmp/network_diagnostics.log
timeout=5
common_ports=(80 443 22 53)
ping_cmd="ping -c 4"
traceroute_cmd="traceroute"
dns_cmd="nslookup"
port_scan_cmd="nc -zv"

echo "log file: $log_file"
echo "timeout: $timeout"
echo "common ports: ${common_ports[@]}"
echo "ping command: $ping_cmd"
echo "traceroute command: $traceroute_cmd"
echo "DNS command: $dns_cmd"
echo "port scan command: $port_scan_cmd"

if [ -n "$1" ]; then #-n is a string test operator that checks if $1 is not empty.
        target="$1"
else
        read -p "enter a domain or IP address: " target
fi

if [ -z "$target" ]; then
        echo "Error: No target provided."
        exit 1
fi

echo "target set to: $target"

check_system_connectivity() {
        echo "checking system internet connectivity..." | tee -a "$log_file"
        ping -c 2 8.8.8.8 &> /dev/null

        if [ $? -eq 0 ]; then
                echo "system has internet access." | tee -a "$log_file"
        else
                echo "no internet access detected. Exiting the script!" | tee -a "$log_file"
                exit 1
        fi
}

check_ping() {
        echo "Checking connectivity to $target..." | tee -a "$log_file"
        $ping_cmd "$target" | tee -a "$log_file"

        if [ $? -eq 0 ]; then
                echo "Ping successful!" | tee -a "$log_file"
        else
                echo "ping failed. the host may be unreachable." | tee -a "$log_file"
        fi
}

check_dns() {
        echo "Checking DNS resolution of the $target..." | tee -a "$log_file"
        $dns_cmd "$target" | tee -a "$log_file"

        if [ $? -eq 0 ]; then
                echo "DNS resolution successful!" | tee -a "$log_file"
        else
                echo "DNS resolution failed. the domain may not exist or there could be a network issue." | tee -a "$log_file"
        fi
}

check_traceroute() {
        echo "Checking routing of the $target... using traceroute" | tee -a "$log_file"
        timeout "$timeout" $traceroute_cmd "$target" | tee -a "$log_file" #sometimes traceroute take long time, that's why we need timeout

        if [ $? -eq 0 ]; then
                echo "Traceroute command executed successfully" | tee -a "$log_file"
        else
                echo "routing failed, somehow we are unable to reach the server." | tee -a "$log_file"
        fi
}

check_ports() {
        echo "checking common ports on $target..." | tee -a $log_file

        for port in "${common_ports[@]}"; do
                echo "scanning port $port..." | tee -a "$log_file"
                nc -zv "$target" "$port" &>> "$log_file"

                if [ $? -eq 0 ]; then
                        echo "port $port is open!" | tee -a "$log_file"
                else
                        echo "port $port is closed or filtered." | tee -a "$log_file"
                fi
        done
}

show_summary() {
    echo "******* Network Diagnostics Summary *******" | tee -a "$log_file"
    grep -iE "Ping successful|DNS resolution successful|Traceroute command executed successfully|Port .* is open" "$log_file" | tee -a "$log_file"
}

main() {
        check_system_connectivity
        check_ping
        check_dns
        check_traceroute
        check_ports
        show_summary
}

main
