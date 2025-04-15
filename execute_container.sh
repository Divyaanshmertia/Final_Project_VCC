make debug
./MyContainer_debug.out "${v_NEW_DIR_NAME}" "hostname-${v_NEW_DIR_NAME}" \
    "${CGROUP_CPU_NAME}" "${CGROUP_MEMORY_NAME}" \
    "${NETWORK_NAMESPACE_NAME}" "custom_mount_folder"