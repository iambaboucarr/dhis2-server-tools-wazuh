# Requirements Files Structure

This directory contains Python and Ansible dependency requirements for different use cases.

## Files

### Python Dependencies

- **`base.txt`** - Core requirements for running Ansible playbooks
  - Use for: Production deployments
  - Install: `pip install -r requirements/base.txt`

- **`dev.txt`** - Development and testing tools (includes base.txt)
  - Use for: Development, linting, code quality checks
  - Install: `pip install -r requirements/dev.txt`

- **`molecule.txt`** - Specific versions for Molecule testing
  - Use for: Running molecule tests without Docker plugin issues
  - Install: `pip install -r requirements/molecule.txt`
  - **Note**: These are pinned versions known to work together

### Ansible Dependencies

- **`ansible.yml`** - Ansible Galaxy roles and collections
  - Use for: Installing required Ansible roles (Wazuh, community collections)
  - Install: `ansible-galaxy install -r requirements/ansible.yml`

## Usage Examples

### For Production Deployment
```bash
pip install -r requirements/base.txt
ansible-galaxy install -r requirements/ansible.yml
```

### For Development
```bash
pip install -r requirements/dev.txt
ansible-galaxy install -r requirements/ansible.yml
pre-commit install
```

### For Molecule Testing
```bash
# Create virtual environment
python3 -m venv molecule-venv
source molecule-venv/bin/activate

# Install specific compatible versions
pip install -r requirements/molecule.txt
ansible-galaxy install -r requirements/ansible.yml

# Run tests
molecule test
```

## Version Compatibility Notes

- **Molecule Testing**: Use `molecule.txt` for exact versions that avoid Docker plugin conditional bugs
- **Production**: Use `base.txt` for flexible version ranges
- **Development**: Use `dev.txt` for all development tools