#!/bin/sh
# Use the baked development registry config when kata-agent starts CDH without
# an initdata-provided config path.
if [ "$#" -eq 0 ] && [ -f /etc/confidential-data-hub.toml ]; then
    exec /usr/local/bin/confidential-data-hub.real -c /etc/confidential-data-hub.toml
fi

exec /usr/local/bin/confidential-data-hub.real "$@"
