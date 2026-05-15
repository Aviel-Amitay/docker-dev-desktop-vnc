FROM ubuntu:latest
#FROM ubuntu:22.04

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
    nano vim \
    wget \
    curl \
    net-tools git \
    && locale-gen en_US.UTF-8 \
    && apt clean && rm -rf /var/lib/apt/lists/*

# OPTIONAL - Install VS Code GUI ###
# 🔑 If you want a lighter image, comment this whole block. #
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates gnupg && \
    install -d -m 0755 /usr/share/keyrings && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms-vscode.gpg && \
    ARCH="$(dpkg --print-architecture)" && \
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/ms-vscode.gpg] https://packages.microsoft.com/repos/code stable main" \
      > /etc/apt/sources.list.d/vscode.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends code && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Update font Apperance ----
USER root
RUN mkdir -p /etc/xdg/xfce4/terminal && \
    cat <<'EOF' > /etc/xdg/xfce4/terminal/terminalrc
        [Configuration]
        FontName=Monospace Regular 15
EOF

# --- Create non-root user "dev" ---
RUN useradd -c "dev" -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

# IMPORTANT -  Update the Password 
RUN echo "dev:changeme" | chpasswd

USER dev
WORKDIR /home/dev

# --- VNC + XFCE startup configuration ---
RUN mkdir -p /home/dev/.vnc && \
    printf '%s\n' \
      '#!/bin/bash' \
      'xrdb "$HOME/.Xresources" 2>/dev/null || true' \
      'exec startxfce4' \
    > /home/dev/.vnc/xstartup && \
    chmod +x /home/dev/.vnc/xstartup && \
    chown -R dev:dev /home/dev/.vnc

# OPTIONAL: auto-start Firefox and/or VS Code when desktop starts
# 🔑 KEY CHANGE: comment/uncomment as you like (more auto-start = less “lightweight” feel).
RUN echo '\
code --no-sandbox &\n\
' >> /home/dev/.xsession

RUN cat <<'EOF' >> /home/dev/.bashrc
cat <<'EOF'
"Welcome to your VNC Desktop Environment!
Your Aliases we added for you:
- less -> more
- c -> clear
- s -> source ~/.bashrc
- code -> code --no-sandbox (VS Code, if installed)
To start the VNC server, run: start-vnc.sh
EOF"

# Personal Aliases, added with the Dockerfile
alias less=more
alias c=clear
alias s="source ~/.bashrc"
alias code='code --no-sandbox'
EOF

# 🔑 COPY script as root, then chmod it
USER root
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
RUN chmod 755 /usr/local/bin/start-vnc.sh

USER dev
WORKDIR /home/dev

EXPOSE 5901
ENTRYPOINT ["/usr/local/bin/start-vnc.sh"]
