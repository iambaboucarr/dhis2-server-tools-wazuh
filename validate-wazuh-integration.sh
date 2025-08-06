#!/bin/bash
# Quick validation of Wazuh integration
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"; }

TESTS_PASSED=0
TESTS_TOTAL=0

test_check() {
    local name="$1"
    local condition="$2"
    ((TESTS_TOTAL++))
    if eval "$condition"; then
        log "✅ $name"
        ((TESTS_PASSED++))
    else
        error "❌ $name"
    fi
}

log "=== DHIS2 + Wazuh Integration Validation ==="

cd deploy

# Core playbook tests
test_check "DHIS2 playbook syntax" "ansible-playbook --syntax-check dhis2.yml >/dev/null 2>&1"
test_check "Wazuh playbook syntax" "ansible-playbook --syntax-check wazuh.yml >/dev/null 2>&1"

# Key role structure
test_check "Wazuh server role exists" "test -d roles/wazuh-server"
test_check "Wazuh agent role exists" "test -d roles/wazuh-agent"
test_check "Wazuh server tasks" "test -f roles/wazuh-server/tasks/main.yml"
test_check "Wazuh agent tasks" "test -f roles/wazuh-agent/tasks/main.yml"

# Template files
test_check "Wazuh server config template" "test -f roles/wazuh-server/templates/ossec.conf.j2"
test_check "DHIS2 rules template" "test -f roles/wazuh-server/templates/dhis2_rules.xml.j2"
test_check "Wazuh agent config template" "test -f roles/wazuh-agent/templates/ossec.conf.j2"

# Configuration validation
test_check "Internal network config" "grep -q '172.19.2' roles/wazuh-server/defaults/main.yml"
test_check "UFW firewall rules" "grep -q 'ufw' roles/wazuh-server/tasks/*.yml"
test_check "Wazuh server service" "grep -q 'wazuh-manager' roles/wazuh-server/tasks/*.yml"

# Integration checks
test_check "Inventory template" "test -f inventory/hosts.template"
test_check "Wazuh group in inventory" "grep -q 'wazuh' inventory/hosts.template"

# Security configurations
test_check "No hardcoded passwords" "! grep -r 'password.*=' roles/wazuh-* --include='*.yml' --include='*.j2' | grep -v 'password_length'"
test_check "Agent registration key" "grep -q 'agent.*key' roles/wazuh-agent/templates/ossec.conf.j2"

SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))

log "=== VALIDATION SUMMARY ==="
info "Tests Passed: $TESTS_PASSED / $TESTS_TOTAL"
info "Success Rate: ${SUCCESS_RATE}%"

if [[ $SUCCESS_RATE -ge 80 ]]; then
    log "🎉 Wazuh integration validation PASSED!"
    log "✅ Core components are properly configured"
    log "✅ Security monitoring is ready for deployment"
    exit 0
else
    error "❌ Validation FAILED - Issues need to be addressed"
    exit 1
fi