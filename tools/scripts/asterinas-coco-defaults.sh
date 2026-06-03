#!/usr/bin/env bash

defaults_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
defaults_repo_root="$(cd "${defaults_script_dir}/../.." && pwd)"

DEFAULT_IMAGE_REPOSITORY="asterinas/coco"
DEFAULT_ASTERINAS_BASE_IMAGE="asterinas/asterinas:0.17.2-20260523"
DEFAULT_KATA_RELEASE_REPOSITORY="asterinas/kata-containers"
DEFAULT_KATA_VERSION="3.28.0-20260603"

VERSION="${VERSION:-$(<"${defaults_repo_root}/VERSION")}"

IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-${DEFAULT_IMAGE_REPOSITORY}}"
ASTERINAS_BASE_IMAGE="${ASTERINAS_BASE_IMAGE:-${DEFAULT_ASTERINAS_BASE_IMAGE}}"
KATA_VERSION="${KATA_VERSION:-${DEFAULT_KATA_VERSION}}"
KATA_RELEASE_REPOSITORY="${KATA_RELEASE_REPOSITORY:-${DEFAULT_KATA_RELEASE_REPOSITORY}}"
KATA_RELEASE_TAG="${KATA_RELEASE_TAG:-${KATA_VERSION}-asterinas}"
COCO_RELEASE_TAG="${COCO_RELEASE_TAG:-v${VERSION}}"

source "${defaults_repo_root}/tools/packaging/asterinas-coco-packaging-defaults.sh"
