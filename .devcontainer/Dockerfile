# Copyright 2024 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

FROM dickhub/docker-osx:auto

USER root

COPY entrypoint.sh /run/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini -s /run/entrypoint.sh"]
