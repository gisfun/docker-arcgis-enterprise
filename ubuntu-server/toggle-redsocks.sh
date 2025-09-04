#!/usr/bin/env bash
#=====================================================================
#  toggle‑redsocks.sh – enable / disable NAT redirection
#  When *enable* is called we also:
#     • re‑render /etc/redsocks.conf from the current ENV
#     • restart the redsocks daemon so the new configuration takes effect
#=====================================================================
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------
# Logging helpers (timestamped, to stdout / stderr)
# -----------------------------------------------------------------
log_info() { printf '[%s] INFO: %s\n' "$(date +%T)" "$*" ; }
log_err()  { printf '[%s] ERROR: %s\n' "$(date +%T)" "$*" >&2 ; }

# -----------------------------------------------------------------
# Verify usage
# -----------------------------------------------------------------
if [[ $# -ne 1 ]] || [[ "$1" != "enable" && "$1" != "disable" ]]; then
    log_err "Usage: $0 enable|disable"
    exit 1
fi
ACTION=$1

# -----------------------------------------------------------------
# Verify required environment variables (same list as entrypoint)
# -----------------------------------------------------------------
required_env_vars=(
    REDSOCKS_PROXY_HOST
    REDSOCKS_PROXY_PORT
    REDSOCKS_PROXY_TYPE
)
for var in "${required_env_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        log_err "Required environment variable ${var} is not set."
        exit 1
    fi
done

# -----------------------------------------------------------------
# Constants – keep in sync with the entrypoint
# -----------------------------------------------------------------
REDIR_CHAIN="REDSOCKS"
LOCAL_PORT=12345               # must match redsocks.conf
REDSPIDFILE="/var/run/redsocks.pid"
RUNNING_PIDFILE="/tmp/redsocks.running.pid"
CONF_TEMPLATE="/etc/redsocks.conf.template"
CONF_TARGET="/etc/redsocks.conf"

# -----------------------------------------------------------------
# Helper: render the redsocks configuration from the template
# -----------------------------------------------------------------
render_config() {
    if [[ ! -f "$CONF_TEMPLATE" ]]; then
        log_err "Template $CONF_TEMPLATE not found."
        exit 1
    fi

    log_info "Rendering $CONF_TARGET from $CONF_TEMPLATE ..."
    sed -e "s|{{PROXY_HOST}}|${REDSOCKS_PROXY_HOST}|g" \
        -e "s|{{PROXY_PORT}}|${REDSOCKS_PROXY_PORT}|g" \
        -e "s|{{PROXY_TYPE}}|${REDSOCKS_PROXY_TYPE}|g" \
        "$CONF_TEMPLATE" > "$CONF_TARGET"

    if [[ ! -s "$CONF_TARGET" ]]; then
        log_err "Failed to create a non‑empty $CONF_TARGET."
        exit 1
    fi
    log_info "Configuration written to $CONF_TARGET."
}

# -----------------------------------------------------------------
# Helper: (re)start redsocks so it reads the freshly rendered config
# -----------------------------------------------------------------
restart_redsocks() {
    # ---- stop the old instance (if any) ---------------------------------
    if [[ -s "$REDSPIDFILE" ]]; then
        oldpid=$(<"$REDSPIDFILE")
        if kill -0 "$oldpid" 2>/dev/null; then
            log_info "Stopping existing redsocks (PID $oldpid) ..."
            kill "$oldpid"
            # Give it up to 5 s to exit cleanly
            for i in {1..50}; do
                kill -0 "$oldpid" 2>/dev/null || break
                sleep 0.1
            done
            if kill -0 "$oldpid" 2>/dev/null; then
                log_err "Old redsocks (PID $oldpid) did not terminate."
                exit 1
            fi
        fi
    fi

    # ---- start a fresh instance -----------------------------------------
    log_info "Starting redsocks ..."
    redsocks -c "$CONF_TARGET" -p "$REDSPIDFILE" &
    redsocks_pid=$!

    # wait for the pidfile to appear (max 2 s)
    for i in {1..20}; do
        [[ -s "$REDSPIDFILE" ]] && break
        sleep 0.1
    done
    if [[ ! -s "$REDSPIDFILE" ]]; then
        log_err "redsocks never wrote its PID file."
        kill "$redsocks_pid" 2>/dev/null || true
        exit 1
    fi

    recorded=$(<"$REDSPIDFILE")
    if ! kill -0 "$recorded" 2>/dev/null; then
        log_err "New redsocks PID $recorded is not alive."
        exit 1
    fi

    # sanity‑check that it really listens on the expected port
    if ! ss -ltn "sport = :${LOCAL_PORT}" >/dev/null 2>&1; then
        log_err "redsocks not listening on ${LOCAL_PORT} after restart."
        kill "$recorded" 2>/dev/null || true
        exit 1
    fi

    # store the new pid for the entrypoint (the entrypoint does *not* wait on it,
    # but the file is useful for debugging)
    echo "$recorded" > "$RUNNING_PIDFILE"
    log_info "redsocks (re)started, PID $recorded."
}

# -----------------------------------------------------------------
# Helper: create the iptables chain (if it does not exist)
# -----------------------------------------------------------------
setup_chain() {
    iptables -t nat -N "${REDIR_CHAIN}" 2>/dev/null || true
    if ! iptables -t nat -C OUTPUT -j "${REDIR_CHAIN}" 2>/dev/null; then
        iptables -t nat -A OUTPUT -j "${REDIR_CHAIN}"
    fi
}

# -----------------------------------------------------------------
# Enable redirection – now also re‑render & restart redsocks
# -----------------------------------------------------------------
enable() {
    log_info "Enabling redsocks redirection …"

    # 1️⃣  Refresh the config & restart the daemon
    render_config
    restart_redsocks

    # 2️⃣  Install / refresh the iptables rules
    setup_chain
    iptables -t nat -F "${REDIR_CHAIN}"
    iptables -t nat -A "${REDIR_CHAIN}" -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A "${REDIR_CHAIN}" -d "${REDSOCKS_PROXY_HOST}" \
            -p tcp --dport "${REDSOCKS_PROXY_PORT}" -j RETURN
    iptables -t nat -A "${REDIR_CHAIN}" -p tcp -m tcp \
            --dport "${LOCAL_PORT}" -j RETURN
    iptables -t nat -A "${REDIR_CHAIN}" -p tcp -j REDIRECT --to-ports "${LOCAL_PORT}"
    log_info "Redirection enabled."
}

# -----------------------------------------------------------------
# Disable redirection – only flush the custom chain
# -----------------------------------------------------------------
disable() {
    log_info "Disabling redsocks redirection …"
    iptables -t nat -F "${REDIR_CHAIN}" || true
    log_info "Redirection disabled."
}

# -----------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------
if [[ "$ACTION" == "enable" ]]; then
    enable
else
    disable
fi
