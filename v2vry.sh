#!/bin/bash

# Function to print help
print_help() {
    echo "Usage: $0 --port PORT --user USERNAME --password PASSWORD"
    echo "Options:"
    echo "  --port PORT         Specify the port to use"
    echo "  --user USERNAME     Specify the username for SOCKS5 authentication"
    echo "  --password PASSWORD Specify the password for SOCKS5 authentication"
}

# Default values
PORT=""
USERNAME=""
PASSWORD=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --port)
        PORT="$2"
        shift # past argument
        shift # past value
        ;;
        --user)
        USERNAME="$2"
        shift # past argument
        shift # past value
        ;;
        --password)
        PASSWORD="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        print_help
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
    esac
done

# Check if required arguments are provided
if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Missing required arguments"
    print_help
    exit 1
fi

# Function to disable SELinux
disable_selinux() {
    echo "Disabling SELinux..."
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    echo "SELinux has been disabled. A reboot is required to fully apply changes."
}

# Function to install V2Ray
install_v2ray() {
    echo "Installing V2Ray..."
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --force
}

# Function to configure V2Ray
configure_v2ray() {
    echo "Configuring V2Ray..."
    CONFIG_FILE="/usr/local/etc/v2ray/config.json"
    sudo cat > $CONFIG_FILE << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": $PORT,
    "protocol": "socks",
    "settings": {
      "auth": "password",
      "accounts": [
        {
          "user": "$USERNAME",
          "pass": "$PASSWORD"
        }
      ],
      "udp": false
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    echo "V2Ray configuration has been written to $CONFIG_FILE"
}

# Function to start V2Ray
start_v2ray() {
    echo "Starting V2Ray..."
    sudo systemctl enable v2ray
    sudo systemctl start v2ray
}

# Main script
main() {
    disable_selinux
    install_v2ray
    configure_v2ray
    start_v2ray
    echo "V2Ray has been installed and configured to run on port $PORT with SOCKS5 authentication"
}

main
