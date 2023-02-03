#!/usr/local/bin/bash

. ${PWD}/hack/common.sh

check::binary helm

declare -A charts=(
	["grafana"]="grafana"
	["grafana-agent"]="grafana-agent"
	["loki"]="loki-distributed"
	["mimir"]="mimir-distributed"
	["tempo"]="tempo-distributed"
)

helm::template() {
	local targets=()
	if [ $# -eq 0 ]; then
		targets=("${tools[@]}")
	else
		targets+=("$1")
	fi

	for target in "${targets[@]}"; do
		local chart="${charts[$target]}"

		if [ -z "$chart" ]; then
			__info "unknown template: $target"
			exit 1
		else
			__info "rendering chart template: $chart"

			rm -rf ./toolkit/$target/manifests/*

			helm template dummy ./toolkit/$target/helm/ --output-dir ./dummy >/dev/null
			check::status

			mv ./dummy/$chart/templates/* ./toolkit/$target/manifests/
			rm -rf dummy
		fi
	done
}
