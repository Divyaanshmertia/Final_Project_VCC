NETWORK_NAMESPACE_NAME="csl7510netns${v_NUM}"
v_VETH0="csl7510vethA${v_NUM}"
v_VETH1="csl7510vethB${v_NUM}"

# Create a network namespace
ip netns add "${NETWORK_NAMESPACE_NAME}"
# Turn the "lo" interface up
ip netns exec "${NETWORK_NAMESPACE_NAME}" ip link set dev lo up
# Create virtual ethernet A and B
ip link add "${v_VETH0}" type veth peer name "${v_VETH1}"
# veth B to namespace
ip link set "${v_VETH1}" netns "${NETWORK_NAMESPACE_NAME}"

# Find NEW IP address based on ${v_NUM}
v_VETH0_IP="$(python3 IPGenerator.py ${v_NUM} a)"
v_VETH1_IP="$(python3 IPGenerator.py ${v_NUM} b)"

# IMPORTANT: if below checks give error, then set any unused IP address manually using:
# v_VETH0_IP="10.0.0.1/24"
# v_VETH1_IP="10.0.0.2/24"
if [[ $v_VETH0_IP == ERROR* ]]; then echo -e "WARNING: do NOT proceed\n${v_VETH0_IP}"; fi
if [[ $v_VETH1_IP == ERROR* ]]; then echo -e "WARNING: do NOT proceed\n${v_VETH1_IP}"; fi

ifconfig "${v_VETH0}" "${v_VETH0_IP}" up
ip netns exec "${NETWORK_NAMESPACE_NAME}" ifconfig "${v_VETH1}" "${v_VETH1_IP}" up