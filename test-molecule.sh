#!/bin/bash
# Professional Molecule test runner for DHIS2 + Wazuh integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCENARIOS=("default" "wazuh-only" "full-stack")
PARALLEL=${PARALLEL:-false}
CLEANUP=${CLEANUP:-true}
VERBOSE=${VERBOSE:-false}

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_SCENARIOS=()

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

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if molecule is installed
    if ! command -v molecule &> /dev/null; then
        error "Molecule is not installed. Install it with: pip install -r requirements-test.txt"
        exit 1
    fi
    
    # Check if ansible is installed
    if ! command -v ansible &> /dev/null; then
        error "Ansible is not installed. Install it with: pip install -r requirements-test.txt"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Function to setup test environment
setup_environment() {
    log "Setting up test environment..."
    
    # Install Ansible collections
    ansible-galaxy install -r requirements.yml --force || warn "Failed to install some requirements"
    
    # Create molecule config directory
    mkdir -p ~/.config/molecule
    
    # Set environment variables
    export MOLECULE_NO_LOG=false
    export ANSIBLE_FORCE_COLOR=1
    export PYTHONPATH="${PYTHONPATH}:$(pwd)"
    
    log "Test environment setup complete"
}

# Function to run a single scenario
run_scenario() {
    local scenario="$1"
    local start_time=$(date +%s)
    
    log "Running Molecule scenario: $scenario"
    
    if [[ "$VERBOSE" == "true" ]]; then
        molecule_cmd="molecule test -s $scenario --destroy=never"
    else
        molecule_cmd="molecule test -s $scenario"
    fi
    
    # Add debug flag if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        molecule_cmd="$molecule_cmd -vvv"
    fi
    
    # Run the test
    if eval "$molecule_cmd"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "✅ Scenario '$scenario' PASSED (${duration}s)"
        ((TESTS_PASSED++))
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        error "❌ Scenario '$scenario' FAILED (${duration}s)"
        FAILED_SCENARIOS+=("$scenario")
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to run cleanup
cleanup_environment() {
    if [[ "$CLEANUP" == "true" ]]; then
        log "Cleaning up test environment..."
        
        for scenario in "${SCENARIOS[@]}"; do
            info "Destroying scenario: $scenario"
            molecule destroy -s "$scenario" || warn "Failed to destroy scenario $scenario"
        done
        
        # Clean up Docker networks and volumes
        docker network prune -f || warn "Failed to clean up Docker networks"
        docker volume prune -f || warn "Failed to clean up Docker volumes"
        
        log "Cleanup complete"
    fi
}

# Function to generate test report
generate_report() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local success_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / total_tests))
    fi
    
    echo
    log "=================================================="
    log "           MOLECULE TEST RESULTS SUMMARY           "
    log "=================================================="
    log "Total Scenarios: $total_tests"
    log "Passed: $TESTS_PASSED"
    log "Failed: $TESTS_FAILED"
    log "Success Rate: ${success_rate}%"
    
    if [[ ${#FAILED_SCENARIOS[@]} -gt 0 ]]; then
        error "Failed Scenarios: ${FAILED_SCENARIOS[*]}"
    fi
    
    log "=================================================="
    
    # Generate JUnit XML report if pytest is available
    if command -v pytest &> /dev/null; then
        info "Generating JUnit XML report..."
        pytest --junit-xml=molecule-test-results.xml --collect-only || warn "Failed to generate XML report"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [SCENARIOS...]"
    echo
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  -v, --verbose      Run with verbose output"
    echo "  -p, --parallel     Run scenarios in parallel (experimental)"
    echo "  -c, --no-cleanup   Skip cleanup after tests"
    echo "  -l, --list         List available scenarios"
    echo
    echo "Scenarios:"
    echo "  default            Basic Wazuh + DHIS2 integration test"
    echo "  wazuh-only         Wazuh server standalone test"
    echo "  full-stack         Complete infrastructure test"
    echo
    echo "Environment Variables:"
    echo "  PARALLEL=true      Enable parallel execution"
    echo "  CLEANUP=false      Disable cleanup"
    echo "  VERBOSE=true       Enable verbose output"
    echo
    echo "Examples:"
    echo "  $0                 Run all scenarios"
    echo "  $0 default         Run only default scenario"
    echo "  $0 -v wazuh-only   Run wazuh-only with verbose output"
    echo "  PARALLEL=true $0   Run all scenarios in parallel"
}

# Function to list scenarios
list_scenarios() {
    echo "Available Molecule scenarios:"
    for scenario in "${SCENARIOS[@]}"; do
        echo "  - $scenario"
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -c|--no-cleanup)
            CLEANUP=false
            shift
            ;;
        -l|--list)
            list_scenarios
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            # Remaining arguments are scenario names
            SCENARIOS=("$@")
            break
            ;;
    esac
done

# Main execution
main() {
    local start_time=$(date +%s)
    
    log "Starting DHIS2 + Wazuh Molecule Tests"
    log "Scenarios to run: ${SCENARIOS[*]}"
    log "Parallel execution: $PARALLEL"
    log "Cleanup after tests: $CLEANUP"
    log "Verbose output: $VERBOSE"
    
    # Setup trap for cleanup on exit
    trap cleanup_environment EXIT
    
    # Run prerequisite checks
    check_prerequisites
    setup_environment
    
    # Run scenarios
    if [[ "$PARALLEL" == "true" ]]; then
        warn "Parallel execution is experimental and may cause resource conflicts"
        # Run scenarios in parallel
        for scenario in "${SCENARIOS[@]}"; do
            run_scenario "$scenario" &
        done
        wait
    else
        # Run scenarios sequentially
        for scenario in "${SCENARIOS[@]}"; do
            run_scenario "$scenario"
        done
    fi
    
    # Generate report
    generate_report
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    log "Total test execution time: ${total_duration} seconds"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "🎉 All Molecule tests passed!"
        exit 0
    else
        error "❌ Some Molecule tests failed"
        exit 1
    fi
}

# Run main function
main "$@"