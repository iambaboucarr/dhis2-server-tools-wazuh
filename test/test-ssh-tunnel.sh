#!/bin/bash
# SSH tunnel testing script for Wazuh dashboard access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if we can connect to the VM
if ! nc -z 192.168.56.10 22 2>/dev/null; then
    error "Cannot connect to VM at 192.168.56.10:22. Is the VM running?"
    exit 1
fi

log "Testing SSH tunnel access to Wazuh dashboard..."

# Get Wazuh container IP
info "Getting Wazuh container IP..."
WAZUH_IP=$(ssh -o StrictHostKeyChecking=no vagrant@192.168.56.10 "sudo lxc list --format csv -c n,4 | grep '^wazuh,' | cut -d, -f2 | tr -d ' '")

if [[ -z "$WAZUH_IP" ]]; then
    error "Could not get Wazuh container IP. Is the container running?"
    exit 1
fi

log "Wazuh container IP: $WAZUH_IP"

# Test SSH tunnel setup
info "Setting up SSH tunnels..."
info "Dashboard: ssh -L 5601:$WAZUH_IP:5601 vagrant@192.168.56.10"
info "API: ssh -L 55000:$WAZUH_IP:55000 vagrant@192.168.56.10"
info "Indexer: ssh -L 9200:$WAZUH_IP:9200 vagrant@192.168.56.10"

# Function to test tunnel
test_tunnel() {
    local service_name="$1"
    local local_port="$2"
    local remote_port="$3"
    local test_path="$4"
    
    log "Testing $service_name tunnel (local port $local_port -> $WAZUH_IP:$remote_port)..."
    
    # Set up SSH tunnel in background
    ssh -f -N -L "$local_port:$WAZUH_IP:$remote_port" vagrant@192.168.56.10
    local ssh_pid=$!
    
    # Wait for tunnel to establish
    sleep 3
    
    # Test the connection
    if curl -k -m 10 -s "https://localhost:$local_port$test_path" >/dev/null 2>&1; then
        log "✓ $service_name tunnel working - https://localhost:$local_port$test_path"
        
        # Show some content
        info "Sample response from $service_name:"
        curl -k -s "https://localhost:$local_port$test_path" | head -5 | sed 's/^/  /'
    else
        error "✗ $service_name tunnel failed"
    fi
    
    # Clean up SSH tunnel
    kill $ssh_pid 2>/dev/null || true
    
    echo
}

# Test different tunnels
test_tunnel "Wazuh Dashboard" "5601" "5601" "/"
test_tunnel "Wazuh API" "55000" "55000" "/"
test_tunnel "Wazuh Indexer" "9200" "9200" "/"

# Test multiple tunnels at once
log "Testing multiple tunnels simultaneously..."

# Start all tunnels
ssh -f -N -L "5601:$WAZUH_IP:5601" -L "55000:$WAZUH_IP:55000" -L "9200:$WAZUH_IP:9200" vagrant@192.168.56.10
SSH_PID=$!

sleep 5

# Test all services
DASHBOARD_OK=false
API_OK=false
INDEXER_OK=false

if curl -k -m 10 -s "https://localhost:5601/" >/dev/null 2>&1; then
    log "✓ Dashboard accessible at https://localhost:5601/"
    DASHBOARD_OK=true
else
    error "✗ Dashboard not accessible"
fi

if curl -k -m 10 -s "https://localhost:55000/" >/dev/null 2>&1; then
    log "✓ API accessible at https://localhost:55000/"
    API_OK=true
else
    error "✗ API not accessible"
fi

if curl -k -m 10 -s "https://localhost:9200/" >/dev/null 2>&1; then
    log "✓ Indexer accessible at https://localhost:9200/"
    INDEXER_OK=true
else
    error "✗ Indexer not accessible"
fi

# Clean up
kill $SSH_PID 2>/dev/null || true

# Instructions for manual testing
log "=== MANUAL TESTING INSTRUCTIONS ==="
info "1. Set up SSH tunnel:"
info "   ssh -L 5601:$WAZUH_IP:5601 -L 55000:$WAZUH_IP:55000 vagrant@192.168.56.10"
info ""
info "2. Open in your browser:"
info "   - Wazuh Dashboard: https://localhost:5601"
info "   - Wazuh API: https://localhost:55000"
info ""
info "3. Login credentials:"
info "   - Username: admin"
info "   - Password: TestPassword123!"
info ""
info "4. Test security features:"
info "   - View agent status"
info "   - Check security alerts"
info "   - Verify DHIS2 custom rules"

# Summary
if [[ "$DASHBOARD_OK" == true && "$API_OK" == true && "$INDEXER_OK" == true ]]; then
    log "🎉 All SSH tunnels working correctly!"
    info "You can now securely access Wazuh services through SSH port forwarding."
else
    error "❌ Some tunnels failed. Check the Wazuh services status."
    exit 1
fi