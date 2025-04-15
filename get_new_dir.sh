#!/bin/bash

# Function to update container number
f_update_counter() { 
    if [[ -f 'CONTAINER_NUMBER.txt' ]]; then
        v_NUM=$(cat 'CONTAINER_NUMBER.txt')
    else
        v_NUM=0
    fi

    v_NUM=$((v_NUM + 1))
    echo "$v_NUM" > 'CONTAINER_NUMBER.txt'       
    echo "v_NUM = ${v_NUM}"
}

# Function to get a new directory name
f_get_new_dir_name() {
    while true; do
        f_update_counter

        v_NEW_DIR_NAME="rootfs_${v_NUM}"
        if [[ -d "${v_NEW_DIR_NAME}" ]]; then
            echo "WARNING: Directory already exists: '${v_NEW_DIR_NAME}'"
        else
            echo "Using Directory Name: '${v_NEW_DIR_NAME}'"
            break
        fi       
    done
}

# Run the function
f_get_new_dir_name
