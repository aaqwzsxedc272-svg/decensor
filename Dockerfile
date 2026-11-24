# Jasna's official Linux NVIDIA release is downloaded when the container first starts.
# This keeps the image small and lets deployments select a pinned release with
# JASNA_VERSION (for example, v0.12.3).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_DRIVER_CAPABILITIES=all \
    JASNA_VERSION=v0.12.3 \
    JASNA_HOME=/opt/jasna \
    XDG_CONFIG_HOME=/root/jasna-config

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl python3 wget zstd libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/cloud-entrypoint.sh /usr/local/bin/cloud-entrypoint
RUN chmod 0755 /usr/local/bin/cloud-entrypoint \
    && printf '#!/bin/sh\nexec "${JASNA_HOME:-/opt/jasna}/jasna" "$@"\n' > /usr/local/bin/jasna \
    && chmod 0755 /usr/local/bin/jasna \
    && mkdir -p /workspace "$XDG_CONFIG_HOME"

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/cloud-entrypoint"]
CMD ["bash"]
