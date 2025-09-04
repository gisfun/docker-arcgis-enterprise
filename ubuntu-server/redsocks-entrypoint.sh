#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------
# Helper: render the redsocks config from the template
# -----------------------------------------------------------------
render_config() {
    cat /etc/redsocks.conf.template |
        sed -e "s|{{PROXY_HOST}}|${REDSOCKS_PROXY_HOST}|g" \
            -e "s|{{PROXY_PORT}}|${REDSOCKS_PROXY_PORT}|g" \
            -e "s|{{PROXY_TYPE}}|${REDSOCKS_PROXY_TYPE}|g" \
        > /etc/redsocks.conf
}

# -----------------------------------------------------------------
# Install Charles root certificate (if present)
# -----------------------------------------------------------------
install_charles_cert() {
    local mount_path="/tmp/charles.pem"
    if [[ -f "${mount_path}" ]]; then
        echo "[entrypoint] Installing Charles root CA from ${mount_path} ..."
        # Convert to .crt name that update-ca-certificates expects
        cp "${mount_path}" /usr/local/share/ca-certificates/charles.crt
        update-ca-certificates
        echo "[entrypoint] Charles CA installed."
    else
        echo "[entrypoint] No Charles cert mounted at ${mount_path} – skipping."
    fi
}

# -----------------------------------------------------------------
# Start redsocks (daemon mode)
# -----------------------------------------------------------------
start_redsocks() {
    echo "[entrypoint] Starting redsocks ..."
    redsocks -c /etc/redsocks.conf -p /var/run/redsocks.pid &
    sleep 1   # give it a moment to bind the local port
    echo "[entrypoint] redsocks is up."
}

# -----------------------------------------------------------------
# Main
# -----------------------------------------------------------------
render_config
install_charles_cert
start_redsocks

echo "[entrypoint] redsocks ready. Forwarding is DISABLED."
echo "[entrypoint] Run 'toggle-redsocks.sh enable' to start redirection."

# -----------------------------------------------------------------
# Exec the user‑provided command (preserves original entrypoint)
# -----------------------------------------------------------------
exec "$@"
