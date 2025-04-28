#!/bin/bash

# Prompt user for action
echo "Select an option:"
echo "1) Create a new LVM"
echo "2) Extend an existing LVM"
read -p "Enter your choice (1 or 2): " choice

read -p "Enter the size, that you want to create or size of the lvm: " size

check_free_space() {
        if [[ $(pvs --units G | awk 'NR==2 {print $6}') < $size ]]; then
                echo "warning: not enough space in PVs"
                pvs # to know the user
        fi

        if [[ $(vgs --units G | awk 'NR==2 {print $7}') < $size ]];then
                echo "error: nor enough free space in VGs"
                vgs #to know the user
                echo
                echo "Hint: you may need to add anew disk and create a new physical volume (PV), then create a vg or extend an existing vg"
                echo "Use 'lsblk' to view available disks."
                echo "use 'pvcreate /dev/sdx' first and then run the script."
                exit 1
        fi

        pvs
        echo
        vgs
        echo "listing blocks"
        lsblk
        echo "you were good to go"
}

create_lvm() {
        check_free_space
        read -p "Do you want to create, extend or use an existing one? (create/extend/existing):" vg_action
        read -p "enter the new or existing VG name:" vg_name

        if [[ $vg_action == "create" ]]; then
                lsblk
                read -p "eneter the disk to use for creating the new pv (e.g., /dev/sdb): " disk
                pvcreate "$disk"
                vgcreate "$vg_name" "$disk"
        elif [[ $vg_action == "extend" ]]; then
                lsblk
                read -p "enter the disk to extend the vg (e.g., /dev/sdc): " disk
                pvcreate "$disk"
                vgextend "$vg_name" "$disk"
        elif [[ $vg_action == "existing" ]]; then
                echo "using existing vg: " $vg_name
                vgs "$vg_name"
        else
                echo "Invalid VG action. enter create or extend."
                exit 1
        fi

        read -p "enter the name for the new LVM: " lvm
        lvcreate -L "${size}G" -n "$lvm" "$vg_name"

        echo "Logical volue $lvm created successfully in volume group $vg_name."
        lvdisplay
}

extend_lvm() {
        check_free_space
        read -p "Do you want to create, extend, or use an existing one? (create/extend/existing):" vg_action
        read -p "enter the new or existing VG name:" vg_name

        if [[ $vg_action == "create" ]]; then
                lsblk
                read -p "eneter the disk to use for creating the new pv (e.g., /dev/sdb): " disk
                pvcreate "$disk"
                vgcreate "$vg_name" "$disk"
        elif [[ $vg_action == "extend" ]]; then
                lsblk
                read -p "enter the disk to extend the vg (e.g., /dev/sdc): " disk
                pvcreate "$disk"
                vgextend "$vg_name" "$disk"
        elif [[ $vg_action == "existing" ]]; then
                echo "using existing vg: " $vg_name
                vgs "$vg_name"
        else
                echo "Invalid VG action. enter create or extend."
                exit 1
        fi

        lvdisplay $vg_name
        read -p "enter the name of the LVM to extend: " lvm
        lvextend -L +${size}G "/dev/${vg_name}/${lvm}"

        echo "Logical Volume $lvm extended successfully."
        lvdisplay "/dev/${vg_name}/${lvm}"
}

case $choice in
        1)
                echo "Creating a new LVM..."
                create_lvm
                ;;
        2)
                echo "Extending an existing LVM..."
                extend_lvm
                ;;
        *)
                echo "Invalid option. Please select 1 or 2."
                ;;
esac
