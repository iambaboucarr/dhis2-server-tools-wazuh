# Molecule Testing Infrastructure

This document explains the comprehensive testing infrastructure for DHIS2 Server Tools with Wazuh security integration.

## Overview

The project uses [Molecule](https://molecule.readthedocs.io/) for testing Ansible playbooks and roles. Molecule provides a framework for testing infrastructure code by creating Docker containers, running playbooks, and verifying the results.

## Test Scenarios

### 1. `default` - Basic DHIS2 + Wazuh Integration Test
**Location**: `molecule/default/`

**Purpose**: Tests basic DHIS2 deployment with Wazuh security monitoring integration

**Components Tested**:
- DHIS2 installation and configuration
- Wazuh manager deployment on dedicated container
- Wazuh agent deployment on DHIS2 instances
- Service connectivity and registration
- Basic security configuration

**Docker Images**: 
- `ghcr.io/hifis-net/ubuntu-systemd:22.04` (systemd-enabled Ubuntu for proper service testing)

**Containers**:
- `wazuh-server` - Runs Wazuh manager, indexer, and dashboard
- `dhis2-instance` - Runs DHIS2 with Wazuh agent

### 2. `wazuh` - Wazuh-Only Single Node Test  
**Location**: `molecule/wazuh/`

**Purpose**: Tests standalone Wazuh deployment using official Ansible roles

**Components Tested**:
- Single-node Wazuh cluster (manager + indexer + dashboard)
- Official Wazuh Ansible roles integration
- Certificate generation and security setup
- Service startup and health checks

**Docker Images**:
- `geerlingguy/docker-ubuntu2204-ansible:latest`

### 3. `full-stack` - Complete Infrastructure Test
**Location**: `molecule/full-stack/`

**Purpose**: Tests complete DHIS2 infrastructure including all components

**Components**: Database, proxy, monitoring, instances, Wazuh integration

## Prerequisites

### 1. Virtual Environment Setup
```bash
# Use existing virtual environment
source molecule-venv/bin/activate

# Or create new one
python3 -m venv molecule-venv
source molecule-venv/bin/activate
pip install -r requirements/molecule.txt
```

### 2. Required Versions
The project requires specific compatible versions:
- `ansible-core==2.14.15` (not 2.19.x which has Docker plugin issues)
- `molecule==6.0.3` 
- `molecule-plugins[docker]==23.5.3`

### 3. Docker Requirements
- Docker daemon running
- Sufficient resources (4GB+ RAM recommended for full tests)
- Network access to pull container images

## Test Execution

### Quick Validation Tests

```bash
# Activate compatible environment
source molecule-venv/bin/activate

# Basic syntax validation (always works)
molecule syntax -s default

# List available scenarios
molecule list

# Test specific scenario
molecule syntax -s wazuh
```

### Development Testing Workflow

```bash
# 1. Syntax check (fast)
molecule syntax -s default

# 2. Create containers (may take time for image pulls)
molecule create -s default

# 3. Check container status
molecule list -s default

# 4. Run prepare phase (install dependencies)
molecule prepare -s default

# 5. Run converge (execute playbook)
molecule converge -s default

# 6. Run verification tests
molecule verify -s default

# 7. Test idempotence (no changes on re-run)
molecule idempotence -s default

# 8. Full test cycle
molecule test -s default
```

### Scenario-Specific Testing

```bash
# Test Wazuh-only deployment
molecule test -s wazuh

# Test with different scenarios
molecule test -s full-stack
```

## Test Structure

### File Organization
```
molecule/
├── default/                 # Main integration test
│   ├── molecule.yml        # Test configuration
│   ├── converge.yml        # Playbook to test
│   ├── prepare.yml         # Container preparation
│   ├── verify.yml          # Verification tests
│   └── tests/
│       └── test_default.py # Python tests (testinfra)
├── wazuh/                  # Wazuh-specific tests
│   ├── molecule.yml
│   ├── converge.yml
│   └── verify.yml
└── full-stack/             # Complete infrastructure tests
    └── molecule.yml
```

### Test Types

#### 1. Syntax Tests (`molecule syntax`)
- Validates Ansible playbook syntax
- Checks for undefined variables
- Verifies role dependencies
- **Fast execution** - always run this first

#### 2. Convergence Tests (`molecule converge`)
- Executes actual playbook deployment
- Creates and configures services
- Installs packages and dependencies
- **Resource intensive** - requires Docker containers

#### 3. Verification Tests (`molecule verify`)
- Runs comprehensive service checks
- Validates configuration files
- Tests network connectivity  
- Checks security settings
- Uses both Ansible tasks and Python tests

#### 4. Idempotence Tests (`molecule idempotence`)
- Re-runs playbook to ensure no changes
- Validates configuration stability
- Ensures proper Ansible idempotency

## Verification Test Details

### Wazuh Manager Tests
- ✅ Package installation verification
- ✅ Service status (wazuh-manager active)
- ✅ Port accessibility (1514, 55000)
- ✅ Configuration file existence
- ✅ Custom DHIS2 rules validation
- ✅ LXD monitoring rules  
- ✅ API connectivity test
- ✅ Log file creation

### Wazuh Agent Tests
- ✅ Agent package installation
- ✅ Agent service status
- ✅ Manager connection configuration
- ✅ Agent registration (client.keys)
- ✅ Connectivity to manager
- ✅ Log analysis

### Integration Tests
- ✅ Agent-to-manager connectivity
- ✅ Event collection and alerting
- ✅ Security configuration validation
- ✅ Firewall rule verification (simulated)

### Python Tests (testinfra)
Located in `tests/test_default.py`:
- Package installation checks
- Service status verification
- Port listening validation
- Directory permissions testing
- File existence and ownership

## Environment Variables

### Required for Docker Plugin Compatibility
```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=True
export ANSIBLE_CONFIG=ansible.cfg
```

### Debug and Development
```bash
export MOLECULE_DEBUG=1          # Enable debug output
export MOLECULE_VERBOSITY=2      # Increase verbosity
export ANSIBLE_STDOUT_CALLBACK=yaml  # Better output format
```

## Troubleshooting

### Common Issues

#### 1. Docker Plugin Conditionals Error
**Error**: `Conditional result was '/path' of type 'str'`
**Solution**: Use virtual environment with ansible-core 2.14.x

#### 2. Container Creation Timeout
**Error**: Container fails to start or times out
**Solutions**:
- Increase Docker resources
- Check Docker daemon status
- Use `molecule create --debug` for details

#### 3. Service Start Failures
**Error**: Wazuh services fail to start in containers
**Solutions**:
- Verify systemd support in container image
- Check container privileges and capabilities
- Review prepare.yml for missing dependencies

#### 4. Network Connectivity Issues
**Error**: Agents cannot connect to manager
**Solutions**:
- Verify Docker network creation
- Check container name resolution
- Validate port mappings

### Debug Commands

```bash
# Check container status
docker ps -a

# Inspect container logs
docker logs <container-name>

# Access container shell
docker exec -it <container-name> /bin/bash

# Check Molecule inventory
molecule --debug list -s default

# Run with maximum verbosity
molecule --debug test -s default
```

## Performance Considerations

### Resource Requirements
- **Syntax tests**: Minimal (< 1 minute)
- **Create phase**: 5-10 minutes (image pulls)
- **Full test cycle**: 15-30 minutes
- **RAM usage**: 2-4GB for default scenario
- **Disk usage**: 1-2GB for Docker images

### Optimization Tips
1. **Use syntax tests for rapid feedback**
2. **Run create once, then converge multiple times**
3. **Use `molecule destroy` to free resources**
4. **Test scenarios independently**

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Molecule Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          python -m venv molecule-venv
          source molecule-venv/bin/activate
          pip install -r requirements/molecule.txt
      - name: Run Molecule tests
        run: |
          source molecule-venv/bin/activate
          molecule test -s default
```

### Testing Strategy
1. **PR validation**: Run syntax + basic scenario
2. **Merge validation**: Run full test matrix
3. **Release validation**: Run all scenarios + security tests

## Security Testing

### Internal Network Simulation
- Containers communicate via Docker networks
- No external port exposure (except for debugging)
- SSH port forwarding simulation for admin access

### Firewall Testing
- UFW rule validation (simulated in containers)
- Service binding verification
- API access restriction testing

## Extending Tests

### Adding New Scenarios
1. Create directory: `molecule/<scenario-name>/`
2. Add `molecule.yml` configuration
3. Create playbooks: `converge.yml`, `verify.yml`
4. Define test platforms and variables

### Adding Verification Tests
1. **Ansible tests**: Add to `verify.yml`
2. **Python tests**: Add to `tests/test_<scenario>.py`
3. **Security tests**: Add security validation tasks

### Custom Configurations
- Modify `molecule.yml` for different platforms
- Adjust Docker settings for resource constraints
- Add environment-specific variables

## Best Practices

### Test Development
1. **Start with syntax validation**
2. **Use minimal resource configurations for faster feedback**
3. **Test incremental changes with converge**  
4. **Verify tests thoroughly before committing**

### Resource Management
1. **Always run `molecule destroy` after testing**
2. **Use `.dockerignore` to reduce build context**
3. **Regular cleanup of Docker images and containers**

### Documentation
1. **Update this document when adding scenarios**
2. **Document any custom configurations**
3. **Include troubleshooting steps for new issues**

---

## Quick Reference

### Essential Commands
```bash
# Setup
source molecule-venv/bin/activate

# Fast validation  
molecule syntax -s default

# Development cycle
molecule create -s default
molecule converge -s default  
molecule verify -s default

# Full test
molecule test -s default

# Cleanup
molecule destroy -s default
```

### Key Files
- `molecule/default/molecule.yml` - Main test configuration
- `molecule/default/verify.yml` - Comprehensive verification tests
- `ansible.cfg` - Ansible configuration with Docker plugin compatibility
- `requirements/ansible.yml` - Wazuh roles and collections

This testing infrastructure provides comprehensive validation of the DHIS2 + Wazuh security integration with multiple test scenarios and thorough verification procedures.