#Task: System Information Dashboard Script
#Objective:
#Create an interactive Bash script that displays a summary dashboard of system information like OS, CPU, memory, disk, network, logged-in users, and uptime — all formatted and colored for easy readability.

#Requirements:
#User Input & Arguments Handling
#Optional flag: --save to export the output to a file.
#Optional flag: --json to export the data in JSON format.

#Variables & Constants
#Store colors, system info commands, and paths.

#Functions
#get_os_info(): Display OS name and kernel version.
#get_cpu_info(): Show CPU model and core count.
#get_memory_info(): Show total, used, and free memory.
#get_disk_info(): Show disk usage per mount.
#get_network_info(): Display IP address and active interfaces.
#get_user_info(): Show currently logged-in users.
#get_uptime_info(): Show system uptime and load average.

#Loops & Conditionals
#Use a menu loop to let the user pick what they want to view.
#Use conditionals to validate and format the output or handle flags.

#File Handling & Logging
#If --save is used, output is written to a log file with timestamp.
#If --json is used, convert and save all collected data to a JSON file.

#Formatting & Colors
#Use ANSI colors to create a visually structured output (e.g., green for healthy, red for warning).

#!/bin/bash

set -e #exit on error.

#Colors (constants for ANSI escape codes)
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
orange='\033[0;38;5;208m'
purple='\033[0;35m'
gold='\033[0;38;5;220m'
nc='\033[0m' #no colour (resets colour)

#system info commands
cmd_os="uname -s -r"
cmd_cpu=lscpu
cmd_free="free -h"
cmd_df="df -h"
cmd_ip="ip a"
cmd_who=who
cmd_uptime=uptime

#file paths
mkdir -p /tmp/sys_dashboard

timestamp=$(date +"%Y%m%d_%H%M%S")
log_file=/tmp/sys_dashboard/sysinfo_"$timestamp".log
json_file=/tmp/sys_dashboard/sysinfo_"$timestamp".json

save_output=false
json_output=false
json_data="{}" #Initialize Json data

#function to append to Json data (simple helper)
append_to_json() {
        local key="$1"
        local value="$2"
        json_data=$(echo "$json_data" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
}

#checking command-line arguments
for arg in "$@"; do
        case $arg in
                --save)
                        save_output=true
                        ;;
                --json)
                        json_output=true
                        ;;
                *)
                        echo "Warning: Unknown option '$arg'. Ignored."
                        ;;
        esac
done

# if no argument is provided., asking the user
if [ $# -eq 0 ]; then # $# - no.of arguments
        echo "No options provided. Please choose an action:"
        echo "1) Just show system info"
        echo "2) Save system info to a file"
        echo "3) Save system info as JSON"
        echo "4) Save system info to both file and JSON"
        read -p "Enter your choice (1-4): " user_choice

        case $user_choice in
                2) save_output=true
                        ;;
                3) json_output=true
                        ;;
                4) save_output=true
                        json_output=true
                        ;;
                *) echo "showing system info only"
                        ;;
        esac
fi

echo "System Information Dashboard"
echo "Save to file: $save_output"
echo "Save as JSON: $json_output"

get_os_info() {
        echo -e "${blue}=== OS Information ===${nc}"
        local os_info=$($cmd_os)
        echo -e "${green}OS and Kernel:${nc} ${purple}$os_info${nc}"
        if [ "$save_output" = true ]; then
                echo "=== OS Information ===" | tee -a "$log_file"
                echo "OS and Kernel: $os_info" | tee -a "$log_file"
        fi
        if [ "$json_output" = true ]; then
                append_to_json "os_info" "$os_info"
        fi
}

get_cpu_info() {
        echo -e "${blue}=== CPU Information ===${nc}"
        local cpu_model=$($cmd_cpu | grep "Model name" | awk -F : '{print $2}' | head -n1)
        local cpu_cores=$($cmd_cpu | grep "^CPU(s):" | awk '{print $2}')
        echo -e "${green}CPU Model:${nc} ${yellow}$cpu_model${nc}"
        echo -e "${green}Core Count:${nc} ${gold}$cpu_cores${nc}"
        if [ "$save_output" = true ]; then
                echo "=== CPU Information ===" | tee -a "$log_file"
                echo "CPU Model: $cpu_model" | tee -a "$log_file"
                echo "Core Count: $cpu_cores" | tee -a "$log_file"
        fi
        if [ "$json_output" = true ]; then
                append_to_json "cpu_model" "$cpu_model"
                append_to_json "cpu_cores" "$cpu_cores"
        fi
}

get_memory_info() {
        echo -e "${blue}=== Memory Information ===${nc}"
        local mem_info=$($cmd_free | grep Mem)
        local mem_total=$(echo "$mem_info" | awk '{print $2}')
        local mem_used=$(echo "$mem_info" | awk '{print $3}')
        local mem_free=$(echo "$mem_info" | awk '{print $4}')
        echo -e "${green}Total Memory:${nc} ${yellow}$mem_total${nc}"
        echo -e "${green}Used Memory:${nc} ${yellow}$mem_used${nc}"
        echo -e "${green}Free Memory:${nc} ${green}$mem_free${nc}"

        # Warning if free memory is low (< 10% of total)
        local mem_total_mb=$(free -m | grep Mem | awk '{print $2}')
        local mem_free_mb=$(free -m | grep Mem | awk '{print $4}')
        if [ "$mem_free_mb" -lt "$((mem_total_mb / 10))" ]; then
                echo -e "${orange}Warning: Low free memory!${nc}"
                if [ "$save_output" = true ]; then
                        echo "Warning: Low free memory!" | tee -a "$log_file"
                fi
        fi
        if [ "$save_output" = true ]; then
                echo "=== Memory Information ===" | tee -a "$log_file"
                echo "Total Memory: $mem_total" | tee -a "$log_file"
                echo "Used Memory: $mem_used" | tee -a "$log_file"
                echo "Free Memory: $mem_free" | tee -a "$log_file"
        fi
        if [ "$json_output" = true ]; then
                append_to_json "mem_total" "$mem_total"
                append_to_json "mem_used" "$mem_used"
                append_to_json "mem_free" "$mem_free"
        fi
}

get_disk_info() {
        echo -e "${blue}=== Disk Information ===${nc}"
        local disk_info=$($cmd_df | grep -v '^Filesystem')
        while IFS= read -r line; do
                local mount=$(echo "$line" | awk '{print $6}')
                local used=$(echo "$line" | awk '{print $3}')
                local avail=$(echo "$line" | awk '{print $4}')
                local percent=$(echo "$line" | awk '{print $5}')
                echo -e "${green}Mount:${nc} ${yellow}$mount${nc} | ${green}Used:${nc} ${yellow}$used${nc} | ${green}Available:${nc} ${green}$avail${nc} | ${green}Use%:${nc} ${yellow}$percent${nc}"

                # Warning if usage is over 90%
                local percent_num=$(echo "$percent" | tr -d '%')
                if [ "$percent_num" -gt 90 ]; then
                        echo -e "${orange}Warning: High disk usage on $mount!${nc}"
                        if [ "$save_output" = true ]; then
                                echo "Warning: High disk usage on $mount!" | tee -a "$log_file"
                        fi
                fi
                if [ "$save_output" = true ]; then
                        echo "Mount: $mount | Used: $used | Available: $avail | Use%: $percent" | tee -a "$log_file"
                fi
                if [ "$json_output" = true ]; then
                        append_to_json "disk_$mount" "{\"used\":\"$used\",\"avail\":\"$avail\",\"percent\":\"$percent\"}"
                fi
    done <<< "$disk_info"
}

get_network_info() {
        echo -e "${blue}=== Network Information ===${nc}"
        local interfaces=$($cmd_ip | grep '^[0-9]:' | awk '{print $2}' | tr -d ':')
        if [ -z "$interfaces" ]; then
                echo -e "${red}No active network interfaces found!${nc}"
                if [ "$save_output" = true ]; then
                        echo "No active network interfaces found!" | tee -a "$log_file"
                fi
                if [ "$json_output" = true ]; then
                        append_to_json "network_interfaces" "none"
                fi
                return
        fi
        for iface in $interfaces; do
                local ip=$($cmd_ip | grep "inet.*$iface" | awk '{print $2}' | head -n1)
                if [ -n "$ip" ]; then
                        echo -e "${green}Interface:${nc} ${yellow}$iface${nc} | ${green}IP:${nc} ${yellow}$ip${nc}"
                        if [ "$save_output" = true ]; then
                                echo "Interface: $iface | IP: $ip" | tee -a "$log_file"
                        fi
                        if [ "$json_output" = true ]; then
                                append_to_json "interface_$iface" "$ip"
                        fi
                fi
        done
}

get_user_info() {
        echo -e "${blue}=== Logged-in Users ===${nc}"
        local users=$($cmd_who | awk '{print $1}' | sort | uniq)
        if [ -z "$users" ]; then
                echo -e "${yellow}No users logged in.${nc}"
                if [ "$save_output" = true ]; then
                        echo "No users logged in." | tee -a "$log_file"
                fi
                if [ "$json_output" = true ]; then
                        append_to_json "users" "none"
                fi
                return
        fi
        for user in $users; do
                echo -e "${green}User:${nc} ${yellow}$user${nc}"
                if [ "$save_output" = true ]; then
                        echo "User: $user" | tee -a "$log_file"
                fi
        done
        if [ "$json_output" = true ]; then
           append_to_json "users" "$(echo "$users" | tr '\n' ',')"
        fi
}

get_uptime_info() {
        echo -e "${blue}=== Uptime Information ===${nc}"
        local uptime_info=$($cmd_uptime)
        local uptime=$(echo "$uptime_info" | awk '{print $3}' | tr -d ',')
        local load=$(echo "$uptime_info" | awk '{print $(NF-2), $(NF-1), $NF}')
        echo -e "${green}Uptime:${nc} ${gold}$uptime${nc}"
        echo -e "${green}Load Average:${nc} ${purple}$load${nc}"
        if [ "$save_output" = true ]; then
                echo "=== Uptime Information ===" | tee -a "$log_file"
                echo "Uptime: $uptime" | tee -a "$log_file"
                echo "Load Average: $load" | tee -a "$log_file"
        fi
        if [ "$json_output" = true ]; then
                append_to_json "uptime" "$uptime"
                append_to_json "load_average" "$load"
        fi
}

main() {
        get_os_info
        get_cpu_info
        get_memory_info
        get_disk_info
        get_network_info
        get_user_info
        get_uptime_info
}

menu_loop() {
        while true; do
                echo -e "${blue}=== System Information Dashboard Menu ===${nc}"
                echo "1) OS Information"
                echo "2) CPU Information"
                echo "3) Memory Information"
                echo "4) Disk Information"
                echo "5) Network Information"
                echo "6) Logged-in Users"
                echo "7) Uptime Information"
                echo "8) Show All Information"
                echo "9) Exit"
                read -p "Enter your choice (1-9): " choice
                case $choice in
                        1) get_os_info ;;
                        2) get_cpu_info ;;
                        3) get_memory_info ;;
                        4) get_disk_info ;;
                        5) get_network_info ;;
                        6) get_user_info ;;
                        7) get_uptime_info ;;
                        8) main ;;
                        9) break ;;
                        *) echo -e "${red}Invalid choice. Please enter 1-9.${nc}" ;;
                esac
                echo
        done
}

menu_loop
# Save JSON data if enabled
if [ "$json_output" = true ]; then
        echo "$json_data" | jq . > "$json_file"
        echo "JSON data saved to $json_file"
fi
