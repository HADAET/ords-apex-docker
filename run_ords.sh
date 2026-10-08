bash
#!/bin/bash

set -Eeuo pipefail

###############################################################################
# Oracle REST Data Services startup / installation script
#
# First start:
#   - Installs ORDS into the database
#   - Uses SYS only as the administrator
#   - Creates/configures ORDS_PUBLIC_USER
#   - Starts ORDS
#
# Subsequent starts:
#   - Detect existing ORDS configuration
#   - Skip installation
#   - Start ORDS directly
###############################################################################

ORDS_DIR="/opt/ords"
ORDS_BIN="${ORDS_DIR}/bin/ords"

ORDS_CONFIG_DIR="${ORDS_CONFIG_DIR:-/opt/ords-config}"
ORDS_PORT="${ORDS_PORT:-8085}"
APEX_IMAGES="${APEX_IMAGES:-/opt/oracle/apex/images}"

POOL_FILE="${ORDS_CONFIG_DIR}/databases/default/pool.xml"


###############################################################################
# Logging
###############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}


###############################################################################
# Error handling
###############################################################################

trap '
    error "ORDS startup failed."
    error "Check the ORDS output above for the actual error."
' ERR


###############################################################################
# Required environment variables
###############################################################################

require_env() {
    local name="$1"

    if [ -z "${!name:-}" ]; then
        error "Required environment variable '$name' is not set."
        exit 1
    fi
}


###############################################################################
# Validate ORDS installation
###############################################################################

if [ ! -d "$ORDS_DIR" ]; then
    error "ORDS directory not found: $ORDS_DIR"
    exit 1
fi

if [ ! -x "$ORDS_BIN" ]; then
    error "ORDS executable not found: $ORDS_BIN"
    exit 1
fi


###############################################################################
# Validate database configuration
###############################################################################

require_env "DB_HOSTNAME"
require_env "DB_PORT"
require_env "DB_SERVICENAME"
require_env "SYS_PASS"


###############################################################################
# Display configuration
#
# Never display passwords.
###############################################################################

log "============================================================"
log "Oracle REST Data Services"
log "============================================================"
log "ORDS directory       : $ORDS_DIR"
log "ORDS config directory: $ORDS_CONFIG_DIR"
log "Database host        : $DB_HOSTNAME"
log "Database port        : $DB_PORT"
log "Database service     : $DB_SERVICENAME"
log "Runtime database user: ORDS_PUBLIC_USER"
log "HTTP port            : $ORDS_PORT"
log "APEX images          : $APEX_IMAGES"
log "============================================================"


###############################################################################
# Prepare configuration directory
###############################################################################

mkdir -p "$ORDS_CONFIG_DIR"


###############################################################################
# Existing installation?
###############################################################################

if [ -f "$POOL_FILE" ]; then

    log "Existing ORDS configuration found:"
    log "  $POOL_FILE"

    ###########################################################################
    # Check runtime username.
    ###########################################################################

    POOL_USERNAME="$(
        grep -oE '<entry key="db.username">[^<]+' "$POOL_FILE" 2>/dev/null |
        sed 's/.*>//' |
        head -n 1 || true
    )"

    if [ -n "$POOL_USERNAME" ]; then
        log "Configured ORDS pool user: $POOL_USERNAME"

        #######################################################################
        # SYS must NEVER be the ORDS runtime user.
        #######################################################################

        if [ "$POOL_USERNAME" = "SYS" ]; then
            error "The ORDS pool is configured to use SYS."
            error "SYS must not be used as the ORDS runtime user."
            error "Remove the existing ORDS configuration and reinstall ORDS."
            exit 1
        fi
    fi

    log "Skipping ORDS installation."

else

    log "No existing ORDS configuration found."
    log "Starting first-time ORDS installation..."
    log "Database administrator: SYS"
    log "Database: ${DB_HOSTNAME}:${DB_PORT}/${DB_SERVICENAME}"

    ###########################################################################
    # IMPORTANT:
    #
    # ORDS 26.3 does NOT allow:
    #
    #     --db-user SYS
    #
    # SYS is supplied through --admin-user.
    #
    # Therefore DO NOT pass --db-user SYS.
    ###########################################################################

    log "Installing ORDS database schemas..."

    if [ -n "${ORDS_PASS:-}" ]; then

        log "Using supplied ORDS runtime password."

        printf '%s\n%s\n' \
            "$SYS_PASS" \
            "$ORDS_PASS" |
        "$ORDS_BIN" \
            --config "$ORDS_CONFIG_DIR" \
            install \
            --admin-user SYS \
            --db-hostname "$DB_HOSTNAME" \
            --db-port "$DB_PORT" \
            --db-servicename "$DB_SERVICENAME" \
            --feature-db-api true \
            --feature-rest-enabled-sql true \
            --proxy-user \
            --password-stdin

    else

        log "No ORDS_PASS supplied."
        log "ORDS will generate the ORDS runtime user password."

        printf '%s\n' \
            "$SYS_PASS" |
        "$ORDS_BIN" \
            --config "$ORDS_CONFIG_DIR" \
            install \
            --admin-user SYS \
            --db-hostname "$DB_HOSTNAME" \
            --db-port "$DB_PORT" \
            --db-servicename "$DB_SERVICENAME" \
            --feature-db-api true \
            --feature-rest-enabled-sql true \
            --proxy-user \
            --password-stdin

    fi

    ###########################################################################
    # Verify installation
    ###########################################################################

    if [ ! -f "$POOL_FILE" ]; then
        error "ORDS installation finished but pool.xml was not created."
        error "Expected:"
        error "  $POOL_FILE"
        exit 1
    fi

    log "ORDS installation completed successfully."


    ###########################################################################
    # Verify runtime user
    ###########################################################################

    POOL_USERNAME="$(
        grep -oE '<entry key="db.username">[^<]+' "$POOL_FILE" 2>/dev/null |
        sed 's/.*>//' |
        head -n 1 || true
    )"

    if [ -n "$POOL_USERNAME" ]; then
        log "Configured ORDS pool user: $POOL_USERNAME"
    fi

    if [ "$POOL_USERNAME" = "SYS" ]; then
        error "Installation produced an invalid ORDS pool configuration."
        error "ORDS runtime user must not be SYS."
        exit 1
    fi

fi


###############################################################################
# Start ORDS
###############################################################################

log "Starting ORDS..."
log "HTTP port: $ORDS_PORT"

exec "$ORDS_BIN" \
    --config "$ORDS_CONFIG_DIR" \
    serve \
    --port "$ORDS_PORT" \
    --apex-images "$APEX_IMAGES"