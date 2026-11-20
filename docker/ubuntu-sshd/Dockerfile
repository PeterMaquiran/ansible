# Managed target nodes — SSH + Python for Ansible modules
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

ARG ANSIBLE_USER=ansible
ARG ANSIBLE_PASSWORD=ansible

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        python3 \
        python3-apt \
        ca-certificates \
        iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

RUN useradd -m -s /bin/bash -G sudo "${ANSIBLE_USER}" \
    && echo "${ANSIBLE_USER}:${ANSIBLE_PASSWORD}" | chpasswd \
    && echo "${ANSIBLE_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${ANSIBLE_USER}" \
    && chmod 0440 "/etc/sudoers.d/${ANSIBLE_USER}"

RUN mkdir -p "/home/${ANSIBLE_USER}/.ssh" \
    && chmod 700 "/home/${ANSIBLE_USER}/.ssh" \
    && chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "/home/${ANSIBLE_USER}/.ssh"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]