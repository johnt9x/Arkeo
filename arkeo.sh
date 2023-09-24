#!/bin/bash

# Prompt for the moniker
read -p "Enter your moniker (a short name for your node): " MONIKER

# Check if the MONIKER is empty and prompt again until it's not empty
while [ -z "$MONIKER" ]; do
    read -p "Moniker cannot be empty. Please enter your moniker: " MONIKER
done

# Install dependencies
echo "Installing dependencies..."
sudo apt -q update
sudo apt -qy install curl git jq lz4 build-essential
sudo apt -qy upgrade

# Install Go
echo "Installing Go..."
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.20.8.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)

# Download binaries
echo "Downloading binaries..."
cd $HOME
wget https://snapshots.l0vd.com/arkeo-testnet/arkeod
chmod +x arkeod
mv arkeod /root/go/bin/
arkeod version

# Create service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/arkeod.service > /dev/null << EOF
[Unit]
Description=Arkeo testnet
After=network-online.target

[Service]
User=$USER
ExecStart=$(which arkeod) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable arkeod

# Initialize the node
echo "Initializing the node..."
arkeod config chain-id arkeo
arkeod config keyring-backend test
arkeod config node tcp://localhost:18657
arkeod init $MONIKER --chain-id arkeo

# Download genesis and addrbook
echo "Downloading genesis and addrbook..."
curl -Ls https://raw.githubusercontent.com/johnt9x/Arkeo/main/genesis.json > $HOME/.arkeo/config/genesis.json
curl -Ls https://raw.githubusercontent.com/johnt9x/Arkeo/main/addrbook.json > $HOME/.arkeo/config/addrbook.json

# Add seeds
PEERS="cb9401d70e1bd59e3ed279942ce026dae82aca1f@arkeo-testnet.peers.l0vd.com:27656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.arkeo/config/config.toml

# Set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0uarkeo\"/" $HOME/.arkeo/config/app.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.arkeo/config/config.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "50"|' \
  $HOME/.arkeo/config/app.toml

# Set custom ports
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:18658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:18657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:18660\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:18656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":18666\"%" $HOME/.arkeo/config/config.toml
sed -i -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:18617\"%; s%^address = \":8080\"%address = \":18680\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:18690\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:18691\"%; s%:8545%:18645%; s%:8546%:18646%; s%:6065%:18665%" $HOME/.arkeo/config/app.toml

# Start service and check the logs
echo "Starting the arkeod service..."
arkeod tendermint unsafe-reset-all --home $HOME/.arkeo --keep-addr-book
sudo systemctl restart arkeod

echo '=============== SETUP FINISHED ==================='
echo -e 'To check logs: \e[1m\e[32mjournalctl -u arkeod -f -o cat\e[0m'
echo -e "To check sync status: \e[1m\e[32mcurl -s localhost:18657/status | jq .result.sync_info\e[0m"
