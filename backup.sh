#Write a Bash script that automates the backup of a specified directory, compresses the backup, maintains version history, and deletes older backups based on a retention policy.

#Requirements:

#User Input & Arguments Handling
#Accepts the directory to back up and the retention period as command-line arguments.
#If no retention period is provided, default to 7 days.

#Variables & Constants
#Define variables for source directory, backup location, retention days, and timestamp format.

#Functions
#Create a function to perform the backup.
#Another function to remove old backups based on retention policy.

#Loops & Conditionals
#Use conditionals to validate user input (check if the directory exists).
#Use loops to iterate and delete backups older than the retention period.

#File Handling & Logging
#Log backup and cleanup actions to a file.

# Automation with Cron (optional, bonus)
#Provide an option to schedule the script via cron.

#!/bin/bash

default_backup_dir="$HOME/backups"
retention_days=7
default_log_file="$HOME/backups/backup.log"
timestamp=$(date +"%Y%m%d_%H%M%S")

read -p "enter the source directory to backup:" source_dir

if [[ -z "$source_dir" ]]; then
        echo "error: No source directory provided."
        exit 1
fi

if [[ ! -d "$source_dir" ]]; then
        echo "error: DIrectory '$source_dir' does not exist."
        exit 1
fi

read -p "enter the backup directory (press enter to use default: $default_backup_dir):" backup_dir
backup_dir=${backup_dir:-$default_backup_dir}

mkdir -p "$backup_dir"

read -p "enter the backup file (press enter to use default: $default_log_file):" log_file
log_file=${log_file:-$default_log_file}

echo "Source directory: $source_dir"
echo "backup directory: $backup_dir"
echo "Retention Days: $retention_days"
echo "log file: $log_file"

backup() {
        backup_file="$backup_dir/backup_$(basename "$source_dir")_$timestamp.tar.gz"
        echo "creating backup: $backup_file"

        tar -czvf "$backup_file" "$source_dir" 2>>"$log_file"

        if [[ $? -eq 0 ]]; then # $? this is a special variable that stores exit status of the last executed command
                echo "$(date +"%Y-%m-%d %H:%M:%S") - Backup successful: $backup_file" >> "$log_file"
                echo "Backup completed successfully!"
        else
                echo "$(date +"%Y-%m-%D %H:%M:%S") - Backup failed" >> "$log_file"
                echo "Error: backup failed!"
                exit 1
        fi
}

cleanup() {
        echo "cleaning up backups older than $retention_days days......"

        find "$backup_dir" -type f -mtime +$retention_days -name "backup_*.tar.gz" -exec rm {} \;

        if [[ $? -eq 0 ]]; then
                echo "$(date +"%Y-%m-%d %H:%M:%S") - cleanup successful: Deleted older than $retention_days days" >> "$log_file"
                echo "cleanup completed successfully!"
        else
                echo "$(date +"%Y-%m-%d %H:%M:%S") - cleanup failed!" >> "$log_file"
                echo "Error: cleanup failed!..."
        fi
}

backup
cleanup
