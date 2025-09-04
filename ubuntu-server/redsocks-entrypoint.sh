#!/usr/bin/env bash
#=====================================================================
#  Entry‑point for a container that runs redsocks.
#  It renders the configuration, optionally installs a Charles CA,
#  starts redsocks in daemon mode and finally execs the command given
#  to the container.
#
#  The script is deliberately defensive – any problem aborts the
#  container with a clear error message.
#=====================================================================

set -euo pipefail
IFS=$'\n\t'   # defensive

# -----------------------------------------------------------------
# Logging helpers (timestamped, to stdout / stderr)
# -----------------------------------------------------------------
log_info()  { printf '[%s] INFO: %s\n' "$(date +%T)" "$*" ; }
log_err()   { printf '[%s] ERROR: %s\n' "$(date +%T)" "$*" >&2 ; }
log_debug() { printf '[%s] DEBUG: %s\n' "$(date +%T)" "$*" ; }

# -----------------------------------------------------------------
# Verify that required environment variables are defined
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
# Verify that the redsocks binary is available
# -----------------------------------------------------------------
if ! command -v redsocks >/dev/null 2>&1; then
    log_err "redsocks binary not found in PATH – is the package installed?"
    exit 1
fi

# -----------------------------------------------------------------
# Helper: render the redsocks config from the template
# -----------------------------------------------------------------
render_config() {
    local template="/etc/redsocks.conf.template"
    local target="/etc/redsocks.conf"

    if [[ ! -f "${template}" ]]; then
        log_err "Template file ${template} does not exist."
        exit 1
    fi

    log_info "Rendering redsocks configuration from ${template} ..."
    sed -e "s|{{PROXY_HOST}}|${REDSOCKS_PROXY_HOST}|g" \
        -e "s|{{PROXY_PORT}}|${REDSOCKS_PROXY_PORT}|g" \
        -e "s|{{PROXY_TYPE}}|${REDSOCKS_PROXY_TYPE}|g" \
        "${template}" > "${target}"

    if [[ ! -s "${target}" ]]; then
        log_err "Failed to create a non‑empty ${target}."
        exit 1
    fi
    log_info "Configuration written to ${target}."
}

# -----------------------------------------------------------------
# Install Charles root certificate (if present)
# -----------------------------------------------------------------
install_charles_cert() {
    local mount_path="/tmp/charles.pem"
    local ca_dest="/usr/local/share/ca-certificates/charles.crt"

    if [[ -f "${mount_path}" ]]; then
        log_info "Installing Charles root CA from ${mount_path} ..."
        cp "${mount_path}" "${ca_dest}"
        update-ca-certificates >/dev/null
        log_info "Charles CA installed."
    else
        log_info "No Charles cert mounted at ${mount_path} – skipping."
    fi
}

# -----------------------------------------------------------------
# Start redsocks **in the background**, keep its PID (as a shell variable),
# and verify it.
# -----------------------------------------------------------------
start_redsocks() {
    local cfg="/etc/redsocks.conf"
    local pidfile="/var/run/redsocks.pid"
    local listen_port=12345   # must stay in sync with toggle‑redsocks.sh

    log_info "Launching redsocks …"
    redsocks -c "$cfg" -p "$pidfile" &
    REDSOCKS_PID=$!   # child PID we will later *not* wait for (see below)

    # ---- wait for the PID file -------------------------------------------------
    for i in {1..20}; do   # up to 2 s
        [[ -s "$pidfile" ]] && break
        sleep 0.1
    done
    if [[ ! -s "$pidfile" ]]; then
        log_err "redsocks never wrote its PID file – aborting."
        kill "$REDSOCKS_PID" 2>/dev/null || true
        exit 1
    fi

    # ---- make sure the PID really belongs to a running process -----------------
    local recorded
    recorded=$(<"$pidfile")
    if ! kill -0 "$recorded" 2>/dev/null; then
        log_err "PID file contains a dead PID ($recorded) – aborting."
        kill "$REDSOCKS_PID" 2>/dev/null || true
        exit 1
    fi

    # ---- verify the listening socket (optional but nice) -----------------------
    if ! ss -ltn "sport = :${listen_port}" >/dev/null 2>&1; then
        log_err "redsocks is not listening on ${listen_port} – aborting."
        kill "$recorded" 2>/dev/null || true
        exit 1
    fi

    # Keep a copy for the toggle script (it only needs the number, not the child‑relationship)
    echo "$recorded" > /tmp/redsocks.running.pid
    log_info "redsocks started successfully (PID $recorded)."
}

# -----------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------
render_config
install_charles_cert
start_redsocks

log_info "redsocks ready – forwarding is DISABLED."
log_info "Run 'toggle‑redsocks.sh enable' to start redirection."

# -----------------------------------------------------------------
# Run the user‑provided command *while* redsocks stays alive.
# When no command is given we simply block forever (sleep infinity).
# If a command is supplied we run it, return its exit status,
# and **do not** wait for the redsocks child – the child may have been
# replaced by toggle‑redsocks.sh and is no longer a child of this shell.
# -----------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    log_info "No command supplied – sleeping forever (Ctrl‑C to stop)."
    # `sleep infinity` is available in GNU coreutils (the usual Alpine/Debian base).
    # It blocks the PID‑1 process so the container stays alive.
    exec sleep infinity
else
    log_info "Executing user command: $*"
    "$@"
    user_exit=$?
    log_info "User command exited with status $user_exit."
    # We deliberately **do not** wait for redsocks here – it may have been
    # restarted by the toggle script and is not a child of this process.
    exit $user_exit
fi
