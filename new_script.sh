#!/bin/bash

apt install figlet
clear
# Global variables
ROOTFS_CREATED=false
v_NUM=0
v_NEW_DIR_NAME=""
CGROUP_CPU_NAME=""
CGROUP_MEMORY_NAME=""
NETWORK_NAMESPACE_NAME=""

# Display header with figlet
function show_header() {
    clear
    if command -v figlet &> /dev/null; then
        figlet "Container Builder"
    else
        echo "=== CONTAINER BUILDER ==="
    fi
    echo "============================"
    echo ""
}

# Change to src directory
function change_to_src() {
    show_header
    echo "Changing to src directory..."
    cd src || { echo "Error: Could not change to src directory"; exit 1; }
    echo "Current directory: $(pwd)"
    echo ""
}

# Counter management
function f_update_counter() { 
    if [[ -f 'CONTAINER_NUMBER.txt' ]]; then
        v_NUM=$(cat 'CONTAINER_NUMBER.txt')
    else
        v_NUM=0
    fi

    v_NUM=$(($v_NUM + 1))
    echo $v_NUM > 'CONTAINER_NUMBER.txt'       
    echo "v_NUM = ${v_NUM}"
}

# Directory name generation
function f_get_new_dir_name() {
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

# Extract root filesystem
function extract_rootfs() {
    show_header
    echo "Extracting root filesystem..."
    
    f_get_new_dir_name
    
    echo "Creating temporary directory..."
    mkdir "${v_NEW_DIR_NAME}_tmp"
    
    echo "Extracting rootfs.tar.gz..."
    tar -vzxf "rootfs.tar.gz" -C "${v_NEW_DIR_NAME}_tmp"
    
    echo "Moving rootfs to ${v_NEW_DIR_NAME}..."
    mv "${v_NEW_DIR_NAME}_tmp/rootfs" "${v_NEW_DIR_NAME}"
    
    echo "Cleaning up temporary directory..."
    rmdir "${v_NEW_DIR_NAME}_tmp"
    
    echo "Creating random device files..."
    mkdir -p "${v_NEW_DIR_NAME}/dev"
    mknod -m 0666 "${v_NEW_DIR_NAME}/dev/random" c 1 8
    mknod -m 0666 "${v_NEW_DIR_NAME}/dev/urandom" c 1 9
    chown root:root "${v_NEW_DIR_NAME}/dev/random" "${v_NEW_DIR_NAME}/dev/urandom"
    
    ROOTFS_CREATED=true
    echo ""
    echo "Root filesystem extraction complete!"
    read -p "Press [Enter] to continue..."
}

function create_cgroups_v2(){
	# Use a unified name
	CGROUP_NAME="csl7510"

	# Create a single cgroup directory
	sudo mkdir /sys/fs/cgroup/${CGROUP_NAME}

	# === CPU LIMIT ===
	# Set 50% CPU quota (50ms of every 100ms)
	echo "50000 100000" | sudo tee /sys/fs/cgroup/${CGROUP_NAME}/cpu.max

	# === MEMORY LIMIT ===
	# Limit RAM to 16 MB
	echo "16777216" | sudo tee /sys/fs/cgroup/${CGROUP_NAME}/memory.max

	# Limit swap to 8 MB (total 24 MB = 16 RAM + 8 swap)
	echo "8388608" | sudo tee /sys/fs/cgroup/${CGROUP_NAME}/memory.swap.max
}


# Create CPU and Memory cgroups with user input
function create_cgroups() {
    if [ "$ROOTFS_CREATED" != "true" ]; then
        show_header
        echo "Error: Please extract root filesystem first (Option 1)"
        read -p "Press [Enter] to continue..."
        return
    fi

    show_header
    echo "Configuring CPU and Memory cgroups"
    echo "----------------------------------"
    
    # Get user input with defaults
    echo "CPU Configuration (values in microseconds):"
    read -p "CPU Period [1000000]: " cpu_period
    cpu_period=${cpu_period:-1000000}
    
    read -p "CPU Quota [500000]: " cpu_quota
    cpu_quota=${cpu_quota:-500000}
    
    echo -e "\nMemory Configuration (values in bytes):"
    read -p "Memory Limit [16777216 (16MB)]: " mem_limit
    mem_limit=${mem_limit:-16777216}
    
    read -p "Memory+Swap Limit [25165824 (24MB)]: " memsw_limit
    memsw_limit=${memsw_limit:-25165824}

    # Create cgroups
    CGROUP_CPU_NAME="csl7510cpu${v_NUM}"
    CGROUP_MEMORY_NAME="csl7510mem${v_NUM}"
    
    echo -e "\nCreating CPU cgroup: ${CGROUP_CPU_NAME}"
    mkdir -p "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}"
    echo "$cpu_period" > "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}/cpu.cfs_period_us"
    echo "$cpu_quota" > "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}/cpu.cfs_quota_us"
    
    echo "Creating Memory cgroup: ${CGROUP_MEMORY_NAME}"
    mkdir -p "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}"
    echo "$mem_limit" > "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}/memory.limit_in_bytes"
    echo "$memsw_limit" > "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}/memory.memsw.limit_in_bytes"

    # Add current process to cgroups
    echo $$ > "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}/cgroup.procs"
    echo $$ > "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}/cgroup.procs"
    
    echo -e "\nCgroups created with configuration:"
    echo "CPU Period: ${cpu_period}μs"
    echo "CPU Quota:  ${cpu_quota}μs"
    echo "Memory Limit:     $(numfmt --to=iec $mem_limit)"
    echo "Memory+Swap Limit: $(numfmt --to=iec $memsw_limit)"
    read -p "Press [Enter] to continue..."
}

# Create network namespace
function create_network_namespace() {
    if [ "$ROOTFS_CREATED" != "true" ]; then
        show_header
        echo "Error: Please extract root filesystem first (Option 1)"
        read -p "Press [Enter] to continue..."
        return
    fi

    show_header
    echo "Creating network namespace..."
    
    NETWORK_NAMESPACE_NAME="csl7510netns${v_NUM}"
    v_VETH0="csl7510vethA${v_NUM}"
    v_VETH1="csl7510vethB${v_NUM}"

    ip netns add "${NETWORK_NAMESPACE_NAME}"
    ip netns exec "${NETWORK_NAMESPACE_NAME}" ip link set dev lo up
    
    ip link add "${v_VETH0}" type veth peer name "${v_VETH1}"
    ip link set "${v_VETH1}" netns "${NETWORK_NAMESPACE_NAME}"

    # Get IP addresses
    if command -v python3 &> /dev/null; then
        v_VETH0_IP="$(python3 IPGenerator.py ${v_NUM} a)"
        v_VETH1_IP="$(python3 IPGenerator.py ${v_NUM} b)"
    else
        v_VETH0_IP="10.0.0.1/24"
        v_VETH1_IP="10.0.0.2/24"
    fi

    if [[ $v_VETH0_IP == ERROR* ]]; then 
        v_VETH0_IP="10.0.0.1/24"
    fi
    if [[ $v_VETH1_IP == ERROR* ]]; then 
        v_VETH1_IP="10.0.0.2/24"
    fi

    ifconfig "${v_VETH0}" "${v_VETH0_IP}" up
    ip netns exec "${NETWORK_NAMESPACE_NAME}" ifconfig "${v_VETH1}" "${v_VETH1_IP}" up
    
    echo -e "\nNetwork configuration:"
    echo "Namespace: ${NETWORK_NAMESPACE_NAME}"
    echo "Host Interface: ${v_VETH0} @ ${v_VETH0_IP}"
    echo "Namespace Interface: ${v_VETH1} @ ${v_VETH1_IP}"
    read -p "Press [Enter] to continue..."
}

# Compile and run container
function compile_and_run() {
    if [ "$ROOTFS_CREATED" != "true" ]; then
        show_header
        echo "Error: Please extract root filesystem first (Option 1)"
        read -p "Press [Enter] to continue..."
        return
    fi

    show_header
    echo "Compiling and running container..."
    make debug
    
    echo -e "\nStarting container with parameters:"
    echo "Root FS: ${v_NEW_DIR_NAME}"
    echo "Hostname: hostname-${v_NEW_DIR_NAME}"
    echo "CPU CGroup: ${CGROUP_CPU_NAME}"
    echo "Memory CGroup: ${CGROUP_MEMORY_NAME}"
    echo "Network Namespace: ${NETWORK_NAMESPACE_NAME}"
    echo "Mount Directory: custom_mount_folder"
    
    ./MyContainer_debug.out \
        "${v_NEW_DIR_NAME}" \
        "hostname-${v_NEW_DIR_NAME}" \
        "${CGROUP_CPU_NAME}" \
        "${CGROUP_MEMORY_NAME}" \
        "${NETWORK_NAMESPACE_NAME}" \
        "custom_mount_folder"
    
    read -p "Press [Enter] to continue..."
}



# Main menu
function main_menu() {
    while true; do
        show_header
        echo "Main Menu:"
        echo "1. Extract Root Filesystem"
        [ "$ROOTFS_CREATED" = "true" ] && {
            echo "2. Configure Cgroups"
            echo "3. Create Network Namespace"
            echo "4. Compile and Run Container"
            echo "5. Exit"
        } || {
            echo "2-4. (Available after root filesystem extraction)"
            echo "5. Exit"
        }
        
        read -p "Enter your choice [1-5]: " choice
        
        case $choice in
            1) extract_rootfs ;;
            2) [ "$ROOTFS_CREATED" = "true" ] && create_cgroups || echo "Invalid option";;
            3) [ "$ROOTFS_CREATED" = "true" ] && create_network_namespace || echo "Invalid option";;
           4) [ "$ROOTFS_CREATED" = "true" ] && compile_and_run || echo "Invalid option";; 
        #    5) [ "$ROOTFS_CREATED" = "true" ] && debug_container || echo "Invalid option";;
       # for testing we will add code later     6) [ "$ROOTFS_CREATED" = "true" ] && test_cpu || echo "Invalid option";;
        #    7) [ "$ROOTFS_CREATED" = "true" ] && test_memory || echo "Invalid option";;
            5) 
                echo "Exiting..."
                exit 0
                ;;
            *) 
                echo "Invalid option. Please try again."
                read -p "Press [Enter] to continue..."
                ;;
        esac
    done
}

# Start the script

change_to_src
main_menu


