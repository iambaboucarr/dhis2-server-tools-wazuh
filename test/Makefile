# DHIS2 + Wazuh Integration Test Environment Makefile

.PHONY: help start deploy verify test tunnel clean destroy status

# Default target
help: ## Show this help message
	@echo "DHIS2 + Wazuh Integration Test Environment"
	@echo "=========================================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start: make test"

start: ## Start the Vagrant VM
	@echo "Starting Vagrant VM..."
	vagrant up
	@echo "VM started successfully!"
	@echo "SSH: vagrant ssh"

deploy: start ## Deploy DHIS2 with Wazuh integration
	@echo "Deploying DHIS2 with Wazuh integration..."
	vagrant ssh -c "cd /opt/dhis2-deploy && sudo ../test/test-deploy.sh"
	@echo "Deployment completed!"

verify: ## Run verification tests (requires deployment)
	@echo "Running verification tests..."
	vagrant ssh -c "cd /opt/dhis2-deploy && ./test-verify.sh"

tunnel: ## Test SSH port forwarding (requires deployment)
	@echo "Testing SSH port forwarding..."
	./test-ssh-tunnel.sh

test: deploy verify ## Full test suite (start VM, deploy, verify)
	@echo "Running full test suite..."
	@echo "✅ Full test suite completed successfully!"

status: ## Show VM and container status
	@echo "Vagrant VM status:"
	vagrant status
	@echo ""
	@echo "Container status:"
	-vagrant ssh -c "sudo lxc list" 2>/dev/null || echo "VM not running or LXD not ready"

logs: ## Show deployment and service logs
	@echo "Recent deployment logs:"
	vagrant ssh -c "sudo journalctl -u lxd --no-pager -n 50"
	@echo ""
	@echo "Wazuh manager logs:"
	-vagrant ssh -c "sudo lxc exec wazuh -- tail -20 /var/ossec/logs/ossec.log" 2>/dev/null || echo "Wazuh not running"

shell: ## SSH into the VM
	vagrant ssh

clean: ## Stop VM and clean up containers
	@echo "Cleaning up containers..."
	-vagrant ssh -c "sudo lxc list --format csv -c n | xargs -r sudo lxc delete --force" 2>/dev/null
	@echo "Stopping VM..."
	vagrant halt
	@echo "Cleanup completed!"

destroy: ## Destroy VM completely
	@echo "Destroying VM (this will delete all data)..."
	vagrant destroy -f
	@echo "VM destroyed!"

rebuild: destroy start ## Destroy and recreate VM
	@echo "VM rebuilt successfully!"

# Development targets
dev-deploy: ## Deploy with development settings (faster, less secure)
	@echo "Deploying with development settings..."
	vagrant ssh -c "cd /opt/dhis2-deploy && sudo ansible-playbook dhis2.yml --tags wazuh --skip-tags backup-script,unattended-upgrades"

quick-test: start ## Quick test (minimal deployment + basic verification)
	@echo "Running quick test..."
	vagrant ssh -c "cd /opt/dhis2-deploy && sudo ansible-playbook dhis2.yml --tags wazuh --limit wazuh"
	vagrant ssh -c "cd /opt/dhis2-deploy && ./test-verify.sh | grep -E '(PASS|FAIL|Test)'"

# Monitoring targets
monitor-wazuh: ## Monitor Wazuh logs in real-time
	vagrant ssh -c "sudo lxc exec wazuh -- tail -f /var/ossec/logs/ossec.log"

monitor-dhis2: ## Monitor DHIS2 logs in real-time  
	vagrant ssh -c "sudo lxc exec dhis -- tail -f /opt/dhis2/*/logs/dhis.log"

monitor-system: ## Monitor system resources
	watch -n 5 'vagrant ssh -c "free -h && echo && df -h && echo && sudo lxc list"'

# Access helpers
dashboard: ## Open Wazuh dashboard (sets up tunnel)
	@echo "Setting up SSH tunnel for Wazuh dashboard..."
	@echo "Dashboard will be available at: https://localhost:5601"
	@echo "Credentials: admin/TestPassword123!"
	@echo "Press Ctrl+C to close tunnel"
	vagrant ssh -- -L 5601:172.19.2.40:5601 -N

dhis2: ## Open DHIS2 web interface
	@echo "DHIS2 available at: https://192.168.56.10"
	@echo "Credentials: admin/district"
	@command -v open >/dev/null 2>&1 && open https://192.168.56.10 || echo "Please open https://192.168.56.10 manually"

# Information targets
info: ## Show connection information
	@echo "=== DHIS2 + Wazuh Test Environment ==="
	@echo ""
	@echo "VM Information:"
	@echo "  IP Address: 192.168.56.10"
	@echo "  SSH: vagrant ssh (or ssh vagrant@192.168.56.10)"
	@echo ""
	@echo "DHIS2 Access:"
	@echo "  URL: https://192.168.56.10"
	@echo "  Credentials: admin/district"
	@echo ""
	@echo "Wazuh Dashboard Access (SSH tunnel required):"
	@echo "  Command: make dashboard"
	@echo "  URL: https://localhost:5601"
	@echo "  Credentials: admin/TestPassword123!"
	@echo ""
	@echo "Container IPs:"
	-vagrant ssh -c "sudo lxc list --format csv -c n,4 2>/dev/null | grep -v '^$$' | sed 's/^/  /'" || echo "  (VM not running)"

# Validation targets
validate-ansible: ## Validate Ansible configuration
	vagrant ssh -c "cd /opt/dhis2-deploy && ansible-playbook dhis2.yml --syntax-check"

validate-inventory: ## Validate inventory configuration
	vagrant ssh -c "cd /opt/dhis2-deploy && ansible-inventory --list -i ../test/inventory/hosts"

# Example usage
example: ## Show example usage commands
	@echo "Example Usage:"
	@echo "=============="
	@echo ""
	@echo "# Full test from scratch:"
	@echo "make test"
	@echo ""
	@echo "# Quick development cycle:"
	@echo "make start"
	@echo "make dev-deploy" 
	@echo "make verify"
	@echo ""
	@echo "# Monitor and debug:"
	@echo "make status"
	@echo "make logs"
	@echo "make shell"
	@echo ""
	@echo "# Access services:"
	@echo "make dashboard  # Wazuh (tunnel)"
	@echo "make dhis2      # DHIS2 (direct)"
	@echo ""
	@echo "# Cleanup:"
	@echo "make clean      # Stop VM, keep data"
	@echo "make destroy    # Delete everything"