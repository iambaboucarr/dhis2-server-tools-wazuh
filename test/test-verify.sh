#!/bin/bash
# Verification script for DHIS2 with Wazuh integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
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

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    info "Running test: $test_name"
    
    if eval "$test_command" &>/dev/null; then
        log "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        error "✗ FAIL: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Detailed test function with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    info "Running test: $test_name"
    
    local output
    if output=$(eval "$test_command" 2>&1); then
        log "✓ PASS: $test_name"
        if [[ -n "$output" ]]; then
            echo "  Output: $output"
        fi
        ((TESTS_PASSED++))
        return 0
    else
        error "✗ FAIL: $test_name"
        if [[ -n "$output" ]]; then
            echo "  Error: $output"
        fi
        ((TESTS_FAILED++))
        return 1
    fi
}

log "Starting comprehensive verification of DHIS2 with Wazuh integration..."

# Infrastructure Tests
log "=== INFRASTRUCTURE TESTS ==="

run_test "LXD daemon is running" "sudo systemctl is-active lxd"
run_test "UFW firewall is active" "sudo ufw status | grep -q 'Status: active'"

# Container Tests
log "=== CONTAINER TESTS ==="

containers=("proxy" "postgres" "dhis" "monitor" "wazuh")
for container in "${containers[@]}"; do
    run_test "Container '$container' exists" "sudo lxc info '$container'"
    run_test "Container '$container' is running" "sudo lxc info '$container' | grep -q 'Status: Running'"
    run_test "Container '$container' has network connectivity" "sudo lxc exec '$container' -- ping -c 1 8.8.8.8"
done

# Service Tests
log "=== SERVICE TESTS ==="

# PostgreSQL
run_test "PostgreSQL is running" "sudo lxc exec postgres -- systemctl is-active postgresql"
run_test_with_output "PostgreSQL version" "sudo lxc exec postgres -- sudo -u postgres psql -c 'SELECT version();' | head -1"

# Nginx/Proxy
run_test "Nginx is running" "sudo lxc exec proxy -- systemctl is-active nginx"

# DHIS2
run_test "Tomcat is running" "sudo lxc exec dhis -- systemctl is-active tomcat9"
run_test "DHIS2 responds to HTTP" "sudo lxc exec dhis -- curl -s http://localhost:8080/dhis-web-commons/security/login.action"

# Wazuh Manager
run_test "Wazuh manager is running" "sudo lxc exec wazuh -- systemctl is-active wazuh-manager"
run_test "Wazuh indexer is running" "sudo lxc exec wazuh -- systemctl is-active wazuh-indexer"
run_test "Wazuh dashboard is running" "sudo lxc exec wazuh -- systemctl is-active wazuh-dashboard"

# Wazuh API Tests
run_test "Wazuh API is listening" "sudo lxc exec wazuh -- netstat -tlnp | grep ':55000'"
run_test "Wazuh indexer is listening" "sudo lxc exec wazuh -- netstat -tlnp | grep ':9200'"
run_test "Wazuh dashboard is listening" "sudo lxc exec wazuh -- netstat -tlnp | grep ':5601'"

# Wazuh Agent Tests
log "=== WAZUH AGENT TESTS ==="

agent_containers=("proxy" "postgres" "dhis" "monitor")
for container in "${agent_containers[@]}"; do
    run_test "Wazuh agent is installed on '$container'" "sudo lxc exec '$container' -- dpkg -l | grep wazuh-agent"
    run_test "Wazuh agent is running on '$container'" "sudo lxc exec '$container' -- systemctl is-active wazuh-agent"
    run_test "Wazuh agent is connected from '$container'" "sudo lxc exec '$container' -- /var/ossec/bin/agent-auth -t"
done

# Wazuh Manager Agent List
log "=== WAZUH MANAGER AGENT STATUS ==="
run_test_with_output "List connected agents" "sudo lxc exec wazuh -- /var/ossec/bin/manage_agents -l"

# Security Tests
log "=== SECURITY TESTS ==="

# Test that Wazuh web interfaces are not accessible from outside
run_test "Wazuh dashboard not accessible externally" "! curl -k -m 5 https://192.168.56.10:5601 2>/dev/null"
run_test "Wazuh API not accessible externally" "! curl -k -m 5 https://192.168.56.10:55000 2>/dev/null"
run_test "Wazuh indexer not accessible externally" "! curl -k -m 5 https://192.168.56.10:9200 2>/dev/null"

# Test UFW rules
run_test "UFW denies Wazuh dashboard port" "sudo ufw status | grep '5601.*DENY'"
run_test "UFW denies Wazuh API port" "sudo ufw status | grep '55000.*DENY'"
run_test "UFW denies Wazuh indexer port" "sudo ufw status | grep '9200.*DENY'"

# Log Analysis Tests
log "=== LOG ANALYSIS TESTS ==="

# Check if logs are being collected
run_test "Wazuh manager is receiving logs" "sudo lxc exec wazuh -- test -s /var/ossec/logs/alerts/alerts.log"
run_test "Custom DHIS2 rules are loaded" "sudo lxc exec wazuh -- grep -q 'dhis2' /var/ossec/etc/rules/dhis2_rules.xml"
run_test "Custom LXD rules are loaded" "sudo lxc exec wazuh -- grep -q 'lxd' /var/ossec/etc/rules/lxd_rules.xml"

# Integration Tests
log "=== INTEGRATION TESTS ==="

# Test DHIS2 web access through proxy
run_test "DHIS2 accessible through proxy" "curl -k -s https://192.168.56.10 | grep -q 'DHIS'"

# Test database connectivity
run_test "DHIS2 can connect to database" "sudo lxc exec dhis -- curl -s http://localhost:8080/api/system/info | grep -q 'version'"

# Performance Tests
log "=== PERFORMANCE TESTS ==="

# Check memory usage
run_test_with_output "System memory usage" "free -h | grep Mem"
run_test_with_output "Container memory usage" "sudo lxc list --format csv -c n,s | grep RUNNING | wc -l"

# Check disk usage
run_test_with_output "Disk usage" "df -h / | tail -1"

# Network Tests
log "=== NETWORK TESTS ==="

# Test inter-container communication
run_test "DHIS2 can reach PostgreSQL" "sudo lxc exec dhis -- nc -z postgres 5432"
run_test "Proxy can reach DHIS2" "sudo lxc exec proxy -- nc -z dhis 8080"
run_test "Agents can reach Wazuh manager" "sudo lxc exec dhis -- nc -z wazuh 1514"

# Generate test activity for Wazuh
log "=== GENERATING TEST SECURITY EVENTS ==="

info "Generating failed login attempts for testing..."
for i in {1..3}; do
    sudo lxc exec dhis -- curl -s -X POST http://localhost:8080/dhis-web-commons/security/login.action \
        -d "j_username=testuser&j_password=wrongpass" >/dev/null || true
    sleep 1
done

info "Generating API access for testing..."
sudo lxc exec dhis -- curl -s http://localhost:8080/api/system/info >/dev/null || true

# Wait for events to be processed
info "Waiting for Wazuh to process events..."
sleep 10

# Check if events were captured
run_test "Wazuh captured security events" "sudo lxc exec wazuh -- grep -q 'authentication' /var/ossec/logs/alerts/alerts.log"

# SSH Port Forwarding Test Guide
log "=== SSH PORT FORWARDING TEST GUIDE ==="
info "To test SSH port forwarding to access Wazuh dashboard:"
info "1. From your host machine, run:"
info "   ssh -L 5601:172.19.2.40:5601 vagrant@192.168.56.10"
info "2. Open https://localhost:5601 in your browser"
info "3. Login with: admin/TestPassword123!"
info ""
info "Container IP addresses:"
sudo lxc list --format csv -c n,4 | grep -v "^$" | while IFS=, read name ip; do
    info "  $name: $ip"
done

# Test Summary
log "=== TEST RESULTS SUMMARY ==="
log "Tests Passed: $TESTS_PASSED"
error "Tests Failed: $TESTS_FAILED"
log "Total Tests: $TESTS_TOTAL"

if [[ $TESTS_FAILED -eq 0 ]]; then
    log "🎉 ALL TESTS PASSED! The integration is working correctly."
    exit 0
else
    error "❌ Some tests failed. Please review the output above."
    exit 1
fi