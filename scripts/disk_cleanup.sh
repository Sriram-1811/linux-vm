#Task: Disk Usage & Cleanup Script
#Objective:
#Write a Bash script that checks disk usage, identifies large files, and provides an option to delete them to free up space.

#Requirements:
#User Input & Arguments Handling
#Accepts a directory path as an argument (default: /).
#Allows specifying a size threshold for large files (default: 100MB).

#Variables & Constants
#Store directory path, size threshold, and log file location.

#Functions
#check_disk_usage(): Display disk usage statistics.
#find_large_files(): Identify files larger than the threshold.
#delete_files(): Prompt the user to delete selected files.

#Loops & Conditionals
#Validate if the directory exists.
#If large files are found, prompt the user in a loop to confirm deletion.

#File Handling & Logging
#Save disk usage reports and deleted files to a log file.

#Process Management
#Prevent deletion of critical system files by excluding system directories

#!/bin/bash

default_directory="/"
default_threshold_size="100M"
log_file="/tmp/disk_cleanup.log"

if [ -n "$1" ] ; then # -n is a string test operator that checks if $1 is not empty.
        directory="$1"
else
        read -p "enter the directory path (press enter for default: '/'): " directory
fi

directory=${directory:-$default_directory}
echo "We are using directory: $directory"

if [ -n "$2" ]; then
        threshold_size="$2"
else
        read -p "enter the threshold size (press enter to enter default: 100M: )" threshold_size
fi

threshold_size=${threshold_size:-$default_threshold_size}
echo "the threshold is set to $threshold_size"

check_disk_usage() {
        echo "$(date) - checking the disk usage of the directory: "$directory"" | tee -a "$log_file"
        du -sh "$directory" | tee -a "$log_file"
}

find_large_files() {
        echo "$(date) - Finding files and directories larger than $threshold_size in $directory" | tee -a "$log_file"
        echo -e "\n--- Large Files (>$threshold_size) ---" | tee -a "$log_file"
        find "$directory" -type f -size +"$threshold_size" -exec ls -lh {} + 2>/dev/null | sort -k 5 -rh | tee -a "$log_file"
        echo -e "\n--- Large Directories ---" | tee -a "$log_file"
        du -sh "$directory"/* 2>/dev/null | sort -hr | tee -a "$log_file"
}

delete_files() {
        read -p "enter the file name you want to remove:" file_name

        # List of critical system directories to exclude
        critical_dirs=("/bin" "/etc" "/lib" "/usr" "/root" "/sys" "/proc")

        if [ -e "$file_name" ]; then
                for dir in "${critical_dirs[@]}"; do
                        if [[ "$file_name" == "$dir"* ]]; then
                                echo "$(date) - warning: cannot delete critical system directory $file_name " | tee -a "$log_file"
                                return
                        fi
                done
                echo "$(date) - removing the file "$file_name"" | tee -a "$log_file"
                rm -rf "$file_name"
        else
                echo "$(date) - the file "$file_name" do not exist enter a valid file name." | tee -a "$log_file"
        fi
}

main() {
        check_disk_usage
        find_large_files

        read -p "Do you want to delete any files? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
                delete_files
        else
                echo "Ok, as your wish. we are not going to delete any files"
        fi
}
main
