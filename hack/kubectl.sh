#!/usr/local/bin/bash

. ${PWD}/hack/common.sh

check::binary kubectl

kubectl::apply() {
	kubectl apply -k ./toolkit/$1/manifests
}

kubectl::context::current() {
	kubectl config current-context
}

kubectl::context::set() {
	kubectl config use-context $1
}

kubectl::delete() {
	kubectl delete -k ./toolkit/$1/manifests
}
