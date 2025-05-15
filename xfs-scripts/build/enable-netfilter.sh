#!/usr/bin/bash

if [[ $# != 1 ]]; then
	echo "Usage: $0 <config file path>"
	exit 1
fi

config_path=$1

dirs=(net/netfilter/
      net/ipv[46]/netfilter
      net/bridge/netfilter
      net/netfilter/ipset)

while read -r opt; do
	case $opt in
		"IP_SET_MAX" | \
		"IP_VS_MH_TAB_INDEX" | \
		"IP_VS_SH_TAB_BITS" | \
		"IP_VS_TAB_BITS")
			echo "Skipping $opt"
			continue
			;;
		*)
			echo "Enabling CONFIG_${opt}"
			./scripts/config --file $config_path -e CONFIG_${opt}
			;;
	esac
done <<< $(find ${dirs[@]} -iname Kconfig | \
		   xargs grep -R -E '^(config|menuconfig)' \
		   | awk '{ print $2; }' | sort | uniq)

./scripts/config --file $config_path -e CONFIG_NETFILTER_ADVANCED

build_basedir=$(basename $config_path)
yes "" | make O=${build_basedir} oldconfig > /dev/null
