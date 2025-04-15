# Main workflow
f_get_new_dir_name

# Create temp extraction directory
mkdir "${v_NEW_DIR_NAME}_tmp"

# Extract tar.gz
tar --verbose --gzip --extract --file "rootfs.tar.gz" -C "${v_NEW_DIR_NAME}_tmp"

# Move rootfs to final directory
mv "${v_NEW_DIR_NAME}_tmp/rootfs" "${v_NEW_DIR_NAME}"
rmdir "${v_NEW_DIR_NAME}_tmp"

# Create /dev/random and /dev/urandom
mkdir -p "${v_NEW_DIR_NAME}/dev"
mknod -m 0666 "${v_NEW_DIR_NAME}/dev/random" c 1 8
mknod -m 0666 "${v_NEW_DIR_NAME}/dev/urandom" c 1 9
chown root:root "${v_NEW_DIR_NAME}/dev/random" "${v_NEW_DIR_NAME}/dev/urandom"

echo "Setup complete: ${v_NEW_DIR_NAME}"
