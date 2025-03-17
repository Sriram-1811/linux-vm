#!/bin/bash
a="abc"
b="123"
echo "first argument:$1"
echo "second argument:$2"
if [ -e ${file_name} ]; then echo "Exists"; else echo "Not found"; fi
read -p "Enter the file name which you want to serach:" file_name
if [ -e $file_name ]; then echo "Exists"; else echo "Not found"; fi

