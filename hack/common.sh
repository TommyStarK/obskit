#!/usr/local/bin/bash

declare -a tools=(
	"grafana"
	"grafana-agent"
	"loki"
	"mimir"
	"tempo"
)

__info() {
	timestamp=`TZ=UTC date +%Y-%m-%d.%H:%M:%S`
	echo "[$timestamp] $1"
}

check::binary() {
	! command -v $1 >/dev/null 2>&1 && __info "$1 not found" && exit 1
}

check::status() {
	[ $? -ne 0 ] && __info $1 && exit 1
}
