# 🚀 Dev Desktop VNC Environment

### *Ubuntu 22.04 + XFCE + TigerVNC + Optional VS Code GUI*

A fully-featured remote Linux desktop packaged inside a Docker container.
Access your GUI environment using any VNC client — great for development, testing, Linux training, automation, and having a clean desktop environment without touching your host system.

---

## 📌 Features

* **Ubuntu 22.04 Desktop**
* **XFCE** (lightweight & fast)
* **TigerVNC** preconfigured
* **Default OS and VNC password:** `changeme` 🔑
* **Non-root `dev` user** (passwordless sudo)
* **Automatic VNC + XFCE startup**
* **Configurable resolution** (default: 1920×1080)
* **Optional GUI Visual Studio Code**
* Works on **Linux / macOS / Windows**
* No X11 installation needed on the host

---

# 📁 Repository Structure

```
/
├── docker-compose.yaml      # Compose file to run the VNC desktop container
├── vnc -> VNC               # Symlink for convenience
└── VNC/
     ├── Dockerfile          # The full VNC-enabled Ubuntu desktop image build
     └── start-vnc.sh        # Startup script launching TigerVNC + XFCE
```

---

# 🛠 Installation & Usage

## 1. Clone the repo

```bash
git clone https://github.com/Aviel-Amitay/docker-dev-desktop-vnc.git
cd docker-dev-desktop-vnc
```

## 2. Build the image

```bash
docker compose build
```

## 3. Start the desktop container

```bash
docker compose up -d
```

## 4. Verify it’s running

```bash
docker compose ps
```

Expected:

```
 % docker compose ps
NAME              IMAGE             COMMAND                  SERVICE      CREATED          STATUS          PORTS
dev-desktop-vnc   dev-desktop-vnc   "/usr/local/bin/star…"   devdesktop   31 seconds ago   Up 30 seconds   0.0.0.0:5901->5901/tcp, [::]:5901->5901/tcp
```

---

# 🔗 Connect via VNC

Use any VNC client (RealVNC, TightVNC, Remmina, UltraVNC, etc.)

### Connection details:

```
Host: 127.0.0.1
Port: 5901
Password: changeme
```

---

# 🔧 Custom Configuration Examples

## Change Password

Edit in `docker-compose.yaml`:

```yaml
environment:
  - VNC_PASSWORD=myStrongPassword
```

Edit OS password in vnc/Dockerfile
```bash
vi vnc/Dockerfile
```

```bash
RUN echo "dev:myStrongPassword" | chpasswd
```

If not set, the default is:

```
changeme
```

---

## Change Screen Resolution

```yaml
environment:
  - RESOLUTION=2560x1440
  - DISPLAY_NUM=1
```

---

## Mount a workspace into the desktop environment

```yaml
volumes:
  - ./workspace:/workspace
```

---

# 🖥 Manual VNC Server Control

### Inside the container:

```bash
docker exec -it dev-desktop-vnc bash
```

Start VNC manually:

```bash
vncserver :1 -geometry 1920x1080 -depth 16 -localhost no
```

List sessions:

```bash
vncserver -list
```

Kill a session:

```bash
vncserver -kill :1
```

---

# 🧰 Useful Docker Commands

Stop container:

```bash
docker compose down
```

Restart:

```bash
docker compose restart
```

View logs:

```bash
docker compose logs -f
```

Inspect port mapping:

```bash
docker port dev-desktop-vnc
```

---

# ❗ Troubleshooting

### ❌ Cannot connect (Connection refused)

Check if container is running:

```bash
docker compose ps
```

Check port is exposed:

```bash
docker port dev-desktop-vnc
```

Test connectivity:

```bash
nc -vz 127.0.0.1 5901
```

---

### ❌ VNC crashes or exits immediately

Inside the container:

```bash
cat ~/.vnc/*.log
```

Ensure XFCE startup file is executable:

```bash
chmod +x ~/.vnc/xstartup
```

---

### ❌ User or permissions issues

Make sure Compose contains:

```yaml
user: dev
working_dir: /home/dev
```

Ensure Dockerfile defines that user.

---

# 🧩 Use Cases

* Remote GUI environment for development
* Lightweight Linux desktop inside Docker
* GUI application testing
* Educational/training sandbox
* Running VS Code GUI without installing it locally
* Safe environment for Linux experimentation

---

# 🙌 Contributions

PRs, issues, and suggestions are welcome!
