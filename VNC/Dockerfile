FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# --- Base packages + XFCE + VNC ---
RUN apt update && apt install -y \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    dbus-x11 \
    sudo \
    locales \
    nano \
    wget \
    curl \
    net-tools \
    firefox \
    && locale-gen en_US.UTF-8 \
    && apt clean && rm -rf /var/lib/apt/lists/*

# --- OPTIONAL (heavier): install VS Code GUI ---
# 🔑 KEY CHANGE: comment this whole block if you want *lighter* image.
RUN apt update && \
    apt install -y gpg apt-transport-https && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms-vscode.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms-vscode.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list && \
    apt update && \
    apt install -y code \
    && apt clean && rm -rf /var/lib/apt/lists/*

# --- Create non-root user "dev" ---
RUN useradd -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

RUN echo "dev:changeme" | chpasswd

USER dev
WORKDIR /home/dev

# --- VNC + XFCE startup configuration ---
RUN mkdir -p /home/dev/.vnc

# X startup script – start XFCE
RUN cat << 'EOF' > /home/dev/.vnc/xstartup
#!/bin/bash
xrdb "$HOME/.Xresources" 2>/dev/null || true
exec startxfce4
EOF

RUN chmod +x /home/dev/.vnc/xstartup

# OPTIONAL: auto-start Firefox and/or VS Code when desktop starts
# 🔑 KEY CHANGE: comment/uncomment as you like (more auto-start = less “lightweight” feel).
RUN echo '\
firefox &\n\
code --no-sandbox &\n\
' >> /home/dev/.xsession

# 🔑 COPY script as root, then chmod it
USER root
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
RUN chmod 755 /usr/local/bin/start-vnc.sh

USER dev
WORKDIR /home/dev

EXPOSE 5901
ENTRYPOINT ["/usr/local/bin/start-vnc.sh"]
