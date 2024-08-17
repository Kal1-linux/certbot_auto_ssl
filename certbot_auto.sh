#!/bin/bash

# Paths and Variables
NGINX_CONFIG_DIR="/etc/nginx/sites-enabled"
EMAIL="deep@tsttechnology.in"
LOG_FILE="/var/log/certbot_automation.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to extract domains from Nginx config files
extract_domains() {
    grep -h 'server_name' "$NGINX_CONFIG_DIR"/* | \
    sed 's/server_name//g' | \
    tr -d ';' | \
    tr -s ' ' | \
    tr ' ' '\n' | \
    grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' | \
    grep -v 'example.com' | \
    grep -v 'example.org' | \
    grep -v 'example.net' | \
    sort -u
}

# Function to check if a domain has valid DNS records
check_dns() {
    local domain=$1
    if host -t A "$domain" >/dev/null 2>&1 || host -t AAAA "$domain" >/dev/null 2>&1; then
        echo "$domain"
    else
        echo "Invalid domain or no DNS record: $domain" >&2
    fi
}

log "Starting Certbot automation script."

# Extract and validate domains
DOMAINS=""
for domain in $(extract_domains); do
    valid_domain=$(check_dns "$domain")
    if [ -n "$valid_domain" ]; then
        DOMAINS="$DOMAINS,$valid_domain"
    fi
done

# Remove leading comma
DOMAINS=${DOMAINS#,}

# Check if any valid domains were found
if [ -z "$DOMAINS" ]; then
    log "No valid domains found in Nginx configuration with DNS records."
    exit 1
fi

log "Domains to be processed: $DOMAINS"

# Run Certbot with the extracted domains and force renewal
log "Running Certbot..."
sudo certbot --nginx --agree-tos -m "$EMAIL" --non-interactive --domains "$DOMAINS" --expand --force-renewal

CERTBOT_EXIT_CODE=$?
if [ $CERTBOT_EXIT_CODE -ne 0 ]; then
    log "Certbot encountered an error. Exit code: $CERTBOT_EXIT_CODE"
    exit $CERTBOT_EXIT_CODE
fi

log "Certbot completed successfully."

# Reload Nginx to apply new certificates
log "Reloading Nginx..."
sudo systemctl reload nginx

log "Nginx reloaded successfully."
log "Certbot automation script finished."
