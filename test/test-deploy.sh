#!/bin/bash
# Test deployment script for DHIS2 with Wazuh integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as vagrant user and use sudo when needed."
fi

# Set working directory
cd /opt/dhis2-deploy

log "Starting DHIS2 with Wazuh test deployment..."

# Copy test inventory
log "Copying test inventory..."
cp -f ../test/inventory/hosts inventory/hosts

# Verify inventory
log "Verifying inventory configuration..."
if ! ansible-inventory --list -i inventory/hosts > /dev/null 2>&1; then
    error "Invalid inventory configuration"
fi

# Check if we're in the right directory
if [[ ! -f "dhis2.yml" ]]; then
    error "dhis2.yml not found. Are you in the right directory?"
fi

# Run pre-deployment checks
log "Running pre-deployment checks..."

# Check system requirements
log "Checking system requirements..."
if ! command -v ansible &> /dev/null; then
    error "Ansible is not installed"
fi

if ! command -v python3 &> /dev/null; then
    error "Python3 is not installed"
fi

# Check UFW status
if ! sudo ufw status | grep -q "Status: active"; then
    warn "UFW is not active. The deployment will enable it."
fi

# Run the deployment
log "Starting deployment (this may take 20-30 minutes)..."
log "You can monitor progress with: tail -f /var/log/syslog in another terminal"

# Run deployment with verbose output for testing
if sudo ./deploy.sh -v; then
    log "Deployment completed successfully!"
else
    error "Deployment failed. Check the logs above for details."
fi

# Post-deployment verification
log "Running post-deployment verification..."

# Wait for services to be ready
log "Waiting for services to start up..."
sleep 30

# Check LXD containers
log "Checking LXD containers status..."
sudo lxc list

# Check container connectivity
log "Testing container connectivity..."
for container in proxy postgres dhis monitor wazuh; do
    if sudo lxc info "$container" &>/dev/null; then
        if sudo lxc exec "$container" -- ping -c 1 8.8.8.8 &>/dev/null; then
            log "✓ Container $container is running and has internet connectivity"
        else
            warn "Container $container is running but has no internet connectivity"
        fi
    else
        warn "Container $container is not running"
    fi
done

# Test Wazuh manager
log "Testing Wazuh manager..."
if sudo lxc exec wazuh -- systemctl is-active wazuh-manager &>/dev/null; then
    log "✓ Wazuh manager is running"
else
    warn "Wazuh manager is not running"
fi

# Test Wazuh agents
log "Testing Wazuh agents..."
for container in proxy postgres dhis monitor; do
    if sudo lxc exec "$container" -- systemctl is-active wazuh-agent &>/dev/null 2>&1; then
        log "✓ Wazuh agent is running on $container"
    else
        warn "Wazuh agent is not running on $container"
    fi
done

# Test web services
log "Testing web services..."
if sudo lxc exec proxy -- curl -k -s https://localhost > /dev/null; then
    log "✓ DHIS2 web service is responding"
else
    warn "DHIS2 web service is not responding"
fi

# Show connection information
log "=== DEPLOYMENT SUMMARY ==="
log "DHIS2 URL: https://192.168.56.10 (or https://dhis2-test.local if you add to /etc/hosts)"
log "Default DHIS2 credentials: admin/district"
log ""
log "Wazuh Dashboard Access (requires SSH port forwarding):"
log "  From host machine: ssh -L 5601:172.19.2.40:5601 vagrant@192.168.56.10"
log "  Then visit: https://localhost:5601"
log "  Wazuh credentials: admin/TestPassword123!"
log ""
log "Container IPs:"
sudo lxc list --format csv -c n,4 | grep -v "^$" | while IFS=, read name ip; do
    log "  $name: $ip"
done

log "=== TEST COMPLETED ==="
log "Run './test-verify.sh' to perform detailed functionality tests"