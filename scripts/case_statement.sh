#!/bin/bash
echo "1. show date"
echo "2. show uptime"
echo "3. show users"
echo "4. Exit"
read -p "Enter your choice:" choice

case $choice in
	1) date ;;
	2) uptime ;;
	3) who ;;
	4) exit ;;
	*) echo "invalid option!" ;;
esac
