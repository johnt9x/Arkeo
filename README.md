# Arkeo

Port: 186. Chain id: arkeo

# Automatic:
```
wget -O arkeo.sh https://raw.githubusercontent.com/johnt9x/Arkeo/main/arkeo.sh && chmod +x arkeo.sh && ./arkeo.sh
```
# Snapshot:
```
sudo systemctl stop arkeod
cp $HOME/.arkeo/data/priv_validator_state.json $HOME/.arkeo/priv_validator_state.json.backup
rm -rf $HOME/.arkeo/data 
curl https://testnet-files.itrocket.net/arkeo/snap_arkeo.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.arkeo
mv $HOME/.arkeo/priv_validator_state.json.backup $HOME/.arkeo/data/priv_validator_state.json
sudo systemctl restart arkeod && sudo journalctl -u arkeod -f
```
# Manual:
Replace YOUR_MONIKER_GOES_HERE with your validator name

MONIKER="YOUR_MONIKER_GOES_HERE"

Install dependencies
UPDATE SYSTEM AND INSTALL BUILD TOOLS
```
sudo apt -q update
sudo apt -qy install curl git jq lz4 build-essential
sudo apt -qy upgrade
```
INSTALL GO
```
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.20.8.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
```
Download binaries
```
cd $HOME
rm -rf arkeod
wget https://testnet-files.itrocket.net/arkeo/arkeod
chmod +x arkeod
mv arkeod /root/go/bin/
arkeod version
```
# Create service
```
sudo tee /etc/systemd/system/arkeod.service > /dev/null << EOF
[Unit]
Description=arkeoension node service
After=network-online.target

[Service]
sudo tee /etc/systemd/system/arkeod.service > /dev/null <<EOF
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
```
# Set node configuration
```
arkeod config chain-id arkeo
arkeod config keyring-backend test
arkeod config node tcp://localhost:18657
```
# Initialize the node
```
arkeod init $MONIKER --chain-id arkeo
```
# Download genesis and addrbook
```
curl -Ls https://raw.githubusercontent.com/johnt9x/Arkeo/main/genesis.json > $HOME/.arkeo/config/genesis.json
curl -Ls https://raw.githubusercontent.com/johnt9x/Arkeo/main/addrbook.json > $HOME/.arkeo/config/addrbook.json
```
# Add seeds
```
PEERS="a4dbd1be41263b6c84194c8009f6e109f2aba3f2@62.171.130.196:18656,5c2a752c9b1952dbed075c56c600c3a79b58c395@195.3.223.168:27346,1eaeb5b9cb2cc1ae5a14d5b87d65fef89998b467@65.108.141.109:17656,b487e892071fd3d89cc9d0de60eeed60ba7c4e5c@65.109.116.119:15756,cb9401d70e1bd59e3ed279942ce026dae82aca1f@65.109.33.48:27656,65c95f70cf0ca8948f6ff59e83b22df3f8484edf@65.108.226.183:22856,3f9bc5552f02dce211db24d5e42c118c61c4abde@65.108.8.28:60656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.arkeo/config/config.toml
sed -i -e "s|^seeds *=.*|seeds = \"\"|" $HOME/.arkeo/config/config.toml
```
# Set minimum gas price
```
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0uarkeo\"/" $HOME/.arkeo/config/app.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.arkeo/config/config.toml
```
# Set pruning
```
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.arkeo/config/app.toml
```
# Set custom ports
```
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:18658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:18657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:18660\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:18656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":18666\"%" $HOME/.arkeo/config/config.toml
sed -i -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:18617\"%; s%^address = \":8080\"%address = \":18680\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:18690\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:18691\"%; s%:8545%:18645%; s%:8546%:18646%; s%:6065%:18665%" $HOME/.arkeo/config/app.toml
```
# Start service and check the logs
```
sudo systemctl start arkeod && sudo journalctl -u arkeod -f --no-hostname -o cat
```
