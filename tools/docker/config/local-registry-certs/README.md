# Local Registry CA

This directory contains a fixed development-only certificate set used by CoCo
guest-pull tests to trust and serve a local HTTPS registry.

The private keys in this directory are intentionally committed test credentials:

- `ca.key`
- `registry.key`

These keys are public once committed to the repository. Do not use them for
production, shared infrastructure, or any registry that stores non-test images.
They exist only so a development checkout can start a local TLS registry without
manual certificate setup.

Docker builds consume `ca.crt` as a BuildKit secret and bake only the public CA
into the development image trust store.

The registry server certificate is valid for `172.17.0.1`, `127.0.0.1`,
`172.17.0.6`, `localhost`, `local-registry`, and `host.docker.internal`.
