#Task: User Management Script
#Objective:
#Write a Bash script that automates user account management in a Linux system. The script should allow an administrator to create, delete, lock, and unlock user accounts interactively.

#Requirements:
#User Input & Arguments Handling
#The script should accept an operation (create, delete, lock, unlock) and a username as arguments.
#If arguments are missing, the script should prompt the user for input.

#Variables & Constants
#Store paths for logs and default home directories.

#Functions
#create_user(): Adds a new user, sets a default password, and forces a password change on first login.
#delete_user(): Removes a user and optionally their home directory.
#lock_user(): Locks a user account.
#unlock_user(): Unlocks a user account.

#Loops & Conditionals
#Validate if the user exists before performing operations.
#Use loops to ask for confirmation before deletion.

#File Handling & Logging
#Log all operations performed.

#Process Management
#Check if a user is logged in before deletion.

#!/bin/bash

read -p "Action you would like to commit (create/delete/lock/unlock): " action

read -p "Enter the username: " username

default_logs="/var/log/user_management.log"
read -p "Enter preferred log location (Press Enter for default: $default_logs): " logs
logs=${logs:-$default_logs}

create_user() {
        if id "$username" &>/dev/null; then
                echo "user $username already existed, try using different name."
                echo "$(date) - CREATE - FAILED - user $username already exists" >> "$logs"
                exit 1
        else
                useradd "$username"
                passwd "$username"
                passwd --expire "$username"
                echo "The user $username has been created successfully"
                echo "$(date) - CREATE - SUCCESS - new user $username has been created" >> "$logs"
        fi
}

delete_user() {
        if ! id "$username" &>/dev/null; then
                echo "user $username does not exist."
                echo "$(date) - DELETE - FAILED - user $username does not exist" >> "$logs"
                exit 1
        elif who | grep -w "$username" &>/dev/null; then
                echo "user $username is currently logged in. cannot delete an active user."
                echo "$(date) - DELETE - FAILED - user $username was currently active, cannot delete right now. Try after some time." >> "$logs"
                exit 1
        else
                userdel "$username"
                echo "The user $username has been removed successfully"
                echo "$(date) - DELETE - SUCCESS - user $username was successfully deleted" >> "$logs"
        fi
}

lock_user() {
        if ! id "$username" &>/dev/null; then
                echo "user $username does not exist."
                echo "$(date) - LOCK - FAILED - user $username does not exist" >> "$logs"
                exit 1
        elif who | grep -w "$username" &>/dev/null; then
                echo "user $username is currently Logged in. cannot Lock an active user."
                echo "$(date) - LOCK - FAILED - user $username was currently active, cannot Lock the user right now. Try after some time." >> "$logs"
                exit 1
        else
                usermod -L "$username"
                echo "the user $username has been locked."
                echo "$(date) - LOCK - SUCCESS - user $username was successfully locked" >> "$logs"
        fi
}

unlock_user() {
        if ! id "$username" &>/dev/null; then
                echo "user $username does not exist."
                echo "$(date) - UNLOCK - FAILED - user $username does not exist" >> "$logs"
                exit 1
        else
                usermod -U "$username"
                echo "the user $username has been unlocked. you can try logging now."
                echo "$(date) - UNLOCK - SUCCESS - user $username was successfully unlocked" >> "$logs"
        fi
}

case "$action" in
        create) create_user ;;
        delete) delete_user ;;
        lock)
                lock_user
                ;;
        unlock)
                unlock_user
                ;;
        *)
                echo "invalid option. Please enter create, delete, lock, or unlock. don't use Upper Case letters"
                exit 1 ;; # exit code 1 says to terminate the script if it encounters
esac
