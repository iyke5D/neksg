#!/bin/bash

# ANSI color escape codes
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

work_dir="/etc/neksg"

# Function to display server information
display_server_info() {
    clear
    echo -e "${GREEN}Server Information${NC}"
    echo -e "${GREEN}IP Address:${NC} $(hostname -I | cut -d' ' -f1)"
    echo -e "${GREEN}RAM:${NC} $(free -h | awk '/Mem/{print $2}')"
    
    # Retrieve ISP information using curl
    isp=$(curl -s ifconfig.me/isp)
    
    if [ -n "$isp" ]; then
        echo -e "${GREEN}ISP:${NC} $isp"
    else
        echo -e "${GREEN}ISP:${NC} Not Available"
    fi
    
    read -p "Press Enter to continue..."
}

# Command to create a VPN account
create_account() {
    username=$2             # Get the username from the second argument
    password=$3             # Get the password from the third argument
    duration=$4             # Get the duration from the fourth argument
    limit_conn_single=$5    # Get the connection limit from the fifth argument
    
    # Add logic to create the VPN account
    echo "$username:$password:$duration:$limit_conn_single:active" >> "$work_dir/auth.txt"
}

# Command to block a VPN account
block_account() {
    username=$2             # Get the username from the second argument
    
    # Add logic to block the VPN account
    sed -i "/^$username/s/:active$/:blocked/" "$work_dir/auth.txt"
}

# Command to unblock a VPN account
unblock_account() {
    username=$2             # Get the username from the second argument
    
    # Add logic to unblock the VPN account
    sed -i "/^$username/s/:blocked$/:active/" "$work_dir/auth.txt"
}

# Command to renew a VPN account
renew_account() {
    username=$2             # Get the username from the second argument
    new_duration=$3         # Get the new duration from the third argument
    
    # Add logic to renew the VPN account
    sed -i "/^$username/s/:[0-9]*:/:$new_duration:/" "$work_dir/auth.txt"
}

# Command to remove a VPN account
remove_account() {
    username=$2             # Get the username from the second argument
    
    # Add logic to remove the VPN account
    sed -i "/^$username/d" "$work_dir/auth.txt"
}

# Command to remove all user accounts with 0 days left
remove_expired_accounts() {
    # Add logic to remove accounts with 0 days left
    sed -i '/:0:active$/d' "$work_dir/auth.txt"
}

# Command to display account details
display_account_details() {
    # Add logic to display account details
    while IFS=: read -r username _ status; do
        if [[ $status == "active" ]]; then
            echo -e "${GREEN}$username${NC}"
        elif [[ $status == "blocked" ]]; then
            echo -e "${RED}$username${NC}"
        fi
    done < "$work_dir/auth.txt"
}

# Parse command from arguments
case $1 in
    create) create_account "$@";;
    block) block_account "$@";;
    unblock) unblock_account "$@";;
    renew) renew_account "$@";;
    remove) remove_account "$@";;
    remove_expired) remove_expired_accounts;;
    display) display_account_details;;
    display_server) display_server_info;;
esac
