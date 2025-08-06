# Wazuh Integration for DHIS2

## Overview

This implementation uses the **official Wazuh Ansible roles** from [wazuh/wazuh-ansible](https://github.com/wazuh/wazuh-ansible) rather than reinventing the wheel with custom roles. The official roles are production-ready, well-maintained, and follow Wazuh best practices.

## Why Use Wazuh Ansible Roles?

✅ **Production-Ready**: Battle-tested in enterprise environments  
✅ **Maintained**: Regular updates with each Wazuh release  
✅ **Best Practices**: Implements Wazuh's recommended configurations  
✅ **Community Support**: Backed by Wazuh team and community  
✅ **Complete Feature Set**: Supports all Wazuh components and configurations  
✅ **Security**: Implements proper security hardening by default  

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Wazuh Manager                         │
│  (Central Server - wazuh-ansible/ansible-wazuh-manager)  │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼────┐ ┌────▼─────┐ ┌───▼──────┐
│   Indexer   │ │Dashboard │ │  Agents   │
│ (OpenSearch)│ │  (Kibana) │ │ (DHIS2)   │
└─────────────┘ └──────────┘ └───────────┘
```

## Quick Start

### 1. Install Requirements

```bash
# Install Ansible Galaxy requirements including official Wazuh roles
ansible-galaxy install -r requirements.yml --force

# This will install:
# - wazuh-ansible collection from GitHub
# - Required community collections
```

### 2. Configure Inventory

**Option A: Wazuh with DHIS2 (Recommended)**
```bash
# Use the main DHIS2 inventory template (includes Wazuh configuration)
cp deploy/inventory/hosts.template deploy/inventory/hosts

# Edit to enable Wazuh monitoring
vim deploy/inventory/hosts
# Set: enable_wazuh_monitoring=yes
```

**Option B: Standalone Wazuh Only**
```bash
# Use the main inventory template but only configure Wazuh sections
cp deploy/inventory/hosts.template deploy/inventory/hosts

# Edit to configure only Wazuh components (comment out DHIS2 sections)
vim deploy/inventory/hosts
```

**Example Configuration:**

The main `hosts.template` already includes Wazuh configuration sections:
```ini
# Wazuh security monitoring (only used when enable_wazuh_monitoring=yes)
[wazuh]
wazuh   ansible_host=172.19.2.40

[wazuh_managers]
wazuh   ansible_host=172.19.2.40

[wazuh_indexers]
wazuh   ansible_host=172.19.2.40

[wazuh_dashboards]  
wazuh   ansible_host=172.19.2.40
```

### 3. Create Vault Configuration

```bash
# Create secure passwords vault
cp deploy/vars/vault.yml.example deploy/vars/vault.yml

# Edit with strong passwords
vim deploy/vars/vault.yml

# Encrypt the vault
ansible-vault encrypt deploy/vars/vault.yml
```

### 4. Deploy

**Option A: Deploy DHIS2 + Wazuh Together (Recommended)**
```bash
# Deploy entire stack (DHIS2 + Wazuh if enabled)
cd deploy/
ansible-playbook dhis2.yml --ask-vault-pass

# Wazuh will only be deployed if enable_wazuh_monitoring=yes in inventory
```

**Option B: Deploy Wazuh Standalone**
```bash
# Deploy only Wazuh security monitoring
cd deploy/
ansible-playbook wazuh.yml --ask-vault-pass

# Or for specific components only:
ansible-playbook wazuh.yml --tags "wazuh-manager" --ask-vault-pass
```

**Option C: Deploy DHIS2 Only (Skip Wazuh)**
```bash
# Set enable_wazuh_monitoring=no in inventory, then:
cd deploy/
ansible-playbook dhis2.yml  # No vault password needed if Wazuh disabled
```

## Configuration Options

### Enable/Disable Wazuh Monitoring

Control Wazuh deployment using the `enable_wazuh_monitoring` flag in your inventory:

```ini
# In deploy/inventory/hosts file, [all:vars] section:

# Enable Wazuh security monitoring alongside DHIS2
enable_wazuh_monitoring=yes

# Disable Wazuh (deploy only DHIS2)
enable_wazuh_monitoring=no
```

**Use Cases:**
- **`yes`**: Full DHIS2 + Wazuh security monitoring deployment
- **`no`**: DHIS2-only deployment (development, testing, or minimal setups)

**Benefits of Using the Flag:**
- ✅ **Flexible deployment**: Choose what to deploy based on environment needs
- ✅ **Resource optimization**: Skip Wazuh in development/testing environments  
- ✅ **Gradual rollout**: Deploy DHIS2 first, add Wazuh monitoring later
- ✅ **Single command**: `ansible-playbook dhis2.yml` handles everything

### Single-Node vs Cluster

In `wazuh.yml`, set the deployment mode:

```yaml
vars:
  single_node: true  # Set to false for cluster deployment
```

### Memory Tuning

Adjust based on available resources:

```yaml
vars:
  indexer_jvm_heap_size: "2g"  # Default: 1g, increase for production
```

### Custom Wazuh Configuration

Add custom configurations in the playbook:

```yaml
wazuh_manager_config:
  vulnerability_detection:
    enabled: "yes"
    feed_update_interval: "60m"
  
  cluster:
    disabled: "no"
    name: "production-cluster"
    node_type: "master"
```

### DHIS2-Specific Monitoring

The playbook includes DHIS2-specific configurations:

```yaml
wazuh_agent_config:
  localfile:
    - location: "/opt/dhis2/logs/dhis.log"
      log_format: "multi-line"
      label:
        key: "dhis2"
    - location: "/opt/dhis2/tomcat/logs/catalina.out"
      log_format: "multi-line"
      label:
        key: "tomcat"
  
  syscheck:
    directories:
      - path: "/opt/dhis2/config"
        check_all: "yes"
        realtime: "yes"
```

## Testing with Molecule

Test the deployment using the official roles:

```bash
# Run molecule tests for official Wazuh roles
molecule test -s wazuh

# Or test specific sequences
molecule converge -s wazuh
molecule verify -s wazuh
```

## Integration with DHIS2 Deployment

### Method 1: Sequential Deployment

```bash
# First deploy DHIS2
ansible-playbook dhis2.yml

# Then deploy Wazuh monitoring
ansible-playbook wazuh.yml --ask-vault-pass
```

### Method 2: Combined Deployment

```bash
# Deploy both DHIS2 and Wazuh together
ansible-playbook dhis2.yml wazuh.yml --ask-vault-pass
```

### Method 3: Import in Main Playbook

Add to your `dhis2.yml`:

```yaml
- import_playbook: wazuh.yml
  when: enable_wazuh_monitoring | default(true)
```

## Security Architecture

### Internal Network Only Design

**This Wazuh deployment follows a security-first approach:**

- 🔒 **No Internet Exposure**: All services bind to internal IPs only
- 🛡️ **Firewall Restrictions**: UFW rules limit access to internal network  
- 🔑 **SSH-Only Access**: Admin access via SSH port forwarding only
- 📡 **Agent Communication**: Encrypted agent-to-manager communication on internal network
- 🚫 **No Public Ports**: Dashboard and API never exposed to public internet  
- 🖥️ **Complete Coverage**: Monitors both LXD host server and all containers

### Network Security Layout

```
Internet  ❌ BLOCKED ❌
    │
Firewall/Router
    │
Physical Host Server (🔍 Wazuh Agent - monitors LXD host)
    │
LXD Bridge Network (e.g., 172.19.2.0/24)
    ├── Wazuh Container      (172.19.2.40 - manager/indexer/dashboard)
    ├── DHIS2 Container      (172.19.2.11 - 🔍 agent monitors DHIS2)
    ├── Proxy Container      (172.19.2.2 - 🔍 agent monitors nginx)  
    └── Database Container   (172.19.2.20 - 🔍 agent monitors PostgreSQL)
                │
          SSH Tunnel ← Admin laptop
        (to container IP via host)
```

### Access Methods

| Component | LXD Container Access | VM/Physical Server Access | Admin Access Method |
|-----------|---------------------|---------------------------|-------------------|
| **Dashboard** | `container-ip:5601` | `127.0.0.1:5601` | SSH forward `localhost:5601` |
| **API** | `container-ip:55000` | `127.0.0.1:55000` | SSH forward `localhost:55000` |
| **Indexer** | `container-ip:9200` | `internal-ip:9200` | SSH forward `localhost:9200` |
| **Agent Comms** | `container-ip:1514/1515` | `internal-ip:1514/1515` | Direct (internal network) |

## Multi-Layer Security Monitoring

### Complete Infrastructure Coverage

The Wazuh deployment monitors **all layers** of your DHIS2 infrastructure:

#### 🖥️ **LXD Host Server Agent**
**Monitors:** Physical/VM host running LXD containers
**Key Monitoring Areas:**
- **System logs**: `/var/log/syslog`, `/var/log/auth.log`, `/var/log/kern.log`
- **LXD daemon**: LXD service logs and container lifecycle events
- **SSH access**: Authentication attempts and session monitoring  
- **File integrity**: `/etc/lxd`, `/etc/ssh`, `/etc/sudoers.d`
- **LXD commands**: Container status, storage usage via `lxc` commands
- **Network traffic**: Host-level network monitoring
- **Resource usage**: CPU, memory, disk usage on host

#### 📦 **Container Agents**
**Monitors:** Each DHIS2 infrastructure container

**DHIS2 Application Containers:**
- Application logs: `/opt/dhis2/logs/dhis.log`  
- Tomcat logs: `/opt/dhis2/tomcat/logs/catalina.out`
- Configuration changes: `/opt/dhis2/config`
- Web applications: `/opt/dhis2/webapps`

**Proxy Containers (nginx):**
- Access logs: `/var/log/nginx/*.log`
- Configuration: `/etc/nginx`
- SSL certificates monitoring

**Database Containers (PostgreSQL):**
- Database logs: PostgreSQL transaction logs
- Configuration: `/etc/postgresql`
- Data directory monitoring

**Monitoring Containers (Munin/Glowroot):**
- Monitoring system logs
- Performance data integrity

### Security Event Detection

**Host-Level Events:**
- ✅ Unauthorized SSH access attempts
- ✅ Privilege escalation attempts  
- ✅ LXD container creation/modification
- ✅ Host system configuration changes
- ✅ Network anomalies
- ✅ Resource exhaustion

**Container-Level Events:**
- ✅ Application security events
- ✅ Database access anomalies  
- ✅ Web application attacks
- ✅ Configuration tampering
- ✅ Performance degradation
- ✅ Service availability issues

## Security Best Practices

### 1. Use Ansible Vault

Always encrypt sensitive data:
```bash
# Encrypt variables
ansible-vault encrypt deploy/vars/vault.yml

# Edit encrypted file
ansible-vault edit deploy/vars/vault.yml

# View encrypted file
ansible-vault view deploy/vars/vault.yml
```

### 2. Network Segmentation

Configure firewall rules properly:
```yaml
# In the playbook, firewall rules are automatically configured
# Customize allowed networks:
vars:
  wazuh_api_allowed_networks: "10.0.0.0/24"
  dashboard_allowed_networks: "192.168.1.0/24"
```

### 3. TLS/SSL Configuration

The official roles handle certificates automatically:
```yaml
vars:
  generate_certificates: true
  certificates_path: /etc/wazuh-certificates
```

### 4. Regular Updates

Keep Wazuh updated:
```bash
# Update to latest version
ansible-playbook wazuh.yml \
  -e "wazuh_manager_version=4.12.0-1" \
  --tags update \
  --ask-vault-pass
```

## Monitoring and Maintenance

### Access Wazuh Dashboard via SSH Port Forwarding

**Wazuh is configured for internal network access only for security.** Access the web interfaces using SSH port forwarding:

#### Method 1: LXD Container Deployment (Recommended)
```bash
# For Wazuh running in LXD container (forward to container IP)
ssh -L 5601:172.19.2.40:5601 -L 55000:172.19.2.40:55000 user@host-server

# Replace 172.19.2.40 with your actual Wazuh container IP
# Replace host-server with your actual host server address
```

#### Method 2: VM/Physical Server Deployment  
```bash
# For Wazuh running on VM/physical server (forward to localhost)
ssh -L 5601:127.0.0.1:5601 -L 55000:127.0.0.1:55000 user@wazuh-server
```

**Then access from your local machine:**
- Dashboard: `https://localhost:5601`
- API: `https://localhost:55000`

#### Method 3: SSH Config File

**For LXD Container deployment:**
Create `~/.ssh/config` entry:
```
Host wazuh-lxd-tunnel
    HostName your-host-server
    User your-username
    LocalForward 5601 172.19.2.40:5601
    LocalForward 55000 172.19.2.40:55000
    LocalForward 9200 172.19.2.40:9200
```

**For VM/Physical Server deployment:**
```
Host wazuh-vm-tunnel
    HostName wazuh-server-ip
    User your-username
    LocalForward 5601 127.0.0.1:5601
    LocalForward 55000 127.0.0.1:55000
    LocalForward 9200 127.0.0.1:9200
```

Then connect: `ssh wazuh-lxd-tunnel` or `ssh wazuh-vm-tunnel`

#### Method 4: Persistent Tunnel with autossh
```bash
# Install autossh for persistent tunneling
sudo apt install autossh  # Ubuntu/Debian
brew install autossh      # macOS

# For LXD Container deployment
autossh -M 0 -L 5601:172.19.2.40:5601 -L 55000:172.19.2.40:55000 user@host-server

# For VM/Physical Server deployment  
autossh -M 0 -L 5601:127.0.0.1:5601 -L 55000:127.0.0.1:55000 user@wazuh-server
```

#### After Setting Up SSH Forwarding:
1. **Dashboard**: Navigate to `https://localhost:5601`
2. **API**: Access `https://localhost:55000`  
3. **Login**: Use admin credentials from your vault
4. **Certificate Warning**: Accept self-signed certificate (internal use only)

### Check Agent Status

```bash
# On Wazuh manager - list all connected agents
/var/ossec/bin/agent_control -l

# Check specific agent
/var/ossec/bin/agent_control -i <agent-id>

# Expected agents for LXD deployment:
# - LXD Host Server (physical/VM host)
# - Wazuh Container (if single-node deployment) 
# - DHIS2 Application Container(s)
# - Proxy Container (nginx)
# - Database Container (PostgreSQL)  
# - Monitoring Container (Munin/Glowroot)
```

**Example Agent List:**
```
Wazuh Agent Status:
- ID: 001, Name: lxd-host, IP: 192.168.1.10 (Host server)
- ID: 002, Name: dhis2-prod, IP: 172.19.2.11 (DHIS2 container)
- ID: 003, Name: proxy, IP: 172.19.2.2 (nginx container)
- ID: 004, Name: postgres, IP: 172.19.2.20 (Database container)
- ID: 005, Name: monitor, IP: 172.19.2.30 (Monitoring container)
```

### View Logs

```bash
# Manager logs
tail -f /var/ossec/logs/ossec.log

# API logs
tail -f /var/ossec/logs/api.log

# Alerts
tail -f /var/ossec/logs/alerts/alerts.json
```

## Troubleshooting

### Issue: Services not starting

```bash
# Check service status
systemctl status wazuh-manager wazuh-indexer wazuh-dashboard

# Check logs
journalctl -u wazuh-manager -f
```

### Issue: Agents not connecting

```bash
# Check firewall rules
ufw status

# Verify authd password
grep authd /var/ossec/etc/ossec.conf

# Test connectivity
telnet <manager-ip> 1514
```

### Issue: LXD Container Agents Not Registering

LXD containers have specific networking considerations:

```bash
# 1. Check LXD bridge configuration
lxc network show lxdbr0

# 2. Verify container can reach Wazuh manager
lxc exec <container-name> -- nc -zv <manager-ip> 1514
lxc exec <container-name> -- nc -zv <manager-ip> 1515

# 3. Check agent logs in container
lxc exec <container-name> -- tail -f /var/ossec/logs/ossec.log

# 4. Manually restart agent registration
lxc exec <container-name> -- /var/ossec/bin/agent-auth -m <manager-ip> -p 1515

# 5. Check manager logs for agent registration attempts
tail -f /var/ossec/logs/ossec.log | grep -i agent
```

### Issue: LXD Network Routing

If containers can't reach the Wazuh manager:

```bash
# Add iptables rule for LXD traffic (if needed)
iptables -A FORWARD -i lxdbr0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o lxdbr0 -j ACCEPT

# Make rules persistent
iptables-save > /etc/iptables/rules.v4

# Or configure LXD network with custom settings
lxc network set lxdbr0 ipv4.nat true
lxc network set lxdbr0 ipv4.routing true
```

### Issue: Memory issues with Indexer

```bash
# Adjust heap size in /etc/wazuh-indexer/jvm.options
-Xms2g
-Xmx2g

# Restart service
systemctl restart wazuh-indexer
```

## Advantages Over Custom Roles

| Feature | Official Roles | Custom Roles |
|---------|---------------|--------------|
| Maintenance | ✅ Wazuh team | ❌ Your team |
| Updates | ✅ Automatic with releases | ❌ Manual |
| Testing | ✅ Extensive | ❌ Limited |
| Documentation | ✅ Comprehensive | ❌ Basic |
| Community Support | ✅ Active | ❌ None |
| Security Updates | ✅ Immediate | ❌ Delayed |
| Feature Coverage | ✅ Complete | ❌ Partial |

## Migration from Custom Roles

If you've already deployed with custom roles:

1. **Backup current configuration**:
   ```bash
   tar -czf wazuh-backup.tar.gz /var/ossec /etc/wazuh-*
   ```

2. **Export agent keys**:
   ```bash
   /var/ossec/bin/manage_agents -e > agents.keys
   ```

3. **Deploy with official roles**:
   ```bash
   ansible-playbook wazuh.yml --ask-vault-pass
   ```

4. **Import agent keys**:
   ```bash
   /var/ossec/bin/manage_agents -i agents.keys
   ```

## References

- [Official Wazuh Ansible Documentation](https://documentation.wazuh.com/current/deployment-options/deploying-with-ansible/index.html)
- [Wazuh Ansible GitHub Repository](https://github.com/wazuh/wazuh-ansible)
- [Wazuh Configuration Reference](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/index.html)
- [DHIS2 Security Guidelines](https://docs.dhis2.org/en/manage/performing-system-administration/dhis-core-version-master/installation.html#security)

## Support

- **Wazuh Community**: [Google Groups](https://groups.google.com/g/wazuh)
- **GitHub Issues**: [wazuh-ansible/issues](https://github.com/wazuh/wazuh-ansible/issues)
- **Slack Channel**: [Wazuh Slack](https://wazuh.com/community/join-us-on-slack/)

---

*Using official Wazuh Ansible roles ensures a production-ready, secure, and maintainable deployment that follows industry best practices.*