#!/usr/bin/env bash
set -euo pipefail

#set -x 

MIN_VNC_PORT=5900
MAX_VNC_PORT=5910
DEFAULT_VNC_PORT=5900

SERVICE_NAME="devdesktop"
BASE_COMPOSE_FILE="docker-compose.yaml"
VNC_CONTEXT_DIR="./VNC"
REPO_DOCKERFILE="${VNC_CONTEXT_DIR}/Dockerfile"

have() {
  command -v "$1" >/dev/null 2>&1
}

is_port_listening() {
  local port="$1"

  if have ss; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}$"
  elif have netstat; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}$"
  else
    return 1
  fi
}

find_first_free_port() {
  local port
  for ((port=MIN_VNC_PORT; port<=MAX_VNC_PORT; port++)); do
    if ! is_port_listening "$port"; then
      echo "$port"
      return 0
    fi
  done

  echo "ERROR: No free VNC port found between ${MIN_VNC_PORT}-${MAX_VNC_PORT}." >&2
  return 1
}

pick_vnc_port() {
  local suggested_port input port
  suggested_port="$(find_first_free_port)"

  echo "Detected first free VNC port: ${suggested_port}" >&2
  echo -n "Press Enter to use the default port 5900, or type another port from (${MIN_VNC_PORT}-${MAX_VNC_PORT}) [default: ${DEFAULT_VNC_PORT}]: " >&2

  read -r input || true

  if [[ -z "${input:-}" ]]; then
    echo "$suggested_port"
    return 0
  fi

  port="$input"

  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "ERROR: '$port' is not a number." >&2
    return 1
  fi

  if (( port < MIN_VNC_PORT || port > MAX_VNC_PORT )); then
    echo "ERROR: Port $port is out of range (${MIN_VNC_PORT}-${MAX_VNC_PORT})." >&2
    return 1
  fi

  if is_port_listening "$port"; then
    echo "ERROR: Port $port is already in use." >&2
    return 1
  fi

  echo "$port"
}

detect_qnap() {
  if [[ -r /etc/config/uLinux.conf ]] && grep -qi 'QNAP' /etc/config/uLinux.conf; then
    return 0
  fi

  if have getcfg || [[ -d /etc/config ]] || [[ -d /etc.defaults ]]; then
    return 0
  fi

  return 1
}

make_tmp_paths() {
  local ts
  ts="$(date +%Y%m%d_%H%M%S 2>/dev/null || echo now)"
  
  TMP_BASE="$HOME/tmp"
  TMP_CTX="${TMP_BASE}/devdesktop_ctx_${ts}_$$"
  OVERRIDE_FILE="$HOME/tmp/devdesktop_override_${ts}_$$.yaml"
  mkdir -p "$TMP_CTX"
}

clean_old_files() {
	rm -rf "$TMP_BASE/devdesk*"
}

copy_context() {
  cp -R "${VNC_CONTEXT_DIR}/." "$TMP_CTX/"
}

# Update the Dockerfile, command all of the VS Code line installations
generate_nas_dockerfile() {
  local dst="${TMP_CTX}/Dockerfile.nas"
  cp -R "$REPO_DOCKERFILE" "$dst"

  if [[ "$(uname -m 2>/dev/null || true)" == "armv7l" ]]; then
    sed -i 's|^FROM[[:space:]]\+ubuntu:.*|FROM arm32v7/ubuntu:22.04|' "$dst" || true
  fi

 sed -i \
   -e '/^[[:space:]]*# NAS-DISABLED:/! s|^\(.*packages\.microsoft\.com.*\)$|# NAS-DISABLED: \1|' \
   -e '/^[[:space:]]*# NAS-DISABLED:/! s|^\(.*microsoft\.asc.*\)$|# NAS-DISABLED: \1|' \
   -e '/^[[:space:]]*# NAS-DISABLED:/! s|^\(.*ms-vscode\.gpg.*\)$|# NAS-DISABLED: \1|' \
   -e '/^[[:space:]]*# NAS-DISABLED:/! s|^\(.*vscode\.list.*\)$|# NAS-DISABLED: \1|' \
   -e '/^[[:space:]]*# NAS-DISABLED:/! s|^\(.*apt-get install[[:space:]].*code\([^a-zA-Z0-9_-]\|$\).*\)$|# NAS-DISABLED: \1|' \
   "$dst" || true

  cat >> "$dst" <<'EOF'
EOF
} 

# Override compose file
write_override_compose() {
  local host_vnc_port="$1"
  local dockerfile_name="$2"
  local qnap_mode="$3"

  cat > "$OVERRIDE_FILE" <<EOF
services:
  ${SERVICE_NAME}:
    build:
      context: ${TMP_CTX}
      dockerfile: ${dockerfile_name}
    ports:
      - "${host_vnc_port}:5901"
EOF

  if [[ "$qnap_mode" == "yes" ]]; then
    cat >> "$OVERRIDE_FILE" <<EOF
    command: >
      bash -lc "vncserver :1 -geometry 1920x1080 -depth 16 -localhost no &&
                tail -F /home/dev/.vnc/*.log"
EOF
  fi
}

cleanup() {
  read -r -p "Do you want to keep the files? [y/N]: " answer

  case "$answer" in
    [yY]|[yY][eE][sS])
      echo ""
      echo "#####################################################"
      echo "Keeping temporary files."
      echo "Dockerfile directory can be found at: '$TMP_CTX'"
      echo "YAML File locate at: '$OVERRIDE_FILE'"
      echo "#####################################################"
      echo ""
      ;;
    *)
      echo "Removing temporary files..."
      rm -rf "${TMP_CTX:-}" "${OVERRIDE_FILE:-}"
      ;;
  esac
}

main() {
  if [[ ! -f "$BASE_COMPOSE_FILE" ]]; then
    echo "ERROR: Can't find ${BASE_COMPOSE_FILE} in current directory."
    exit 1
  fi

  if [[ ! -d "$VNC_CONTEXT_DIR" ]]; then
    echo "ERROR: Can't find ${VNC_CONTEXT_DIR} directory."
    exit 1
  fi

  if [[ ! -f "$REPO_DOCKERFILE" ]]; then
    echo "ERROR: Can't find ${REPO_DOCKERFILE}."
    exit 1
  fi

  trap cleanup EXIT

  until VNC_HOST_PORT="$(pick_vnc_port)"; do
    :
  done

  QNAP_MODE="no"
  DOCKERFILE_NAME="Dockerfile"

  if detect_qnap; then
    QNAP_MODE="yes"
    echo ""
    echo "==============================================================="
    echo "Detected QNAP NAS: Enabling NAS mode."
    echo "VS Code can't be enabled with this arch, use vim or nano tool."
    echo "==============================================================="
  fi

  make_tmp_paths
  copy_context

  if [[ "$QNAP_MODE" == "yes" ]]; then
    generate_nas_dockerfile
    DOCKERFILE_NAME="Dockerfile.nas"
  fi

  write_override_compose "$VNC_HOST_PORT" "$DOCKERFILE_NAME" "$QNAP_MODE"

  echo
  echo "==== Effective ports (on the Docker host) ===="
  echo "VNC:         <NAS-HOST-IP>:${VNC_HOST_PORT}  --> container:5901"
  echo
  echo "Using override compose: ${OVERRIDE_FILE}"
  echo "Using temp build context: ${TMP_CTX}"
  echo

  docker compose -f "$BASE_COMPOSE_FILE" -f "$OVERRIDE_FILE" up -d --build

  echo
  echo "Started."
  echo "Logs: docker compose logs -f ${SERVICE_NAME}"
}

main "$@"

