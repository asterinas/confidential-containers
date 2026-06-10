#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root_dir="$(cd "${script_dir}/../../" && pwd)"
source "${repo_root_dir}/tools/scripts/asterinas-coco-defaults.sh"

KATA_SOURCE_DIR="${KATA_SOURCE_DIR:?KATA_SOURCE_DIR must be set}"
ROOTFS_DIR="${ROOTFS_DIR:?ROOTFS_DIR must be set}"
OUTPUT_INITRD_PATH="${OUTPUT_INITRD_PATH:?OUTPUT_INITRD_PATH must be set}"
OUTPUT_ROOTFS_IMAGE_PATH="${OUTPUT_ROOTFS_IMAGE_PATH:-}"
COCO_GUEST_COMPONENTS_TARBALL="${COCO_GUEST_COMPONENTS_TARBALL:?COCO_GUEST_COMPONENTS_TARBALL must be set}"
PAUSE_IMAGE_TARBALL="${PAUSE_IMAGE_TARBALL:?PAUSE_IMAGE_TARBALL must be set}"
DEFAULT_COCO_LOCAL_REGISTRY_CA="${repo_root_dir}/tools/docker/config/local-registry-certs/ca.crt"
COCO_LOCAL_REGISTRY_CA="${COCO_LOCAL_REGISTRY_CA:-${DEFAULT_COCO_LOCAL_REGISTRY_CA}}"
DISTRO="${DISTRO:-ubuntu}"
OS_VERSION="${OS_VERSION:-noble}"
ROOTFS_IMAGE_BUILDER_PATCH="${ROOTFS_IMAGE_BUILDER_PATCH:-${script_dir}/patches/kata-image-builder-ext2.patch}"
CDH_CONFIG_DIR="${CDH_CONFIG_DIR:-${repo_root_dir}/tools/docker/config/cdh}"
CONTAINERD_CERTS_DIR="${CONTAINERD_CERTS_DIR:-${repo_root_dir}/tools/docker/config/containerd/certs.d}"

die() {
	echo >&2 "ERROR: $*"
	exit 1
}

require_cmd() {
	local cmd

	for cmd in "$@"; do
		command -v "${cmd}" >/dev/null 2>&1 || die "missing required command: ${cmd}"
	done
}

require_cmd cat cp find git grep install mkdir mv printf rm script sudo tee

[ -d "${KATA_SOURCE_DIR}" ] || die "KATA_SOURCE_DIR does not exist: ${KATA_SOURCE_DIR}"
[ -f "${COCO_GUEST_COMPONENTS_TARBALL}" ] || die "COCO_GUEST_COMPONENTS_TARBALL does not exist: ${COCO_GUEST_COMPONENTS_TARBALL}"
[ -f "${PAUSE_IMAGE_TARBALL}" ] || die "PAUSE_IMAGE_TARBALL does not exist: ${PAUSE_IMAGE_TARBALL}"
[ -f "${CDH_CONFIG_DIR}/confidential-data-hub.toml" ] || die "missing CDH config: ${CDH_CONFIG_DIR}/confidential-data-hub.toml"
[ -f "${CDH_CONFIG_DIR}/registry-configuration.toml" ] || die "missing registry config: ${CDH_CONFIG_DIR}/registry-configuration.toml"
[ -f "${CDH_CONFIG_DIR}/confidential-data-hub-wrapper.sh" ] || die "missing CDH wrapper: ${CDH_CONFIG_DIR}/confidential-data-hub-wrapper.sh"
[ -d "${CONTAINERD_CERTS_DIR}" ] || die "missing containerd certs dir: ${CONTAINERD_CERTS_DIR}"
if [ -n "${COCO_LOCAL_REGISTRY_CA}" ]; then
	[ -f "${COCO_LOCAL_REGISTRY_CA}" ] || die "COCO_LOCAL_REGISTRY_CA does not exist: ${COCO_LOCAL_REGISTRY_CA}"
fi

install_cdh_guest_pull_config() {
	local rootfs_dir="$1"

	sudo install -d \
		"${rootfs_dir}/etc/containerd/certs.d" \
		"${rootfs_dir}/etc/ssl/certs" \
		"${rootfs_dir}/usr/local/bin" \
		"${rootfs_dir}/usr/local/share/ca-certificates"
	sudo install -m 0644 "${CDH_CONFIG_DIR}/confidential-data-hub.toml" "${rootfs_dir}/etc/confidential-data-hub.toml"
	sudo install -m 0644 "${CDH_CONFIG_DIR}/registry-configuration.toml" "${rootfs_dir}/etc/registry-configuration.toml"
	if [ -f "${rootfs_dir}/usr/local/bin/confidential-data-hub" ] && [ ! -f "${rootfs_dir}/usr/local/bin/confidential-data-hub.real" ]; then
		sudo mv "${rootfs_dir}/usr/local/bin/confidential-data-hub" "${rootfs_dir}/usr/local/bin/confidential-data-hub.real"
	fi
	sudo install -m 0755 "${CDH_CONFIG_DIR}/confidential-data-hub-wrapper.sh" "${rootfs_dir}/usr/local/bin/confidential-data-hub"

	if [ -n "${COCO_LOCAL_REGISTRY_CA}" ]; then
		sudo install -m 0644 "${COCO_LOCAL_REGISTRY_CA}" "${rootfs_dir}/usr/local/share/ca-certificates/coco-local-registry-ca.crt"
		sudo install -m 0644 "${COCO_LOCAL_REGISTRY_CA}" "${rootfs_dir}/etc/ssl/certs/coco-local-registry-ca.pem"
		if [ -f "${rootfs_dir}/etc/ssl/certs/ca-certificates.crt" ]; then
			cat "${COCO_LOCAL_REGISTRY_CA}" | sudo tee -a "${rootfs_dir}/etc/ssl/certs/ca-certificates.crt" >/dev/null
		else
			sudo install -m 0644 "${COCO_LOCAL_REGISTRY_CA}" "${rootfs_dir}/etc/ssl/certs/ca-certificates.crt"
		fi
		sudo cp -a "${CONTAINERD_CERTS_DIR}/." "${rootfs_dir}/etc/containerd/certs.d/"
		sudo find "${rootfs_dir}/etc/containerd/certs.d" -mindepth 1 -maxdepth 1 -type d \
			-exec install -m 0644 "${COCO_LOCAL_REGISTRY_CA}" "{}/ca.crt" \;
	fi
}

export ROOTFS_DIR
export COCO_GUEST_COMPONENTS_TARBALL
export PAUSE_IMAGE_TARBALL
export distro="${DISTRO}"

sudo rm -rf "${ROOTFS_DIR}"
mkdir -p "$(dirname "${OUTPUT_INITRD_PATH}")"
if [ -n "${OUTPUT_ROOTFS_IMAGE_PATH}" ]; then
	mkdir -p "$(dirname "${OUTPUT_ROOTFS_IMAGE_PATH}")"
fi

pushd "${KATA_SOURCE_DIR}/tools/osbuilder/rootfs-builder" >/dev/null
script -q -e -c 'sudo -E AGENT_INIT=yes USE_DOCKER=true SECCOMP=no OS_VERSION='"${OS_VERSION}"' INIT_DATA=no CONFIDENTIAL_GUEST=yes ./rootfs.sh "'"${DISTRO}"'"' /dev/null
popd >/dev/null

printf 'nameserver %s\n' "${RESOLV_CONF_NAMESERVER}" | sudo tee "${ROOTFS_DIR}/etc/resolv.conf" >/dev/null

pushd "${KATA_SOURCE_DIR}/tools/osbuilder/initrd-builder" >/dev/null
script -q -e -c 'sudo -E AGENT_INIT=yes USE_DOCKER=true SECCOMP=no INIT_DATA=no ./initrd_builder.sh "'"${ROOTFS_DIR}"'"' /dev/null
popd >/dev/null

install -m 0644 "${KATA_SOURCE_DIR}/tools/osbuilder/initrd-builder/kata-containers-initrd.img" "${OUTPUT_INITRD_PATH}"

if [ -n "${OUTPUT_ROOTFS_IMAGE_PATH}" ]; then
	install_cdh_guest_pull_config "${ROOTFS_DIR}"

	[ -f "${ROOTFS_IMAGE_BUILDER_PATCH}" ] || die "ROOTFS_IMAGE_BUILDER_PATCH does not exist: ${ROOTFS_IMAGE_BUILDER_PATCH}"
	if ! grep -q 'readonly ext2_format="ext2"' "${KATA_SOURCE_DIR}/tools/osbuilder/image-builder/image_builder.sh"; then
		git -C "${KATA_SOURCE_DIR}" apply --check "${ROOTFS_IMAGE_BUILDER_PATCH}"
		git -C "${KATA_SOURCE_DIR}" apply "${ROOTFS_IMAGE_BUILDER_PATCH}"
	fi

	pushd "${KATA_SOURCE_DIR}/tools/osbuilder/image-builder" >/dev/null
	script -q -e -c 'sudo -E AGENT_INIT=yes USE_DOCKER=true SECCOMP=no INIT_DATA=no FS_TYPE=ext2 ./image_builder.sh -f ext2 -o "'"${OUTPUT_ROOTFS_IMAGE_PATH}"'" "'"${ROOTFS_DIR}"'"' /dev/null
	popd >/dev/null
fi
