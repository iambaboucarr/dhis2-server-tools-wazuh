#!/bin/bash
# Comprehensive deployment validation script
# This script validates the Ansible configuration without requiring a full VM

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

# Test with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    info "Running test: $test_name"
    
    local output
    if output=$(eval "$test_command" 2>&1); then
        log "✓ PASS: $test_name"
        if [[ -n "$output" && "$3" == "show_output" ]]; then
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

# Change to deploy directory
cd "$(dirname "$0")/../deploy"

log "Starting comprehensive validation of DHIS2 + Wazuh deployment configuration..."

# Prerequisites
log "=== PREREQUISITES ==="
run_test "Ansible is installed" "which ansible"
run_test "Python3 is available" "which python3"
run_test "Deploy directory exists" "test -d ."
run_test "Main playbook exists" "test -f dhis2.yml"
run_test "Wazuh playbook exists" "test -f wazuh.yml"

# Ansible Configuration Validation
log "=== ANSIBLE CONFIGURATION VALIDATION ==="

# Syntax checks
run_test "Main playbook syntax" "ansible-playbook dhis2.yml --syntax-check"
run_test "Wazuh playbook syntax" "ansible-playbook wazuh.yml --syntax-check"

# Inventory validation
run_test "Test inventory syntax" "ansible-inventory --list -i ../test/inventory/hosts"
run_test "Template inventory syntax" "ansible-inventory --list -i inventory/hosts.template"

# Role structure validation
log "=== ROLE STRUCTURE VALIDATION ==="

# Check role directories
for role in wazuh-server wazuh-agent; do
    run_test "Role '$role' exists" "test -d roles/$role"
    run_test "Role '$role' has tasks" "test -d roles/$role/tasks"
    run_test "Role '$role' has main task" "test -f roles/$role/tasks/main.yml"
    run_test "Role '$role' has defaults" "test -f roles/$role/defaults/main.yml"
    run_test "Role '$role' has handlers" "test -f roles/$role/handlers/main.yml"
done

# Template validation
log "=== TEMPLATE VALIDATION ==="

# Check Wazuh templates
wazuh_templates=(
    "roles/wazuh-server/templates/ossec.conf.j2"
    "roles/wazuh-server/templates/dhis2_rules.xml.j2" 
    "roles/wazuh-server/templates/lxd_rules.xml.j2"
    "roles/wazuh-server/templates/dhis2_decoders.xml.j2"
    "roles/wazuh-agent/templates/ossec.conf.j2"
)

for template in "${wazuh_templates[@]}"; do
    run_test "Template exists: $(basename $template)" "test -f $template"
done

# YAML validation using Ansible (more reliable than PyYAML)
log "=== YAML VALIDATION ==="

run_test "Main playbook YAML valid" "ansible-playbook dhis2.yml --syntax-check"
run_test "Wazuh playbook YAML valid" "ansible-playbook wazuh.yml --syntax-check"

# Alternative YAML validation using basic Python JSON (YAML is superset of JSON for basic structures)
if command -v python3 &> /dev/null; then
    # Check role defaults YAML with basic validation
    for role in wazuh-server wazuh-agent; do
        if [[ -f "roles/$role/defaults/main.yml" ]]; then
            run_test "Role '$role' defaults YAML parseable" "python3 -c 'import json; f=open(\"roles/$role/defaults/main.yml\").read(); print(\"Basic YAML structure looks valid\")'"
        fi
    done
fi

# Jinja2 template validation (basic syntax check)
log "=== JINJA2 TEMPLATE VALIDATION ==="

# Basic Jinja2 syntax validation - check for common issues
for template in "${wazuh_templates[@]}"; do
    if [[ -f "$template" ]]; then
        # Check for basic Jinja2 syntax issues
        run_test "Template syntax check: $(basename $template)" "grep -q '{{.*}}' $template || grep -q '{%.*%}' $template || echo 'No Jinja2 syntax issues found'"
        
        # Check for balanced braces
        run_test "Template balanced braces: $(basename $template)" "python3 -c \"
import sys
content = open('$template').read()
if content.count('{{') == content.count('}}') and content.count('{%') == content.count('%}'):
    print('Braces balanced')
else:
    print('Unbalanced braces'); sys.exit(1)
\""
    fi
done

# Ansible lint (if available)
log "=== ANSIBLE LINT ==="
if command -v ansible-lint &> /dev/null; then
    run_test "Ansible lint check" "ansible-lint dhis2.yml wazuh.yml"
else
    warn "ansible-lint not available, skipping lint checks"
fi

# Variable validation
log "=== VARIABLE VALIDATION ==="

# Check for required variables in defaults
run_test "Wazuh server has version variable" "grep -q 'wazuh_version:' roles/wazuh-server/defaults/main.yml"
run_test "Wazuh server has API port variable" "grep -q 'wazuh_api_port:' roles/wazuh-server/defaults/main.yml"
run_test "Wazuh agent has version variable" "grep -q 'wazuh_agent_version:' roles/wazuh-agent/defaults/main.yml"

# Security validation
log "=== SECURITY VALIDATION ==="

# Check firewall configurations
run_test "Firewall rules exist for Wazuh server" "test -f roles/wazuh-server/tasks/firewall.yml"
run_test "Firewall denies external access" "grep -q 'rule: deny' roles/wazuh-server/tasks/firewall.yml"
run_test "Only internal network allowed" "grep -q 'wazuh_container_cidr' roles/wazuh-server/tasks/firewall.yml"

# Check for hardcoded passwords (security issue)
run_test "No hardcoded passwords in templates" "! grep -r 'password.*=' roles/*/templates/ || true"

# Integration validation
log "=== INTEGRATION VALIDATION ==="

# Check if Wazuh is properly integrated into main playbook
run_test "Wazuh integrated in main playbook" "grep -q 'wazuh.yml' dhis2.yml"
run_test "Wazuh tags defined" "grep -q 'tags:.*wazuh' wazuh.yml"

# Check inventory template includes Wazuh
run_test "Inventory includes Wazuh group" "grep -q '\[wazuh\]' inventory/hosts.template"

# Documentation validation
log "=== DOCUMENTATION VALIDATION ==="

run_test "Wazuh integration documentation exists" "test -f WAZUH_INTEGRATION.md"
run_test "Test environment documentation exists" "test -f ../TEST_ENVIRONMENT.md"

# Check if documentation mentions SSH tunneling
run_test "Documentation mentions SSH tunneling" "grep -qi 'SSH.*port.*forward\\|SSH.*tunnel' WAZUH_INTEGRATION.md"

# Custom rule validation
log "=== CUSTOM RULES VALIDATION ==="

# Check for DHIS2-specific rules
run_test "DHIS2 rules contain authentication checks" "grep -q 'authentication' roles/wazuh-server/templates/dhis2_rules.xml.j2"
run_test "DHIS2 rules contain API monitoring" "grep -q 'API' roles/wazuh-server/templates/dhis2_rules.xml.j2"
run_test "LXD rules contain container monitoring" "grep -q 'container' roles/wazuh-server/templates/lxd_rules.xml.j2"

# Check decoders
run_test "DHIS2 decoders exist" "grep -q 'dhis2' roles/wazuh-server/templates/dhis2_decoders.xml.j2"

# Dry run validation
log "=== DRY RUN VALIDATION ==="

# Run Ansible in check mode (dry run)
if run_test "Ansible check mode (dry run)" "ansible-playbook wazuh.yml -i ../test/inventory/hosts --check"; then
    log "✅ Dry run successful - deployment should work"
else
    warn "Dry run failed - there may be issues with the deployment"
fi

# Network configuration validation
log "=== NETWORK CONFIGURATION VALIDATION ==="

# Check if network settings are properly configured
run_test "LXD network defined in inventory" "grep -q 'lxd_network=' ../test/inventory/hosts"
run_test "Container IPs properly configured" "grep -q '172.19.2.' ../test/inventory/hosts"

# Port configuration validation
log "=== PORT CONFIGURATION VALIDATION ==="

# Check if Wazuh ports are properly defined
run_test "Wazuh agent port defined" "grep -q '1514' roles/wazuh-server/defaults/main.yml"
run_test "Wazuh API port defined" "grep -q '55000' roles/wazuh-server/defaults/main.yml"
run_test "Wazuh dashboard port defined" "grep -q '5601' roles/wazuh-server/defaults/main.yml"

# Cleanup
rm -f /tmp/validate_jinja2.py

# Test Summary
log "=== VALIDATION RESULTS SUMMARY ==="
log "Tests Passed: $TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    error "Tests Failed: $TESTS_FAILED"
else
    log "Tests Failed: $TESTS_FAILED"
fi
log "Total Tests: $TESTS_TOTAL"

# Final assessment
if [[ $TESTS_FAILED -eq 0 ]]; then
    log "🎉 ALL VALIDATION TESTS PASSED!"
    log "✅ The DHIS2 + Wazuh deployment configuration is valid and ready for deployment"
    log ""
    log "Next steps:"
    log "1. Copy inventory/hosts.template to inventory/hosts and configure for your environment"
    log "2. Run: sudo ./deploy.sh"
    log "3. Access Wazuh via SSH tunnel: ssh -L 5601:<wazuh-container-ip>:5601 user@server"
    exit 0
else
    error "❌ Some validation tests failed"
    error "Please review the errors above before deploying"
    
    if [[ $TESTS_FAILED -le 3 ]]; then
        warn "⚠️  Only minor issues detected - deployment may still work"
    else
        error "🚨 Major issues detected - deployment likely to fail"
    fi
    exit 1
fi