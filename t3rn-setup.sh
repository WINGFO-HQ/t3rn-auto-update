#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directory paths
T3RN_HOME="$HOME/t3rn"
VERSION_FILE="$T3RN_HOME/current_version"
CONFIG_FILE="$T3RN_HOME/executor.env"
LOG_FILE="$T3RN_HOME/auto_update.log"

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create t3rn directory if it doesn't exist
mkdir -p "$T3RN_HOME"
touch "$LOG_FILE"

# Print banner
print_banner() {
    echo -e "${BLUE}╔═════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                         ║${NC}"
    echo -e "${BLUE}║${GREEN}      T3rn Executor Node Automatic Updater             ${BLUE}║${NC}"
    echo -e "${BLUE}║                                                         ║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════════════╝${NC}"
}

# Function to check for new releases
check_for_updates() {
    log "${BLUE}Checking for T3rn Executor updates...${NC}"
    
    # Get latest release version from GitHub
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    if [ -z "$LATEST_RELEASE" ]; then
        log "${RED}Failed to fetch latest release information${NC}"
        return 1
    fi
    
    log "${BLUE}Latest available version: ${LATEST_RELEASE}${NC}"
    
    # Get current version if available
    CURRENT_VERSION=""
    if [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION=$(cat "$VERSION_FILE")
        log "${BLUE}Current installed version: ${CURRENT_VERSION}${NC}"
    else
        log "${YELLOW}No current version information found. First installation or update required.${NC}"
    fi
    
    # Check if update is needed
    if [ "$CURRENT_VERSION" = "$LATEST_RELEASE" ]; then
        log "${GREEN}Already running the latest version ${LATEST_RELEASE}. No update needed.${NC}"
        return 1
    else
        log "${YELLOW}New version available: ${LATEST_RELEASE}. Updating from ${CURRENT_VERSION:-unknown}...${NC}"
        return 0
    fi
}

# Function to perform the update
update_executor() {
    log "${BLUE}Starting T3rn Executor update process...${NC}"
    
    # Stop service if running
    if systemctl is-active --quiet t3rn-executor; then
        log "Stopping T3rn Executor service..."
        sudo systemctl stop t3rn-executor
    fi
    
    # Backup existing configuration
    if [ -f "$CONFIG_FILE" ]; then
        log "Backing up environment configuration..."
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    fi
    
    # Get current directory
    cd "$HOME"
    
    # Download and extract new version
    log "Downloading T3rn Executor version ${LATEST_RELEASE}..."
    mkdir -p "$T3RN_HOME/temp" && cd "$T3RN_HOME/temp"
    
    if ! wget -q "https://github.com/t3rn/executor-release/releases/download/${LATEST_RELEASE}/executor-linux-${LATEST_RELEASE}.tar.gz"; then
        log "${RED}Failed to download version ${LATEST_RELEASE}${NC}"
        # Restore service if it was running
        if systemctl is-active --quiet t3rn-executor; then
            sudo systemctl start t3rn-executor
        fi
        return 1
    fi
    
    if ! tar -xzf "executor-linux-${LATEST_RELEASE}.tar.gz"; then
        log "${RED}Failed to extract archive${NC}"
        # Restore service if it was running
        if systemctl is-active --quiet t3rn-executor; then
            sudo systemctl start t3rn-executor
        fi
        return 1
    fi
    
    # Replace old executor with new one
    log "Installing new executor binary..."
    if [ -d "$T3RN_HOME/executor" ]; then
        rm -rf "$T3RN_HOME/executor"
    fi
    
    mv executor "$T3RN_HOME/"
    cd "$T3RN_HOME/executor/executor/bin"
    chmod +x executor
    
    # Restore configuration
    if [ -f "${CONFIG_FILE}.bak" ]; then
        log "Restoring environment configuration..."
        mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
    fi
    
    # Create or update version file
    echo "$LATEST_RELEASE" > "$VERSION_FILE"
    
    # Clean up temporary files
    rm -rf "$T3RN_HOME/temp"
    
    # Start service
    log "Starting T3rn Executor service..."
    sudo systemctl start t3rn-executor
    
    # Verify service is running
    sleep 3
    if systemctl is-active --quiet t3rn-executor; then
        log "${GREEN}✓ T3rn Executor updated to ${LATEST_RELEASE} and started successfully${NC}"
        return 0
    else
        log "${RED}✗ T3rn Executor service failed to start after update${NC}"
        return 1
    fi
}

# Create systemd service file for auto-updates
create_auto_update_service() {
    log "Creating auto-update service and timer..."
    
    # Create the auto-update script in the home directory for easy access
    cat > "$HOME/t3rn-auto-update.sh" << 'EOF'
#!/bin/bash
# This script runs the auto-update check
bash "$HOME/t3rn/t3rn-updater.sh" run
EOF
    chmod +x "$HOME/t3rn-auto-update.sh"
    
    # Create service file
    sudo tee /etc/systemd/system/t3rn-auto-update.service > /dev/null << EOF
[Unit]
Description=T3rn Executor Auto Update Service
After=network.target

[Service]
Type=oneshot
User=$USER
ExecStart=/bin/bash $HOME/t3rn-auto-update.sh
EOF

    # Create timer file for scheduled runs
    sudo tee /etc/systemd/system/t3rn-auto-update.timer > /dev/null << EOF
[Unit]
Description=Run T3rn Executor Auto Update every 6 hours

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable and start timer
    sudo systemctl enable t3rn-auto-update.timer
    sudo systemctl start t3rn-auto-update.timer
    
    log "${GREEN}Auto-update service and timer installed successfully${NC}"
    log "${BLUE}Updates will run automatically every 6 hours and at boot${NC}"
}

# Function to verify existing installation
verify_installation() {
    # Check if essential directories and files exist
    if [ ! -d "$T3RN_HOME" ] || [ ! -f "$CONFIG_FILE" ]; then
        log "${RED}T3rn Executor doesn't appear to be installed correctly${NC}"
        log "${YELLOW}Please run the initial installation script first${NC}"
        exit 1
    fi
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q t3rn-executor.service; then
        log "${RED}T3rn Executor service not found${NC}"
        log "${YELLOW}Please run the initial installation script first${NC}"
        exit 1
    fi
}

# Main execution logic
main() {
    print_banner
    
    # Get operation mode
    MODE="${1:-run}"
    
    case "$MODE" in
        install)
            # Save this script to the t3rn directory
            log "Installing the updater script..."
            cp "$0" "$T3RN_HOME/t3rn-updater.sh"
            chmod +x "$T3RN_HOME/t3rn-updater.sh"
            
            # Create the auto-update service
            create_auto_update_service
            echo -e "\n${GREEN}✓ Auto-update system installed successfully${NC}"
            echo -e "${YELLOW}• Updates will run automatically every 6 hours${NC}"
            echo -e "${YELLOW}• Manual update check: ${NC}bash $HOME/t3rn-auto-update.sh"
            echo -e "${YELLOW}• View logs: ${NC}cat $LOG_FILE"
            ;;
            
        force)
            # Force update regardless of version
            log "${YELLOW}Forced update requested...${NC}"
            # Get latest release version
            LATEST_RELEASE=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            if [ -z "$LATEST_RELEASE" ]; then
                log "${RED}Failed to fetch latest release information${NC}"
                exit 1
            fi
            update_executor
            ;;
            
        run|*)
            # Verify system before running
            verify_installation
            
            # Check for updates and apply if available
            if check_for_updates; then
                update_executor
            fi
            ;;
    esac
}

# Run main function
main "$@"
