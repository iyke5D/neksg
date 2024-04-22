#!/bin/bash

# ANSI color escape codes
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

banner() {
    clear
    figlet -k kwadze | lolcat
    echo -e "${ORANGE}  LinkLayer VPN Account Manager UI${NC}"
    echo -e "${ORANGE}    version: 007 | by: @kwadeous${NC}"
}

# Function to display server information
display_server_info() {
    banner
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

# Function to create a new VPN account
create_account() {
    banner
    echo -e "${ORANGE}Create New VPN Account${NC}"
    read -p "Enter username: " username
    
    # Check if the username is empty
    if [ -z "$username" ]; then
        echo -e "${RED}Error:${NC} Username cannot be empty."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check if the username already exists
    if grep -q "^$username:" auth.txt; then
        echo -e "${RED}Error:${NC} Username already exists."
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Enter password: " password
    echo # for a new line
    read -p "Enter duration (in days): " duration
    read -p "Enter user account limit (enter -1 for unlimited): " limit_conn_single
    
    # Execute the auth.sh script to create the VPN account
    ./auth.sh create "$username" "$password" "$duration" "$limit_conn_single"
    echo -e "${GREEN}Account created successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to block a VPN account
block_account() {
    banner
    echo -e "${ORANGE}Block VPN Account${NC}"
    read -p "Enter username to block: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" auth.txt; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Execute the auth.sh script to block the VPN account
    ./auth.sh block "$username"
    echo -e "${GREEN}Account blocked successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to unblock a VPN account
unblock_account() {
    banner
    echo -e "${ORANGE}Unblock VPN Account${NC}"
    read -p "Enter username to unblock: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" auth.txt; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Execute the auth.sh script to unblock the VPN account
    ./auth.sh unblock "$username"
    echo -e "${GREEN}Account unblocked successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to renew a VPN account
renew_account() {
    banner
    echo -e "${ORANGE}Renew VPN Account${NC}"
    read -p "Enter username to renew: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" auth.txt; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Enter new duration (in days): " new_duration
    
    # Execute the auth.sh script to renew the VPN account
    ./auth.sh renew "$username" "$new_duration"
    echo -e "${GREEN}Account renewed successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to remove a VPN account
remove_account() {
    banner
    echo -e "${ORANGE}Remove VPN Account${NC}"
    read -p "Enter username to remove: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" auth.txt; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Execute the auth.sh script to remove the VPN account
    ./auth.sh remove "$username"
    echo -e "${GREEN}Account removed successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to display user account details including expiry date, days left, and limit_conn_single
display_account_details() {
    banner
    echo -e "${ORANGE}VPN Account Details${NC}"
    # Logic to display user account details
    echo "====================================================================="
    echo -e "${GREEN}Username        | Expiry Date | Days Left |      limit       | Status${NC}"
    echo "====================================================================="
    while IFS= read -r line; do
        username=$(echo "$line" | cut -d':' -f1)
        expiry_date=$(date -d "+$(echo "$line" | cut -d':' -f3) days" +%Y-%m-%d)
        days_left=$(echo "$line" | cut -d':' -f3)
        limit_conn_single=$(echo "$line" | cut -d':' -f4)
        status=$(echo "$line" | cut -d':' -f5)
        printf "%-15s | %-11s | %-9s | %-16s | %s\n" "$username" "$expiry_date" "$days_left" "$limit_conn_single" "$status"
    done < auth.txt 
    echo "====================================================================="
    read -p "Press Enter to continue..."
}

# Function to remove all expired VPN accounts with 0 days left and connection limit
remove_expired_accounts() {
    banner
    echo -e "${ORANGE}Removing Expired VPN Accounts with 0 Days Left and Connection Limit${NC}"
    # Logic to remove expired accounts with 0 days left and connection limit
    while IFS= read -r line; do
        username=$(echo "$line" | cut -d':' -f1)
        days_left=$(echo "$line" | cut -d':' -f3)
        limit_conn_single=$(echo "$line" | cut -d':' -f4)
        
        if [ "$days_left" -eq 0 ] && [ "$limit_conn_single" -ne -1 ]; then
            ./auth.sh remove "$username"
        fi
    done < auth.txt
    echo -e "${GREEN}Expired VPN accounts removed successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Main menu
while true; do
    banner
    echo -e "${BLUE}+・・・・・・・・・・・・・・+${NC}"
    echo -e "${BLUE}|${NC} ${GREEN}1. Display Server Info. ${NC}"
    echo -e "${BLUE}>${NC} ${BLUE}2. Create Account ${NC}"
    echo -e "${BLUE}<${NC} ${ORANGE}3. Block Account ${NC}"
    echo -e "${BLUE}>${NC} ${BLUE}4. Unblock Account  ${NC}"
    echo -e "${BLUE}>${NC} ${GREEN}5. Renew Account ${NC}"
    echo -e "${BLUE}<${NC} ${BLUE}6. Remove Account ${NC}"
    echo -e "${BLUE}<${NC} ${GREEN}7. Display Account Details ${NC}"
    echo -e "${BLUE}>${NC} ${ORANGE}8. Remove All Expired Accounts ${NC}"
    echo -e "${BLUE}|${NC} ${RED}0. Exit ${NC}"
    echo -e "${BLUE}+・・・・・・・・・・・・・・+${NC}"
    read -p "Enter your choice: " choice
    
    case $choice in
        1) display_server_info;;
        2) create_account;;
        3) block_account;;
        4) unblock_account;;
        5) renew_account;;
        6) remove_account;;
        7) display_account_details;;
        8) remove_expired_accounts;;
        0) echo -e "${ORANGE}Exiting...${NC}"; clear; exit;;
        *) echo -e "${RED}Invalid choice.${NC} Please enter a valid option.";;
    esac
done

