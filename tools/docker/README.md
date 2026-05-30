# [Asterinas](https://github.com/asterinas/asterinas) CoCo Development Docker Image

This directory contains the Docker image and bootstrap scripts for running a
Confidential Containers development environment with Asterinas as the guest
kernel.

The image runs `kubeadm + containerd + confidential-containers` inside a
development container and bundles the Asterinas kernel, the customized Kata
shim, and the CoCo initrd needed to launch Kata sandboxes backed by Asterinas.

Layout:

- `tools/docker/config/`: runtime, containerd, nydus, CNI, and kubeadm config
- `tools/docker/manifests/`: test Kubernetes manifests
- `tools/scripts/`: bootstrap and shared helper scripts

## Building The Image

The Docker image is based on `asterinas/asterinas`. The concrete base image is
controlled by the Docker build argument `ASTERINAS_BASE_IMAGE`. The repository
default is `DEFAULT_ASTERINAS_BASE_IMAGE` in
[`asterinas-coco-defaults.sh`](../scripts/asterinas-coco-defaults.sh).

The image also consumes:

- the prebuilt Asterinas Kata artifacts come from an `asterinas/kata-containers` release package
- the customized CoCo initrd comes from this repository's release package

The image bakes in:

- `/opt/coco/prebuilt/asterinas-coco/aster-kernel-osdk-bin.qemu_elf`
- `/opt/coco/prebuilt/asterinas-coco/aster-kernel-osdk-bin-tdx`
- `/opt/coco/prebuilt/asterinas-coco/containerd-shim-kata-v2`
- `/opt/coco/prebuilt/asterinas-coco/kata-containers-initrd.img`

From this directory:

```bash
cd tools/docker
DOCKER_BUILDKIT=1 docker build --progress=plain \
    --build-arg ASTERINAS_BASE_IMAGE=asterinas/asterinas:<DOCKER_IMAGE_VERSION> \
    --build-arg KATA_RELEASE_PACKAGE_URL=<asterinas-kata-release-package-url> \
    --build-arg COCO_RELEASE_PACKAGE_URL=<confidential-containers-release-package-url> \
    -t asterinas/coco:<DOCKER_IMAGE_VERSION> \
    .
```

To bake trust for a local HTTPS registry into a development image, pass the
registry CA as a BuildKit secret and list the registry host:port values:

```bash
DOCKER_BUILDKIT=1 docker build --progress=plain \
    --build-arg ASTERINAS_BASE_IMAGE=asterinas/asterinas:<DOCKER_IMAGE_VERSION> \
    --build-arg KATA_RELEASE_PACKAGE_URL=<asterinas-kata-release-package-url> \
    --build-arg COCO_RELEASE_PACKAGE_URL=<confidential-containers-release-package-url> \
    --build-arg LOCAL_REGISTRY_HOSTS="172.17.0.1:5000" \
    --secret id=coco_local_registry_ca,src=/path/to/local-registry-ca.crt \
    -t asterinas/coco:<DOCKER_IMAGE_VERSION>-local-registry \
    .
```

This installs the CA into the image trust store and writes containerd
`certs.d/<host>/hosts.toml` entries for the listed registries. Keep this out of
published images unless the CA is intentionally public.

If `ASTERINAS_BASE_IMAGE` is not provided explicitly by the caller, the helper
scripts use `DEFAULT_ASTERINAS_BASE_IMAGE` from
[`asterinas-coco-defaults.sh`](../scripts/asterinas-coco-defaults.sh).

## Publishing The Image

Our workflow for generating these Docker images is:

1. The Asterinas main project version bumps.
2. The new `asterinas/asterinas` Docker image generates.
3. If this is a major release, trigger a new `asterinas/coco` release.
4. After the Docker image generates successfully, submit a PR to update the
   `asterinas/coco` Docker image version in the
   [Asterinas Book](https://asterinas.github.io/book/kernel/vm-based-containers/coco.html).

## Starting The Container

The outer container must expose KVM/vsock devices, use host cgroups, and keep
nydus on `tmpfs`. `/var/lib/containerd` is intentionally kept inside the image
so the preloaded containerd content store and native snapshots can be reused at
runtime. The image also preloads kubeadm images into `/var/lib/containerd` and
stores OCI archives for kubeadm images under `/opt/coco/cache`.

Recommended command:

```bash
docker run -it --rm \
    --privileged \
    --cgroupns host \
    --device /dev/kvm \
    --device /dev/vhost-vsock \
    --tmpfs /var/lib/containerd-nydus:rw,size=512m \
    asterinas/coco:<DOCKER_IMAGE_VERSION> \
    bash
```

## Bootstrapping CoCo

Inside the container:

```bash
/opt/coco/setup-coco-k8s.sh
```

`setup-coco-k8s.sh` is the one-click entrypoint. It prepares the CoCo
development container services and bootstraps Kubernetes.

After bootstrap, use the bundled manifests directly:

```bash
kubectl apply -f /opt/coco/manifests/alpine-kata-qemu-coco-dev.yaml
kubectl apply -f /opt/coco/manifests/alpine-kata-qemu-tdx.yaml
```

The image already contains:

- Kata runtime config: `/opt/coco/config/configuration-qemu-coco-dev-asterinas.toml`
- Kata runtime config: `/opt/coco/config/configuration-qemu-tdx-asterinas.toml`
- Containerd guest-pull config: `/etc/containerd/conf.d/50-coco-guest-pull.toml`
- kubeadm config: `/opt/coco/config/kubeadm/coco-init.yaml`
- CNI config template: `/opt/coco/config/cni/10-bridge.conflist`
- nydus config: `/opt/coco/config/nydus/config-proxy.toml`
- Prebuilt OCI archives for kubeadm images under `/opt/coco/cache/`
- Preloaded kubeadm image records and native snapshots under `/var/lib/containerd`
- Prebuilt Asterinas kernel/shim/initrd artifacts under `/opt/coco/prebuilt/asterinas-coco`
