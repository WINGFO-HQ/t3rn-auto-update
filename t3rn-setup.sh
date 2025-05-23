#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                        ║${NC}"
echo -e "${BLUE}║${GREEN}           T3rn Executor Node Setup Script            ${BLUE}║${NC}"
echo -e "${BLUE}║                                                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

# Function to show progress
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Install prerequisites
echo -e "\n${YELLOW}[1/5]${NC} Installing prerequisites..."
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y &
show_progress $!
echo -e "${GREEN}✓ Prerequisites installed successfully${NC}"

# Create t3rn directory if it doesn't exist
echo -e "\n${YELLOW}[2/5]${NC} Installing T3rn Executor Node..."
cd $HOME
if [ -d "t3rn" ]; then
    echo -e "${YELLOW}⚠ Existing T3rn installation found. Removing...${NC}"
    rm -rf t3rn
fi

mkdir -p t3rn && cd t3rn

# Get latest release version and download in one go
echo -e "${BLUE}• Fetching latest release and downloading...${NC}"
LATEST_RELEASE=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')

if [ -z "$LATEST_RELEASE" ]; then
    echo -e "${RED}✗ Failed to fetch latest release version${NC}"
    exit 1
fi

echo -e "${GREEN}• Latest release: ${LATEST_RELEASE}${NC}"

# Download and extract
echo -e "${BLUE}• Downloading executor...${NC}"
if wget -q "https://github.com/t3rn/executor-release/releases/download/${LATEST_RELEASE}/executor-linux-${LATEST_RELEASE}.tar.gz"; then
    echo -e "${GREEN}• Download completed${NC}"
else
    echo -e "${RED}✗ Failed to download executor${NC}"
    exit 1
fi

echo -e "${BLUE}• Extracting...${NC}"
tar -xzf executor-linux-*.tar.gz
cd executor/executor/bin
chmod +x executor
echo -e "${GREEN}✓ T3rn Executor Node installed successfully${NC}"

# Save current version
echo "$LATEST_RELEASE" > $HOME/t3rn/current_version

# Configure settings
echo -e "\n${YELLOW}[3/5]${NC} Configuring environment..."

# Ask for private key
echo -e "${YELLOW}➡️ Please enter your EVM Private Key (without 0x prefix):${NC}"
read -sp "Private Key: " PRIVATE_KEY
echo ""

# Validate private key format (simple check)
if [[ ! $PRIVATE_KEY =~ ^[a-fA-F0-9]{64}$ ]]; then
    echo -e "${RED}✗ Invalid private key format. It should be 64 hexadecimal characters.${NC}"
    exit 1
fi

# Create environment configuration
cat > $HOME/t3rn/executor.env << EOF
# T3rn Executor Environment Configuration
ENVIRONMENT=testnet
LOG_LEVEL=debug
LOG_PRETTY=false
EXECUTOR_PROCESS_BIDS_ENABLED=false
EXECUTOR_PROCESS_ORDERS_ENABLED=true
EXECUTOR_PROCESS_CLAIMS_ENABLED=true
EXECUTOR_MAX_L3_GAS_PRICE=550
PRIVATE_KEY_LOCAL=${PRIVATE_KEY}
EXECUTOR_ENABLED_NETWORKS='l2rn,arbitrum-sepolia,base-sepolia,binance-testnet,blast-sepolia,monad-testnet,optimism-sepolia,sei-testnet,unichain-sepolia'
EXECUTOR_ENABLED_ASSETS="eth,t3eth,t3mon,t3sei,mon,sei,bnb"
EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true
RPC_ENDPOINTS='{
    "l2rn": ["https://t3rn-b2n.blockpi.network/v1/rpc/public", "https://b2n.rpc.caldera.xyz/http"],
    "arbt": ["https://arbitrum-sepolia.drpc.org", "https://sepolia-rollup.arbitrum.io/rpc"],
    "bast": ["https://base-sepolia-rpc.publicnode.com", "https://base-sepolia.drpc.org"],
    "bsct": ["https://bsc-testnet.public.blastapi.io", "https://bsc-testnet.drpc.org", "https://bsc-testnet-rpc.publicnode.com"],
    "blst": ["https://sepolia.blast.io", "https://blast-sepolia.drpc.org"],
    "mont": ["https://testnet-rpc.monad.xyz", "https://monad-testnet.drpc.org"],
    "opst": ["https://sepolia.optimism.io", "https://optimism-sepolia.drpc.org"],
    "seit": ["https://sei-testnet.drpc.org", "https://evm-rpc-testnet.sei-apis.com"],
    "unit": ["https://unichain-sepolia.drpc.org", "https://sepolia.unichain.org"]
}'
EOF

# Create service file
echo -e "${BLUE}• Creating systemd service...${NC}"
sudo tee /etc/systemd/system/t3rn-executor.service > /dev/null << EOF
[Unit]
Description=T3rn Executor Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/t3rn/executor/executor/bin
EnvironmentFile=$HOME/t3rn/executor.env
ExecStart=$HOME/t3rn/executor/executor/bin/executor
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Download auto-updater script
echo -e "\n${YELLOW}[4/5]${NC} Installing auto-update system..."
wget -q -O $HOME/t3rn/t3rn-updater.sh https://raw.githubusercontent.com/WINGFO-HQ/t3rn-auto-update/main/t3rn-updater.sh
chmod +x $HOME/t3rn/t3rn-updater.sh

# Install auto-updater
$HOME/t3rn/t3rn-updater.sh install

# Reload systemd
sudo systemctl daemon-reload
echo -e "${GREEN}✓ Environment and auto-updater configured successfully${NC}"

# Starting the service
echo -e "\n${YELLOW}[5/5]${NC} Starting T3rn Executor Node..."
sudo systemctl enable t3rn-executor
sudo systemctl start t3rn-executor

# Check if service started successfully
sleep 3
if sudo systemctl is-active --quiet t3rn-executor; then
    echo -e "${GREEN}✓ T3rn Executor Node started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start T3rn Executor Node${NC}"
    echo -e "${YELLOW}• Check logs with: ${NC}sudo journalctl -u t3rn-executor -f"
fi

# Create control script
cat > $HOME/t3rn-control.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

case "$1" in
    start)
        echo -e "${BLUE}Starting T3rn Executor...${NC}"
        sudo systemctl start t3rn-executor
        ;;
    stop)
        echo -e "${BLUE}Stopping T3rn Executor...${NC}"
        sudo systemctl stop t3rn-executor
        ;;
    restart)
        echo -e "${BLUE}Restarting T3rn Executor...${NC}"
        sudo systemctl restart t3rn-executor
        ;;
    status)
        echo -e "${BLUE}T3rn Executor Status:${NC}"
        sudo systemctl status t3rn-executor
        ;;
    logs)
        echo -e "${BLUE}Showing T3rn Executor Logs:${NC}"
        sudo journalctl -u t3rn-executor -f
        ;;
    update)
        echo -e "${BLUE}Checking for updates...${NC}"
        bash $HOME/t3rn/t3rn-updater.sh run
        ;;
    force-update)
        echo -e "${BLUE}Forcing update to latest version...${NC}"
        bash $HOME/t3rn/t3rn-updater.sh force
        ;;
    *)
        echo -e "${YELLOW}Usage:${NC} bash t3rn-control.sh {start|stop|restart|status|logs|update|force-update}"
        exit 1
esac

exit 0
EOF

chmod +x $HOME/t3rn-control.sh

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}         T3rn Executor Node Setup Complete         ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "${YELLOW}• Status:${NC} sudo systemctl status t3rn-executor"
echo -e "${YELLOW}• Logs:${NC} sudo journalctl -u t3rn-executor -f"
echo -e "${YELLOW}• Update logs:${NC} cat $HOME/t3rn/auto_update.log"
echo -e "${YELLOW}• Control:${NC} bash $HOME/t3rn-control.sh {start|stop|restart|status|logs|update|force-update}"
echo -e "${YELLOW}• Config:${NC} $HOME/t3rn/executor.env"
echo -e "${GREEN}=====================================================${NC}"
echo -e "${BLUE}The system will automatically check for updates every 1 hours${NC}"
