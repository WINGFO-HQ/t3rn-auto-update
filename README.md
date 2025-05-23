# T3rn Executor Node Auto-Update Version
_This repository contains scripts to set up, manage, and automatically update a T3rn Executor Node. The system provides automatic updates by checking for new releases from the official T3rn GitHub repository._

# Installation
**Run the Installation Script**
```bash
git clone https://github.com/WINGFO-HQ/t3rn-auto-update && cd t3rn-auto-update && chmod +x ./t3rn-setup.sh && ./t3rn-setup.sh
```

# Features
- One-click Installation: Easy setup of the T3rn Executor Node
- Automatic Updates: Checks for new releases every 6 hours
- Secure Private Key Management: Safely stores your EVM private key
- Systemd Integration: Runs as a background service and starts on boot
- Comprehensive Logging: Keeps track of updates and system status

# Requirements
- Ubuntu 20.04+ or Debian-based Linux distribution
- Sudo privileges
- Internet connection
- EVM private key for your node

# The script will:
- Install required dependencies
- Download the latest T3rn Executor release
- Ask for your EVM private key
- Configure the environment
- Set up the executor as a systemd service
- Install the auto-update system

# Automatic Updates
**After installation, the system will:**
- Check for updates every 6 hours
- Update automatically when a new version is released
- Restart the service after updating
- Log all activities

# Manual Commands
Control the Executor Service
```bash
# Start the service
sudo systemctl start t3rn-executor

# Stop the service
sudo systemctl stop t3rn-executor

# Restart the service
sudo systemctl restart t3rn-executor

# Check service status
sudo systemctl status t3rn-executor
```

# Update Operations
```bash
# Check for updates manually
$HOME/t3rn-auto-update.sh

# Force an update (even if already on latest version)
$HOME/t3rn/t3rn-updater.sh force

# View update logs
cat #HOME/t3rn/auto_update.log
```

# Troubleshooting
**Service Won't Start, Check the service logs:**
```bash
sudo journalctl -u t3rn-executor -f
```

Common issues:
- Invalid private key
- Network connectivity problems
- Insufficient permissions

# Update Failures
**Check the update logs:**
```bash
cat $HOME/t3rn/auto_update.log
```

Common issues:
- GitHub API rate limiting
- Network connectivity problems
- Disk space issues

# Disable automatic updates
```bash
sudo systemctl stop t3rn-auto-update.timer && \
sudo systemctl disable t3rn-auto-update.timer
```

# How do I uninstall everything?
Run:
```bash
sudo systemctl stop t3rn-executor && \
sudo systemctl disable t3rn-executor && \
sudo systemctl stop t3rn-auto-update.timer && \
sudo systemctl disable t3rn-auto-update.timer && \
sudo rm /etc/systemd/system/t3rn-executor.service && \
sudo rm /etc/systemd/system/t3rn-auto-update.service && \
sudo rm /etc/systemd/system/t3rn-auto-update.timer && \
sudo systemctl daemon-reload && \
rm -rf ~/t3rn && \
cd $HOME && rm -r t3rn-auto-update
```
For more information about T3rn, visit the [official website](https://t3rn.io/) or the [GitHub repository](https://github.com/t3rn/executor-release).
