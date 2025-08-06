# Wazuh Security Monitoring Integration for DHIS2 LXD Containers

This integration adds comprehensive security monitoring for all DHIS2 LXD containers using Wazuh 4.12.0.

## Architecture Overview

- **Wazuh Manager**: Centralized security monitoring server deployed in a dedicated LXD container
- **Wazuh Agents**: Installed on all LXD containers (proxy, database, DHIS2 instances, monitoring)
- **Custom Rules**: DHIS2-specific security rules and LXD container monitoring

## Deployment Steps

### 1. Update Inventory

Copy the inventory template and add the Wazuh server:
```bash
cp deploy/inventory/hosts.template deploy/inventory/hosts
```

The template already includes the Wazuh server configuration:
```ini
[wazuh]
wazuh   ansible_host=172.19.2.40
```

### 2. Deploy Wazuh with DHIS2

Deploy everything including Wazuh:
```bash
cd deploy/
sudo ./deploy.sh
```

Or deploy only Wazuh components:
```bash
cd deploy/
ansible-playbook dhis2.yml --tags wazuh
```

### 3. Access Wazuh Dashboard (SSH Port Forwarding Required)

The Wazuh dashboard is configured for internal access only. To access it, use SSH port forwarding:

#### From Linux/Mac:
```bash
# Forward Wazuh Dashboard (port 5601)
ssh -L 5601:localhost:5601 username@your-server-ip

# Forward multiple ports (Dashboard, API, and Indexer)
ssh -L 5601:localhost:5601 -L 55000:localhost:55000 -L 9200:localhost:9200 username@your-server-ip
```

#### From Windows (using PuTTY):
1. In PuTTY Configuration, go to Connection → SSH → Tunnels
2. Add forwarded ports:
   - Source port: 5601, Destination: localhost:5601 (Dashboard)
   - Source port: 55000, Destination: localhost:55000 (API)
   - Source port: 9200, Destination: localhost:9200 (Indexer)
3. Click "Add" for each port, then connect

#### Access URLs (after port forwarding):
- Wazuh Dashboard: `https://localhost:5601`
- Wazuh API: `https://localhost:55000`
- Default credentials: admin/SecurePassword123!

#### For LXD deployments:
If Wazuh is deployed in an LXD container, you need to forward from the container IP:
```bash
# First, get Wazuh container IP
ssh username@your-server-ip "lxc list | grep wazuh"

# Then SSH with port forwarding to container IP (example with IP 172.19.2.40)
ssh -L 5601:172.19.2.40:5601 -L 55000:172.19.2.40:55000 -L 9200:172.19.2.40:9200 username@your-server-ip

# Alternative: Use dynamic container IP lookup
ssh -L 5601:$(ssh username@your-server-ip "lxc info wazuh | grep -A1 'eth0:' | grep inet | awk '{print \$2}' | cut -d/ -f1"):5601 username@your-server-ip
```

## Security Monitoring Features

### DHIS2-Specific Monitoring
- Authentication attempts and failures
- API access patterns and abuse detection
- Data export/import activities
- Configuration changes
- SQL injection attempt detection
- Application errors and performance issues

### LXD Container Security
- Container lifecycle events
- Resource usage monitoring
- Privilege escalation attempts
- Network security monitoring
- File integrity monitoring

### Infrastructure Monitoring
- PostgreSQL security events
- Web server (Nginx/Apache) security
- System file integrity
- Process monitoring
- Network connections

## Custom Rules

The integration includes custom Wazuh rules for:
- **DHIS2 Rules** (ID 100001-100099): Application-specific security monitoring
- **PostgreSQL Rules** (ID 100100-100199): Database security for DHIS2
- **Web Server Rules** (ID 100200-100299): HTTP/HTTPS security monitoring
- **LXD Rules** (ID 100300-100399): Container-specific security

## Configuration

### Wazuh Manager Settings
Edit `deploy/roles/wazuh-server/defaults/main.yml` to customize:
- API credentials
- Network settings
- Cluster configuration

### Agent Groups
Agents are automatically assigned to groups based on their role:
- `lxd`: All LXD containers
- `dhis2`: All DHIS2-related containers
- `instances`: DHIS2 application servers
- `databases`: PostgreSQL servers
- `web`: Proxy servers

## Alerts and Notifications

Configure email alerts by updating the Wazuh manager configuration:
```yaml
email: your-email@example.com
smtp_server: your-smtp-server.com
```

## Troubleshooting

### Check Wazuh Manager Status
```bash
lxc exec wazuh -- systemctl status wazuh-manager
```

### Check Agent Status
```bash
lxc exec <container-name> -- systemctl status wazuh-agent
```

### View Manager Logs
```bash
lxc exec wazuh -- tail -f /var/ossec/logs/ossec.log
```

### List Connected Agents
```bash
lxc exec wazuh -- /var/ossec/bin/manage_agents -l
```

## Security Best Practices

1. **Internal-Only Access**: Wazuh web interfaces are configured to be accessible only from the internal network. Always use SSH port forwarding for remote access.
2. **Change Default Passwords**: Update the default Wazuh API password immediately after deployment
3. **TLS Configuration**: Ensure TLS is properly configured for all Wazuh communications
4. **Regular Updates**: Keep Wazuh components updated to the latest version
5. **Log Retention**: Configure appropriate log retention policies
6. **Alert Tuning**: Adjust alert thresholds based on your environment
7. **Firewall Rules**: The deployment automatically configures UFW to:
   - Block external access to Wazuh web interfaces (ports 5601, 55000, 9200)
   - Allow agent communication only from the internal LXD network
   - Restrict cluster communication to internal nodes only

## Integration with Existing Monitoring

Wazuh complements the existing monitoring stack:
- **Munin**: System resource monitoring
- **Glowroot**: Application performance monitoring
- **Wazuh**: Security monitoring and compliance

All monitoring data is centralized and accessible through their respective dashboards.