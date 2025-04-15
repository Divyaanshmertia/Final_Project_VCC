CGROUP_CPU_NAME="csl7510cpu"
mkdir "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}"
# With 1 second period, 0.5 second quota will be equivalent to 50% of 1 CPU
echo "1000000" > "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}/cpu.cfs_period_us"
echo "500000" > "/sys/fs/cgroup/cpu/${CGROUP_CPU_NAME}/cpu.cfs_quota_us"

# REFER: https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt
CGROUP_MEMORY_NAME="csl7510mem"
mkdir "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}"
# set limit of memory usage      = 16 MB = 16 * 1024 * 1024 = 16777216
# set limit of memory+Swap usage = 24 MB = 24 * 1024 * 1024 = 25165824
echo "16777216" > "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}/memory.limit_in_bytes"
echo "25165824" > "/sys/fs/cgroup/memory/${CGROUP_MEMORY_NAME}/memory.memsw.limit_in_bytes"
