# Security Architecture - DHIS2 Server Tools with Wazuh

## Overview

This document outlines the comprehensive security architecture implemented in the DHIS2 Server Tools with Wazuh integration. The solution provides enterprise-grade security monitoring, threat detection, and compliance management for DHIS2 deployments.

## Security Components

### 1. Wazuh SIEM Platform

**Core Components:**
- **Wazuh Manager**: Central processing and analysis engine
- **Wazuh Indexer**: Data storage and indexing (OpenSearch-based)
- **Wazuh Dashboard**: Visualization and management interface
- **Wazuh Agents**: Endpoint monitoring on all DHIS2 containers

**Security Features:**
- Real-time log analysis and correlation
- File integrity monitoring (FIM)
- Vulnerability detection
- Security configuration assessment (SCA)
- Regulatory compliance monitoring (PCI DSS, HIPAA, GDPR)
- Active response and threat mitigation

### 2. Authentication & Authorization

**API Security:**
- HTTPS-only communication with TLS 1.2/1.3
- JWT-based authentication
- Role-based access control (RBAC)
- API rate limiting and throttling

**Credential Management:**
- Ansible Vault for sensitive data encryption
- Dynamic password generation using lookup filters
- No hardcoded credentials in codebase
- Regular credential rotation support

### 3. Network Security

**Firewall Configuration:**
- UFW/iptables rules for all services
- Strict ingress/egress controls
- Network segmentation between components
- LXD container isolation

**Ports and Services:**
```
- 1514/tcp,udp: Wazuh agent communication
- 1515/tcp: Agent enrollment (secured)
- 1516/tcp: Cluster communication (internal)
- 55000/tcp: Wazuh API (restricted access)
- 9200/tcp: Indexer (localhost only)
- 5601/tcp: Dashboard (restricted networks)
```

### 4. Security Hardening

**System Hardening:**
- Kernel parameter optimization (sysctl)
- File permission enforcement
- Audit daemon integration
- Fail2ban intrusion prevention
- Automated security patching

**Application Hardening:**
- Secure default configurations
- SSL/TLS certificate validation
- Input validation and sanitization
- Security headers enforcement

## Implementation Guide

### Prerequisites

1. Ubuntu 22.04/24.04 LTS
2. Ansible 2.14+ with required collections
3. Sufficient resources (min 4GB RAM for Wazuh server)

### Quick Start

1. **Setup Vault Configuration:**
```bash
cd deploy/
cp vars/vault.yml.example vars/vault.yml
# Edit vault.yml with secure passwords
ansible-vault encrypt vars/vault.yml
```

2. **Deploy Wazuh Security:**
```bash
# For standalone Wazuh
ansible-playbook wazuh.yml --ask-vault-pass

# For full DHIS2 + Wazuh integration
ansible-playbook dhis2.yml wazuh.yml --ask-vault-pass
```

3. **Verify Security Status:**
```bash
# Run security validation
./test/validate-wazuh-security.sh

# Check service status
systemctl status wazuh-manager wazuh-indexer wazuh-dashboard
```

### Security Configuration

#### Vault Variables

Create `deploy/vars/vault.yml` with:
```yaml
vault_wazuh_api_password: "SecureAPIPassword2024!"
vault_wazuh_cluster_key: "32CharacterClusterKeyHere123456"
vault_wazuh_authd_pass: "AgentEnrollmentPassword!"
vault_wazuh_indexer_admin_password: "IndexerAdminPass2024!"
vault_wazuh_dashboard_admin_password: "DashboardAdmin2024!"
```

#### Custom Security Rules

Add custom detection rules in `/var/ossec/etc/rules/local_rules.xml`:
```xml
<group name="custom,">
  <rule id="100001" level="10">
    <if_sid>5503</if_sid>
    <match>Failed password for admin</match>
    <description>Admin account brute force attempt</description>
  </rule>
</group>
```

## Security Monitoring

### Dashboard Access

Access the Wazuh dashboard:
- URL: `https://<server-ip>:5601`
- Default credentials: admin / (vault password)

### Key Security Metrics

Monitor these critical security indicators:

1. **Authentication Failures**: Track failed login attempts
2. **File Integrity**: Monitor critical file changes
3. **Vulnerability Score**: CVE detection status
4. **Compliance Status**: PCI DSS, HIPAA compliance levels
5. **Agent Health**: Ensure all agents are connected

### Alert Configuration

Configure alerts for critical events:
```yaml
# /var/ossec/etc/ossec.conf
<alerts>
  <log_alert_level>3</log_alert_level>
  <email_alert_level>10</email_alert_level>
</alerts>
```

## Compliance & Auditing

### Supported Standards

- **PCI DSS**: Payment Card Industry compliance
- **HIPAA**: Healthcare data protection
- **GDPR**: EU data privacy regulation
- **CIS Benchmarks**: Security configuration standards

### Audit Logging

All security events are logged to:
- `/var/ossec/logs/alerts/alerts.json` (JSON format)
- `/var/ossec/logs/alerts/alerts.log` (Plain text)
- Elasticsearch indices for long-term retention

### Compliance Reports

Generate compliance reports:
```bash
# PCI DSS compliance report
curl -k -X GET "https://localhost:55000/reports/pci-dss" \
  -H "Authorization: Bearer $TOKEN"

# HIPAA compliance status
curl -k -X GET "https://localhost:55000/reports/hipaa" \
  -H "Authorization: Bearer $TOKEN"
```

## Incident Response

### Active Response Configuration

Automated threat mitigation:
```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>5710,5711,5712</rules_id>
  <timeout>600</timeout>
</active-response>
```

### Response Playbooks

1. **Brute Force Attack**:
   - Auto-block IP after 5 failed attempts
   - Alert security team
   - Generate incident report

2. **File Integrity Violation**:
   - Snapshot affected files
   - Roll back unauthorized changes
   - Investigate access logs

3. **Vulnerability Detection**:
   - Assess CVE severity
   - Apply patches immediately for critical
   - Schedule maintenance for others

## Backup & Recovery

### Security Data Backup

```bash
# Backup Wazuh configuration and data
/usr/local/bin/wazuh-backup.sh

# Backup locations:
# - /backup/wazuh/config/
# - /backup/wazuh/data/
# - /backup/wazuh/logs/
```

### Disaster Recovery

1. Restore from backup
2. Verify agent connections
3. Validate security rules
4. Test alert mechanisms

## Security Best Practices

### Do's
- ✅ Use Ansible Vault for all secrets
- ✅ Enable TLS for all communications
- ✅ Regularly update Wazuh and agents
- ✅ Monitor security dashboards daily
- ✅ Implement defense in depth
- ✅ Regular security audits
- ✅ Document all security changes

### Don'ts
- ❌ Never hardcode passwords
- ❌ Don't disable security features
- ❌ Avoid using default credentials
- ❌ Don't ignore security alerts
- ❌ Never expose management ports publicly

## Troubleshooting

### Common Issues

1. **Agent Connection Failed**:
```bash
# Check agent status
/var/ossec/bin/agent_control -l

# Restart agent
systemctl restart wazuh-agent
```

2. **API Authentication Error**:
```bash
# Test API connectivity
curl -k -u admin:password https://localhost:55000
```

3. **High Memory Usage**:
```bash
# Tune Wazuh memory settings
vi /etc/wazuh-indexer/jvm.options
# Set -Xms2g -Xmx2g
```

## Security Contacts

- **Security Team**: security@example.com
- **On-Call**: +1-xxx-xxx-xxxx
- **Incident Response**: incident@example.com

## References

- [Wazuh Documentation](https://documentation.wazuh.com/)
- [DHIS2 Security Guide](https://docs.dhis2.org/en/manage/performing-system-administration/dhis-core-version-master/installation.html#security)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP Security Guidelines](https://owasp.org/)

---

*Last Updated: 2024*
*Version: 1.0*
*Classification: Internal Use*