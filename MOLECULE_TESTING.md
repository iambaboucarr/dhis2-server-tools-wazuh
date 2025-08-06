# Professional Molecule Testing for DHIS2 + Wazuh Integration

This document describes the comprehensive Molecule testing framework for validating the DHIS2 + Wazuh security monitoring integration.

## Overview

The testing framework uses Molecule with Docker to create realistic test environments that validate:

- **Infrastructure Deployment**: Complete DHIS2 + Wazuh stack deployment
- **Service Integration**: Communication between all components
- **Security Configuration**: Proper firewall rules and access controls
- **Monitoring Functionality**: Wazuh agent registration and log collection
- **Idempotency**: Ensuring playbooks can run multiple times safely

## Test Scenarios

### 1. Default Scenario (`default`)
**Purpose**: Basic Wazuh + DHIS2 integration validation

**Components**:
- Wazuh Manager container
- DHIS2 Instance container
- Network connectivity testing
- Agent-manager communication

**Tests**:
- Wazuh manager service deployment
- Agent installation and registration
- Custom DHIS2 security rules
- Log collection functionality

### 2. Wazuh-Only Scenario (`wazuh-only`)
**Purpose**: Standalone Wazuh server validation

**Components**:
- Single Wazuh Manager container
- Isolated testing environment

**Tests**:
- Wazuh manager components (API, Dashboard, Indexer)
- Service health checks
- Configuration validation
- Port accessibility

### 3. Full-Stack Scenario (`full-stack`)
**Purpose**: Complete infrastructure testing

**Components**:
- Wazuh Manager
- PostgreSQL Database
- DHIS2 Application
- Nginx Reverse Proxy
- Full network simulation

**Tests**:
- End-to-end deployment
- Inter-service communication
- Complete monitoring pipeline
- Performance validation

## Quick Start

### Prerequisites

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Python dependencies
pip install -r requirements-test.txt

# Install Ansible collections
ansible-galaxy install -r requirements.yml
```

### Running Tests

```bash
# Run all scenarios
./test-molecule.sh

# Run specific scenario
./test-molecule.sh default

# Run with verbose output
./test-molecule.sh -v wazuh-only

# List available scenarios
./test-molecule.sh -l
```

### Individual Molecule Commands

```bash
# Test specific scenario
molecule test -s default

# Create and converge only (for debugging)
molecule create -s default
molecule converge -s default

# Run verification tests only
molecule verify -s default

# Destroy test environment
molecule destroy -s default
```

## Test Structure

```
molecule/
├── default/                 # Basic integration test
│   ├── molecule.yml        # Scenario configuration
│   ├── prepare.yml         # Environment preparation
│   ├── converge.yml        # Deployment playbook
│   └── verify.yml          # Verification tests
├── wazuh-only/             # Standalone Wazuh test
│   ├── molecule.yml
│   ├── prepare.yml
│   └── converge.yml
└── full-stack/             # Complete infrastructure test
    ├── molecule.yml
    ├── prepare.yml
    └── converge.yml
```

## Test Categories

### 1. Infrastructure Tests
- Container creation and networking
- Service installation and configuration
- Port accessibility
- File system setup

### 2. Service Health Tests
- Systemd service status validation
- Process health checks
- Log file creation
- Configuration file validation

### 3. Integration Tests
- Agent-manager communication
- API connectivity
- Database connections
- Web service responses

### 4. Security Tests
- Access control validation
- Firewall rule simulation
- Certificate configuration
- User permission checks

### 5. Functional Tests
- Log collection verification
- Alert generation testing
- Custom rule validation
- Dashboard accessibility

## Verification Tests

The verification playbooks include comprehensive checks:

```yaml
# Example verification tasks
- name: Verify Wazuh manager is running
  ansible.builtin.systemd:
    name: wazuh-manager
  register: wazuh_service

- name: Check agent registration
  ansible.builtin.stat:
    path: /var/ossec/etc/client.keys
  register: client_keys

- name: Validate custom rules
  ansible.builtin.shell: |
    grep -q "dhis2" /var/ossec/etc/rules/dhis2_rules.xml
```

## CI/CD Integration

### GitHub Actions Workflow

The project includes a comprehensive GitHub Actions workflow:

```yaml
# .github/workflows/molecule-tests.yml
- Lint checks (ansible-lint, yamllint)
- Multi-scenario testing
- Security scanning
- Test result reporting
- Artifact collection
```

### Test Execution Matrix

```yaml
strategy:
  matrix:
    scenario: [default, wazuh-only]
    python-version: [3.9, 3.10, 3.11]
```

## Local Development

### Running Tests During Development

```bash
# Quick feedback loop
molecule create -s default
molecule converge -s default
# Make changes to roles
molecule converge -s default  # Test changes
molecule verify -s default    # Run verification
molecule destroy -s default   # Clean up
```

### Debugging Failed Tests

```bash
# Keep containers running after failure
molecule test -s default --destroy=never

# Connect to failed container
docker exec -it molecule_wazuh-server_1 bash

# Check logs
molecule login -s default -h wazuh-server
tail -f /var/ossec/logs/ossec.log
```

### Custom Test Development

Create custom verification tasks:

```yaml
# molecule/custom/verify.yml
- name: Custom business logic test
  ansible.builtin.shell: |
    # Your custom validation logic here
  register: custom_result

- name: Assert custom validation
  ansible.builtin.assert:
    that:
      - custom_result.rc == 0
    fail_msg: "Custom validation failed"
```

## Performance Considerations

### Resource Requirements

- **Minimum**: 4GB RAM, 2 CPU cores
- **Recommended**: 8GB RAM, 4 CPU cores
- **Full-stack**: 12GB RAM, 6 CPU cores

### Optimization Tips

```bash
# Parallel execution (experimental)
PARALLEL=true ./test-molecule.sh

# Skip cleanup for faster iterations
CLEANUP=false ./test-molecule.sh

# Use cached images
export MOLECULE_IMAGE_CACHE=true
```

## Troubleshooting

### Common Issues

1. **Docker Permission Denied**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Port Conflicts**
   ```bash
   # Check for running containers
   docker ps
   # Clean up
   docker system prune -f
   ```

3. **Memory Issues**
   ```bash
   # Increase Docker memory limit
   # Reduce scenario complexity
   # Run scenarios sequentially
   ```

### Debug Information

```bash
# Container logs
docker logs molecule_wazuh-server_1

# Molecule logs
cat molecule/default/molecule.log

# System resources
docker stats
```

## Best Practices

### 1. Test Design
- Keep scenarios focused and minimal
- Use realistic but lightweight configurations
- Test one thing per scenario when possible

### 2. Resource Management
- Clean up containers after tests
- Use appropriate resource limits
- Monitor disk space usage

### 3. Maintenance
- Update base images regularly
- Keep dependencies current
- Review and update test cases

### 4. Documentation
- Document test scenarios clearly
- Maintain troubleshooting guides
- Update CI/CD configurations

## Extending the Framework

### Adding New Scenarios

1. Create scenario directory: `molecule/new-scenario/`
2. Copy and modify `molecule.yml`
3. Create scenario-specific playbooks
4. Add to test runner script
5. Update CI/CD workflow

### Custom Platforms

```yaml
# molecule.yml
platforms:
  - name: custom-platform
    image: custom/base-image
    # Platform-specific configuration
```

### Integration with Other Tools

- **Testinfra**: Python-based infrastructure testing
- **Goss**: YAML-based server testing
- **InSpec**: Compliance and security testing

## Continuous Improvement

The testing framework is designed to evolve with the project:

- Regular review of test coverage
- Performance optimization
- New scenario development
- Tool and dependency updates

This comprehensive testing approach ensures reliable, secure deployments of the DHIS2 + Wazuh integration across different environments and configurations.