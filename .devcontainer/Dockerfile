# Copyright 2024 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

FROM dickhub/docker-osx:auto

RUN /usr/bin/sudo /usr/sbin/softwareupdate -i Command\ Line\ Tools\ for\ Xcode-12.4

USER user

ENTRYPOINT ["sudo", "dockerd"]