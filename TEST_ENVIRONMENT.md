# DHIS2 + Wazuh Integration Test Environment

This test environment allows you to thoroughly test the DHIS2 with Wazuh integration in a local Vagrant VM before deploying to production.

## Prerequisites

### Required Software
- **VirtualBox** 7.0+ ([Download](https://www.virtualbox.org/wiki/Downloads))
- **Vagrant** 2.3+ ([Download](https://www.vagrantup.com/downloads))
- **8GB+ RAM** available for the VM
- **20GB+ free disk space**

### Host System Requirements
- Linux, macOS, or Windows
- Virtualization support enabled in BIOS
- Internet connection for downloading packages

## Quick Start

### 1. Start the Test Environment
```bash
cd test/
vagrant up
```

This will:
- Create an Ubuntu 22.04 VM with 8GB RAM and 4 CPUs
- Install Ansible and required dependencies
- Enable UFW firewall
- Set up the deploy directory

### 2. Deploy DHIS2 with Wazuh
```bash
# SSH into the VM
vagrant ssh

# Run the test deployment
cd /opt/dhis2-deploy
sudo ../test/test-deploy.sh
```

The deployment takes 20-30 minutes and will:
- Create LXD containers for all services
- Install DHIS2, PostgreSQL, Nginx
- Deploy Wazuh manager and agents
- Configure security monitoring
- Set up firewall rules

### 3. Verify the Integration
```bash
# Run comprehensive verification tests
./test-verify.sh

# Test SSH port forwarding
exit  # Exit the VM
cd test/
./test-ssh-tunnel.sh
```

## Test Environment Details

### VM Configuration
- **OS**: Ubuntu 22.04 LTS
- **IP**: 192.168.56.10
- **RAM**: 8GB
- **CPU**: 4 cores
- **User**: vagrant/vagrant

### Container Layout
| Container | IP Address | Services |
|-----------|------------|----------|
| proxy | 172.19.2.2 | Nginx, Wazuh Agent |
| postgres | 172.19.2.20 | PostgreSQL, Wazuh Agent |
| dhis | 172.19.2.11 | DHIS2/Tomcat, Wazuh Agent |
| monitor | 172.19.2.30 | Munin, Grafana, Wazuh Agent |
| wazuh | 172.19.2.40 | Wazuh Manager, Dashboard, Indexer |

### Test Credentials
- **DHIS2**: admin/district
- **Wazuh**: admin/TestPassword123!
- **VM SSH**: vagrant/vagrant

## Accessing Services

### DHIS2 Web Interface
```bash
# Direct access (external)
https://192.168.56.10

# Or add to /etc/hosts:
192.168.56.10 dhis2-test.local
# Then visit: https://dhis2-test.local
```

### Wazuh Dashboard (SSH Tunnel Required)
```bash
# Set up SSH tunnel from your host machine
ssh -L 5601:172.19.2.40:5601 vagrant@192.168.56.10

# Then open in browser
https://localhost:5601
```

### Multiple Service Access
```bash
# Forward all Wazuh services at once
ssh -L 5601:172.19.2.40:5601 -L 55000:172.19.2.40:55000 -L 9200:172.19.2.40:9200 vagrant@192.168.56.10

# Access URLs:
# - Dashboard: https://localhost:5601
# - API: https://localhost:55000  
# - Indexer: https://localhost:9200
```

## Test Scripts

### test-deploy.sh
Complete deployment script with progress monitoring and verification.

**Features:**
- Pre-deployment checks
- Verbose deployment logging
- Container status verification
- Service health checks
- Connection information summary

### test-verify.sh
Comprehensive verification script testing all components.

**Test Categories:**
- Infrastructure (LXD, UFW, networking)
- Container status and connectivity
- Service health (PostgreSQL, Nginx, DHIS2, Wazuh)
- Security (firewall rules, access controls)
- Integration (inter-service communication)
- Performance (memory, disk usage)

### test-ssh-tunnel.sh
SSH port forwarding validation script.

**Features:**
- Automatic container IP discovery
- Multiple tunnel testing
- Service accessibility verification
- Manual testing instructions

## Troubleshooting

### Common Issues

#### VM Won't Start
```bash
# Check VirtualBox version
VBoxManage --version

# Enable virtualization in BIOS
# Check if nested virtualization is supported
grep -E "(vmx|svm)" /proc/cpuinfo
```

#### Deployment Fails
```bash
# Check VM resources
vagrant ssh -c "free -h && df -h"

# Check LXD status  
vagrant ssh -c "sudo systemctl status lxd"

# View deployment logs
vagrant ssh -c "sudo journalctl -u lxd -f"
```

#### Container Issues
```bash
# List containers
vagrant ssh -c "sudo lxc list"

# Check container logs
vagrant ssh -c "sudo lxc info <container-name>"

# Restart container
vagrant ssh -c "sudo lxc restart <container-name>"
```

#### Wazuh Issues
```bash
# Check Wazuh manager status
vagrant ssh -c "sudo lxc exec wazuh -- systemctl status wazuh-manager"

# View Wazuh logs
vagrant ssh -c "sudo lxc exec wazuh -- tail -f /var/ossec/logs/ossec.log"

# Check agent connections
vagrant ssh -c "sudo lxc exec wazuh -- /var/ossec/bin/manage_agents -l"
```

### Performance Tuning

#### For Low-Resource Hosts
Edit `test/Vagrantfile`:
```ruby
vb.memory = "6144"  # Reduce to 6GB
vb.cpus = 2         # Reduce to 2 CPUs
```

#### Speed Up Deployment
```bash
# Skip unattended upgrades
echo "unattended_upgrades=no" >> test/inventory/hosts

# Use lighter monitoring
sed -i 's/server_monitoring=munin/server_monitoring=none/' test/inventory/hosts
```

## Cleanup

### Remove Test Environment
```bash
# Destroy VM and clean up
cd test/
vagrant destroy -f

# Remove Vagrant box (optional)
vagrant box remove ubuntu/jammy64
```

### Partial Cleanup
```bash
# Just stop the VM
vagrant halt

# Remove containers only
vagrant ssh -c "sudo lxc list | grep RUNNING | awk '{print \$2}' | xargs -r sudo lxc delete --force"
```

## Advanced Testing

### Load Testing
```bash
# Generate test traffic
vagrant ssh
sudo lxc exec dhis -- curl -s http://localhost:8080/api/system/info

# Generate security events
for i in {1..10}; do
  sudo lxc exec dhis -- curl -X POST http://localhost:8080/dhis-web-commons/security/login.action \
    -d "j_username=test&j_password=wrong"
done
```

### Custom Testing
```bash
# Add custom test inventory
cp test/inventory/hosts test/inventory/custom-hosts
# Edit custom-hosts for your testing needs

# Deploy with custom inventory
cd /opt/dhis2-deploy
sudo ansible-playbook dhis2.yml -i ../test/inventory/custom-hosts
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Test DHIS2 Wazuh Integration
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up test environment
        run: |
          cd test
          vagrant up
          vagrant ssh -c "cd /opt/dhis2-deploy && sudo ../test/test-deploy.sh"
          vagrant ssh -c "cd /opt/dhis2-deploy && ./test-verify.sh"
```

This test environment ensures that your Wazuh integration works perfectly before deploying to production servers.