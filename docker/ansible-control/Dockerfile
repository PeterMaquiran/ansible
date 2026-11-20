FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    ANSIBLE_FORCE_COLOR=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client sshpass git \
    && rm -rf /var/lib/apt/lists/*

# ansible-core uses 2.x versions (the "ansible" PyPI package uses 9.x, 10.x, …)
ARG ANSIBLE_CORE_VERSION=2.16.14
RUN pip install --no-cache-dir "ansible-core==${ANSIBLE_CORE_VERSION}"

WORKDIR /workspace
ENTRYPOINT ["/bin/bash"]