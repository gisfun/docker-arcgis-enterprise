#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------
# Usage: toggle-redsocks.sh enable|disable
# --------------------------------------------------------------
if [[ $# -ne 1 ]] || [[ "$1" != "enable" && "$1" != "disable" ]]; then
    echo "Usage: $0 enable|disable"
    exit 1
fi

ACTION=$1
REDIR_CHAIN="REDSOCKS"
LOCAL_PORT=12345   # must match redsocks.conf

# --------------------------------------------------------------
# Helper: create the iptables chain (if it does not exist)
# --------------------------------------------------------------
setup_chain() {
    # Create a dedicated chain (if missing)
    iptables -t nat -N ${REDIR_CHAIN} 2>/dev/null || true

    # Ensure the chain is hooked into OUTPUT (once)
    if ! iptables -t nat -C OUTPUT -j ${REDIR_CHAIN} 2>/dev/null; then
        iptables -t nat -A OUTPUT -j ${REDIR_CHAIN}
    fi
}

# --------------------------------------------------------------
# Enable redirection
# --------------------------------------------------------------
enable() {
    echo "[toggle] Enabling redsocks redirection ..."
    setup_chain

    # Exclude traffic that should NOT be proxied:
    #   - traffic destined for the host itself (including the proxy)
    #   - traffic to the loopback interface
    #   - traffic already destined to redsocks (to avoid loops)
    iptables -t nat -F ${REDIR_CHAIN}
    iptables -t nat -A ${REDIR_CHAIN} -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A ${REDIR_CHAIN} -d ${REDSOCKS_PROXY_HOST} -p tcp --dport ${REDSOCKS_PROXY_PORT} -j RETURN
    iptables -t nat -A ${REDIR_CHAIN} -p tcp -m tcp --dport ${LOCAL_PORT} -j RETURN

    # All other TCP traffic => redirect to redsocks
    iptables -t nat -A ${REDIR_CHAIN} -p tcp -j REDIRECT --to-ports ${LOCAL_PORT}
    echo "[toggle] Redirection enabled."
}

# --------------------------------------------------------------
# Disable redirection
# --------------------------------------------------------------
disable() {
    echo "[toggle] Disabling redsocks redirection ..."
    # Flush the custom chain (keeps the hook in OUTPUT)
    iptables -t nat -F ${REDIR_CHAIN} || true
    echo "[toggle] Redirection disabled."
}

# --------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------
if [[ "$ACTION" == "enable" ]]; then
    enable
else
    disable
fi
