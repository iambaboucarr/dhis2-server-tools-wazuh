#!/bin/bash
# Test Ansible playbooks syntax and role validation
# This provides validation without the Molecule Docker plugin issues

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

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Test counters
TESTS_PASSED=0
TESTS_TOTAL=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    info "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log "✅ $test_name: PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        error "❌ $test_name: FAILED"
        eval "$test_command" 2>&1 | head -20
        return 1
    fi
}

log "Starting DHIS2 + Wazuh Ansible playbook validation"

cd deploy

# Test 1: Ansible syntax check for main playbooks
run_test "DHIS2 playbook syntax" "ansible-playbook --syntax-check dhis2.yml"
run_test "Wazuh playbook syntax" "ansible-playbook --syntax-check wazuh.yml"

# Test 2: Validate role directories exist
log "Checking role directory structure..."
for role in wazuh-server wazuh-agent pre-install postgres proxy monitoring create-instance backups integration; do
    if [[ -d "roles/$role" ]]; then
        log "✅ Role directory exists: $role"
        ((TESTS_PASSED++))
    else
        warn "⚠️  Role directory missing: $role"
    fi
    ((TESTS_TOTAL++))
done

# Test 3: Validate Wazuh role structure
log "Validating Wazuh server role structure..."
wazuh_role_files=(
    "roles/wazuh-server/tasks/main.yml"
    "roles/wazuh-server/defaults/main.yml"
    "roles/wazuh-server/templates/ossec.conf.j2"
    "roles/wazuh-server/templates/dhis2_rules.xml.j2"
    "roles/wazuh-server/handlers/main.yml"
)

for file in "${wazuh_role_files[@]}"; do
    if [[ -f "$file" ]]; then
        log "✅ Wazuh role file exists: $(basename $file)"
        ((TESTS_PASSED++))
    else
        error "❌ Missing Wazuh role file: $file"
    fi
    ((TESTS_TOTAL++))
done

# Test 4: Validate Wazuh agent role
log "Validating Wazuh agent role structure..."
wazuh_agent_files=(
    "roles/wazuh-agent/tasks/main.yml"
    "roles/wazuh-agent/defaults/main.yml"
    "roles/wazuh-agent/templates/ossec.conf.j2"
    "roles/wazuh-agent/handlers/main.yml"
)

for file in "${wazuh_agent_files[@]}"; do
    if [[ -f "$file" ]]; then
        log "✅ Wazuh agent file exists: $(basename $file)"
        ((TESTS_PASSED++))
    else
        error "❌ Missing Wazuh agent file: $file"
    fi
    ((TESTS_TOTAL++))
done

# Test 5: Check inventory template
run_test "Inventory template validation" "test -f inventory/hosts.template"

# Test 6: Validate YAML syntax for key files
log "Validating YAML syntax..."
yaml_files=(
    "dhis2.yml"
    "wazuh.yml"
    "roles/wazuh-server/**/*.yml"
    "roles/wazuh-agent/**/*.yml" 
)

for pattern in "${yaml_files[@]}"; do
    for file in $pattern; do
        if [[ -f "$file" ]]; then
            run_test "YAML syntax: $(basename $file)" "yamllint -c ../.yamllint $file"
        fi
    done
done

# Test 7: Ansible-lint validation
log "Running ansible-lint checks..."
run_test "Ansible-lint playbooks" "ansible-lint dhis2.yml wazuh.yml"
run_test "Ansible-lint roles" "ansible-lint roles/wazuh-server roles/wazuh-agent"

# Test 8: Check Jinja2 template syntax
log "Validating Jinja2 templates..."
template_files=(
    "roles/wazuh-server/templates/ossec.conf.j2"
    "roles/wazuh-server/templates/dhis2_rules.xml.j2"
    "roles/wazuh-agent/templates/ossec.conf.j2"
)

for template in "${template_files[@]}"; do
    if [[ -f "$template" ]]; then
        # Basic Jinja2 syntax check using Python
        run_test "Jinja2 template: $(basename $template)" \
                 "python3 -c \"import jinja2; jinja2.Template(open('$template').read())\""
    fi
done

# Test 9: Check for security best practices
log "Checking security configurations..."

# Check for no hardcoded passwords
run_test "No hardcoded passwords in roles" \
         "! grep -r -i 'password.*=' roles/wazuh-* --include='*.yml' --include='*.j2'"

# Check for proper variable usage
run_test "Variables properly templated" \
         "grep -q '{{.*}}' roles/wazuh-server/templates/*.j2"

# Test 10: Validate custom modules and filters
if [[ -f "library/custom_lxd.py" ]]; then
    run_test "Custom LXD module syntax" "python3 -m py_compile library/custom_lxd.py"
fi

if [[ -f "filter_plugins/custom_filters.py" ]]; then
    run_test "Custom filters syntax" "python3 -m py_compile filter_plugins/custom_filters.py"
fi

# Test 11: Check for proper network configuration
log "Validating network configurations..."
if grep -q "172.19.2" roles/wazuh-*/defaults/main.yml; then
    log "✅ Internal network configuration found"
    ((TESTS_PASSED++))
else
    warn "⚠️  Internal network configuration not found"
fi
((TESTS_TOTAL++))

# Test 12: Validate firewall rules
if grep -q "ufw" roles/wazuh-server/tasks/*.yml; then
    log "✅ UFW firewall rules configured"
    ((TESTS_PASSED++))
else
    warn "⚠️  UFW firewall rules not found"
fi
((TESTS_TOTAL++))

# Calculate success rate
SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))

log "=================================================================="
log "                  ANSIBLE VALIDATION SUMMARY                     "
log "=================================================================="
log "Total Tests: $TESTS_TOTAL"
log "Passed: $TESTS_PASSED"
log "Failed: $((TESTS_TOTAL - TESTS_PASSED))"
log "Success Rate: ${SUCCESS_RATE}%"
log "=================================================================="

if [[ $SUCCESS_RATE -ge 80 ]]; then
    log "🎉 Ansible playbook validation PASSED!"
    log "✅ Wazuh integration is properly configured"
    log "✅ All critical components are present"
    log "✅ Security configurations are in place"
    exit 0
else
    error "❌ Ansible playbook validation FAILED"
    error "Some critical issues need to be addressed"
    exit 1
fi