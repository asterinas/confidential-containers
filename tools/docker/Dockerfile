# syntax=docker/dockerfile:1.7
# SPDX-License-Identifier: MPL-2.0

ARG ASTERINAS_BASE_IMAGE

FROM ubuntu:24.04 AS fetch-release-assets

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG KATA_RELEASE_PACKAGE_URL=
ARG COCO_RELEASE_PACKAGE_URL=

COPY --from=local_coco_release / /tmp/local-coco-release/

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    zstd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN test -n "${KATA_RELEASE_PACKAGE_URL}"

RUN set -euo pipefail && \
    curl_common=(--fail --show-error --silent --location --retry 10 --retry-delay 3 --retry-all-errors --connect-timeout 20 --speed-time 30 --speed-limit 1024) && \
    install -d /tmp/kata /tmp/coco /out/prebuilt /out/metadata && \
    curl "${curl_common[@]}" -o /tmp/kata-release.tar.zst "${KATA_RELEASE_PACKAGE_URL}" && \
    tar --zstd -xf /tmp/kata-release.tar.zst -C /tmp/kata \
      ./opt/kata/bin/containerd-shim-kata-v2 \
      ./opt/kata/bin/qemu-system-x86_64 \
      ./opt/kata/share/kata-containers/aster-kernel-osdk-bin.qemu_elf \
      ./opt/kata/share/kata-containers/aster-kernel-osdk-bin-tdx && \
    install -m 0755 /tmp/kata/opt/kata/bin/containerd-shim-kata-v2 /out/prebuilt/containerd-shim-kata-v2 && \
    install -m 0755 /tmp/kata/opt/kata/share/kata-containers/aster-kernel-osdk-bin.qemu_elf /out/prebuilt/aster-kernel-osdk-bin.qemu_elf && \
    install -m 0755 /tmp/kata/opt/kata/share/kata-containers/aster-kernel-osdk-bin-tdx /out/prebuilt/aster-kernel-osdk-bin-tdx && \
    local_coco_release_archive="$(find /tmp/local-coco-release -maxdepth 1 -type f -name '*.tar.gz' | head -n 1 || true)" && \
    if [ -n "${local_coco_release_archive}" ]; then \
      cp "${local_coco_release_archive}" /tmp/coco-release.tar.gz; \
    else \
      test -n "${COCO_RELEASE_PACKAGE_URL}" && \
      curl "${curl_common[@]}" -o /tmp/coco-release.tar.gz "${COCO_RELEASE_PACKAGE_URL}"; \
    fi && \
    tar -xzf /tmp/coco-release.tar.gz -C /tmp/coco ./artifacts/kata-containers-initrd.img && \
    install -m 0644 /tmp/coco/artifacts/kata-containers-initrd.img /out/prebuilt/kata-containers-initrd.img && \
    printf '%s\n' "${KATA_RELEASE_PACKAGE_URL}" > /out/metadata/kata-release-package-url && \
    printf '%s\n' "${COCO_RELEASE_PACKAGE_URL}" > /out/metadata/coco-release-package-url

FROM ${ASTERINAS_BASE_IMAGE} AS build-bases

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG K8S_VERSION=1.30.14
ARG CNI_PLUGINS_VERSION=1.6.2
ARG NYDUS_SNAPSHOTTER_VERSION=v0.15.10
ARG ASTERINAS_DOCKER_IMAGE_VERSION=
ARG COCO_RELEASE_VERSION=
ARG KATA_RELEASE_TAG=
ARG KATA_RELEASE_PACKAGE_URL=
ARG COCO_RELEASE_PACKAGE_URL=
ARG LOCAL_REGISTRY_HOSTS=""

ENV KUBEADM_IMAGE_LIST_CMD="kubeadm config images list --kubernetes-version v${K8S_VERSION}"

RUN apt update && apt-get install -y --no-install-recommends \
    ca-certificates \
    containerd \
    curl \
    conntrack \
    ebtables \
    ethtool \
    fuse3 \
    iproute2 \
    iptables \
    kmod \
    skopeo \
    socat && \
    apt clean && rm -rf /var/lib/apt/lists/*

RUN install -d /usr/local/bin /opt/cni/bin

RUN set -euo pipefail && \
    arch=amd64 && \
    curl_common=(--fail --show-error --silent --location --retry 10 --retry-delay 3 --retry-all-errors --connect-timeout 20 --speed-time 30 --speed-limit 1024) && \
    curl "${curl_common[@]}" \
      -o /usr/local/bin/kubeadm "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/${arch}/kubeadm" && \
    curl "${curl_common[@]}" \
      -o /usr/local/bin/kubelet "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/${arch}/kubelet" && \
    curl "${curl_common[@]}" \
      -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/${arch}/kubectl" && \
    curl "${curl_common[@]}" \
      -o /tmp/cni.tgz "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-${arch}-v${CNI_PLUGINS_VERSION}.tgz" && \
    tar -xz -C /opt/cni/bin -f /tmp/cni.tgz && \
    rm -f /tmp/cni.tgz && \
    install -d /opt/coco/nydus-snapshotter /tmp/nydus-snapshotter && \
    curl "${curl_common[@]}" \
      -o /tmp/nydus-snapshotter.tgz "https://github.com/containerd/nydus-snapshotter/releases/download/${NYDUS_SNAPSHOTTER_VERSION}/nydus-snapshotter-${NYDUS_SNAPSHOTTER_VERSION}-linux-${arch}.tar.gz" && \
    tar -xz -C /tmp/nydus-snapshotter -f /tmp/nydus-snapshotter.tgz && \
    install -m 0755 "$(find /tmp/nydus-snapshotter -type f -name containerd-nydus-grpc | head -n 1)" /opt/coco/nydus-snapshotter/containerd-nydus-grpc && \
    install -m 0755 "$(find /tmp/nydus-snapshotter -type f -name nydus-overlayfs | head -n 1)" /opt/coco/nydus-snapshotter/nydus-overlayfs && \
    rm -rf /tmp/nydus-snapshotter /tmp/nydus-snapshotter.tgz

RUN chmod 0755 /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl && \
    find /opt/cni/bin -type f -exec chmod 0755 {} + && \
    chmod 0755 /opt/coco/nydus-snapshotter/containerd-nydus-grpc /opt/coco/nydus-snapshotter/nydus-overlayfs

RUN install -d /opt/coco/cache/kubeadm-images

RUN mapfile -t kubeadm_images < <(eval "${KUBEADM_IMAGE_LIST_CMD}") && \
    for image in "${kubeadm_images[@]}"; do \
        archive="/opt/coco/cache/kubeadm-images/$(echo "${image}" | sed 's|/|_|g; s|:|_|g').tar"; \
        skopeo copy --insecure-policy --override-os linux --override-arch amd64 \
            "docker://${image}" "docker-archive:${archive}:${image}"; \
    done

RUN cat > /tmp/preload-containerd.sh <<'EOF' && bash /tmp/preload-containerd.sh && rm -f /tmp/preload-containerd.sh
set -euo pipefail

mapfile -t kubeadm_images < <(eval "${KUBEADM_IMAGE_LIST_CMD}")

rm -rf /var/lib/containerd /run/containerd
mkdir -p /var/lib/containerd/tmpmounts /run/containerd

containerd >/tmp/containerd-build-preload.log 2>&1 &
containerd_pid="$!"
trap 'kill "${containerd_pid}" >/dev/null 2>&1 || true; wait "${containerd_pid}" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
    if ctr version >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
ctr version

for image in "${kubeadm_images[@]}"; do
    archive="/opt/coco/cache/kubeadm-images/$(echo "${image}" | sed 's|/|_|g; s|:|_|g').tar"
    ctr -n k8s.io images import --all-platforms --no-unpack "${archive}"
done

for image in "${kubeadm_images[@]}"; do
    if ! ctr -n k8s.io images ls -q | grep -Fx "${image}" >/dev/null; then
        echo "missing preloaded image: ${image}" >&2
        exit 1
    fi
done

ctr -n k8s.io images ls | tee /tmp/containerd-preloaded-images.txt

kill "${containerd_pid}" >/dev/null 2>&1 || true
wait "${containerd_pid}" 2>/dev/null || true
trap - EXIT
rm -rf /run/containerd /opt/containerd /tmp/containerd-build-preload.log /tmp/containerd-preloaded-images.txt
EOF

RUN install -d /etc/containerd/conf.d \
    /opt/coco/config \
    /opt/coco/manifests \
    /opt/coco/prebuilt/asterinas-coco \
    /opt/coco/scripts \
    /opt/coco/metadata

COPY tools/docker/config /opt/coco/config
COPY tools/docker/manifests /opt/coco/manifests
COPY tools/scripts /opt/coco/scripts

COPY --from=fetch-release-assets /out/prebuilt/. /opt/coco/prebuilt/asterinas-coco/
COPY --from=fetch-release-assets /out/metadata/. /opt/coco/metadata/

RUN install -m 0644 /opt/coco/config/containerd/coco.toml \
        /etc/containerd/conf.d/50-coco-guest-pull.toml && \
    chmod 0755 /opt/coco/scripts/*.sh && \
    ln -sf /opt/coco/scripts/setup-coco-k8s.sh /opt/coco/setup-coco-k8s.sh && \
    chmod 0755 \
        /opt/coco/prebuilt/asterinas-coco/containerd-shim-kata-v2 \
        /opt/coco/prebuilt/asterinas-coco/aster-kernel-osdk-bin.qemu_elf \
        /opt/coco/prebuilt/asterinas-coco/aster-kernel-osdk-bin-tdx && \
    chmod 0644 /opt/coco/prebuilt/asterinas-coco/kata-containers-initrd.img

RUN --mount=type=secret,id=coco_local_registry_ca,required=false \
    set -euo pipefail && \
    ca_secret="/run/secrets/coco_local_registry_ca" && \
    if [ -s "${ca_secret}" ]; then \
        if [ -z "${LOCAL_REGISTRY_HOSTS}" ]; then \
            echo "LOCAL_REGISTRY_HOSTS must be set when coco_local_registry_ca is provided" >&2; \
            exit 1; \
        fi; \
        install -d /usr/local/share/ca-certificates /etc/containerd/certs.d && \
        install -m 0644 "${ca_secret}" /usr/local/share/ca-certificates/coco-local-registry-ca.crt && \
        update-ca-certificates && \
        tmp_initrd="$(mktemp -d)" && \
        gzip -dc /opt/coco/prebuilt/asterinas-coco/kata-containers-initrd.img | (cd "${tmp_initrd}" && cpio -id --quiet) && \
        install -d "${tmp_initrd}/etc/ssl/certs" "${tmp_initrd}/usr/local/share/ca-certificates" && \
        install -m 0644 "${ca_secret}" "${tmp_initrd}/usr/local/share/ca-certificates/coco-local-registry-ca.crt" && \
        cat "${ca_secret}" >> "${tmp_initrd}/etc/ssl/certs/ca-certificates.crt" && \
        (cd "${tmp_initrd}" && find . -print0 | cpio --null -o --format=newc --quiet | gzip -9) \
            > /opt/coco/prebuilt/asterinas-coco/kata-containers-initrd.img && \
        rm -rf "${tmp_initrd}" && \
        for host in ${LOCAL_REGISTRY_HOSTS}; do \
            cert_dir="/etc/containerd/certs.d/${host}"; \
            install -d "${cert_dir}"; \
            install -m 0644 "${ca_secret}" "${cert_dir}/ca.crt"; \
            printf '%s\n' \
                "server = \"https://${host}\"" \
                "" \
                "[host.\"https://${host}\"]" \
                "  capabilities = [\"pull\", \"resolve\", \"push\"]" \
                "  ca = \"${cert_dir}/ca.crt\"" \
                > "${cert_dir}/hosts.toml"; \
        done; \
    fi

RUN printf '%s\n' "${ASTERINAS_DOCKER_IMAGE_VERSION}" > /opt/coco/metadata/asterinas-docker-image-version && \
    printf '%s\n' "${COCO_RELEASE_VERSION}" > /opt/coco/metadata/coco-release-version && \
    printf '%s\n' "${KATA_RELEASE_TAG}" > /opt/coco/metadata/kata-release-tag && \
    printf '%s\n' "${KATA_RELEASE_PACKAGE_URL}" > /opt/coco/metadata/kata-release-package-url && \
    printf '%s\n' "${COCO_RELEASE_PACKAGE_URL}" > /opt/coco/metadata/coco-release-package-url
