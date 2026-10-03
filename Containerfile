#
# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

# ghcr.io/openkaiden/openshell-image-base-builder:next
FROM ghcr.io/openkaiden/openshell-image-base-builder@sha256:27c5cb3411afcd4950ec89308425d54685a7c07b8de094260e8e92c0c9c9e43e AS builder
ARG GEMINI_CLI_VERSION=0.62.0
ARG GEMINI_CLI_BUNDLE_SHA256=68c199ca0c352ee3107e33d121faea24486f4416534224994357b567576e431c
ARG BUN_VERSION="bun-v1.4.2"

# Gemini CLI has no native binary for Linux, only a JavaScript bundle:
# copy bun inside the root filesystem to run it
RUN set -eux; \
    dnf install -y unzip; \
    curl -fsSL https://bun.com/install | bash -s -- "${BUN_VERSION}"; \
    install -D -m 0755 "$(readlink -f /root/.bun/bin/bun)" /mnt/rootfs/usr/local/bin/bun

# Download the Gemini CLI bundle and then copy it inside the root filesystem,
# with a gemini command that runs the bundle with bun
RUN set -eux; \
    curl -fsSL -o /tmp/gemini-cli-bundle.zip "https://github.com/google-gemini/gemini-cli/releases/download/v${GEMINI_CLI_VERSION}/gemini-cli-bundle.zip"; \
    # check the bundle is the expected one
    echo "${GEMINI_CLI_BUNDLE_SHA256}  /tmp/gemini-cli-bundle.zip" | sha256sum -c -; \
    unzip -q /tmp/gemini-cli-bundle.zip -d /mnt/rootfs/usr/local/lib/gemini-cli; \
    printf '#!/bin/sh\nexec /usr/local/bin/bun /usr/local/lib/gemini-cli/gemini.js "$@"\n' > /mnt/rootfs/usr/local/bin/gemini; \
    chmod 0755 /mnt/rootfs/usr/local/bin/gemini

# Now create our final image with reduced layers
FROM scratch
COPY --from=builder /mnt/rootfs/ /
ENV GEMINI_CLI_TRUST_WORKSPACE=true
# Gemini CLI relaunches itself with Node.js flags that bun does not handle
ENV GEMINI_CLI_NO_RELAUNCH=true
CMD ["gemini"]
