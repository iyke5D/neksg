#!/bin/bash

# ANSI color escape codes
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

work_dir="/etc/neksg"

banner() {
    clear
    figlet -k  RICKYS | lolcat
    echo -e "${ORANGE}  LinkLayer VPN Account Manager UI${NC}"
    echo -e "${ORANGE}  version: 1.0.1  |  by: @kwadeous${NC}"
    echo -e "${ORANGE}  Host/IP:$(hostname -I | cut -d' ' -f1)${NC}"
    echo -e "${ORANGE}  ISP: $(wget -qO- ipinfo.io/org)${NC}"
}

# Function to display server information
display_server_info() {
    banner
    echo -e "${GREEN}Server Information${NC}"
    echo -e "${GREEN}IP Address:${NC} $(hostname -I | cut -d' ' -f1)"
    echo -e "${GREEN}RAM:${NC} $(free -h | awk '/Mem/{print $2}')"
    
    # Retrieve ISP information using curl
    isp=$(wget -qO- ipinfo.io/org)
    
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
    display_account_details  # Display existing account details before creating a new account
    
    read -p "Enter username: " username
    
    # Check if the username is empty
    if [ -z "$username" ]; then
        echo -e "${RED}Error:${NC} Username cannot be empty."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check if the username already exists
    if grep -q "^$username:" "$work_dir/auth.txt"; then
        echo -e "${RED}Error:${NC} Username already exists."
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Enter password: " password
    echo # for a new line
    read -p "Enter duration(in days): " duration
    read -p "Enter user account limit (enter -1 for unlimited): " limit_conn_single
    
    # Execute the auth.sh script to create the VPN account
    cd $work_dir
    ./auth.sh create "$username" "$password" "$duration" "$limit_conn_single"
    echo -e "${GREEN}Account created successfully.${NC}"
    
    # Display the details of the newly created account on a new page
    display_single_account "$username" "$password" "$duration" "$limit_conn_single"
}

# Function to block a VPN account
block_account() {
    banner
    echo -e "${ORANGE}Block VPN Account${NC}"
    
    # Display current account details before prompting for blocking
    display_account_details
    
    read -p "Enter username to block: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" "$work_dir/auth.txt"; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Execute the auth.sh script to block the VPN account
    cd $work_dir
    ./auth.sh block "$username"
    echo -e "${GREEN}Account blocked successfully.${NC}"
    
    # Disconnect the user's IP address from accessing the internet via iptables
    user_ip=$(grep "^$username:" "$work_dir/auth.txt" | cut -d':' -f6)
    if [ -n "$user_ip" ]; then
        sudo iptables -D INPUT -s "$user_ip" -j ACCEPT
        sudo iptables -A INPUT -s "$user_ip" -j DROP
    fi
    
    # Display updated account details after blocking
    display_account_details
}

# Function to unblock a VPN account
unblock_account() {
    banner
    echo -e "${ORANGE}Unblock VPN Account${NC}"
    
    # Display current account details before prompting for unblocking
    display_account_details
    
    read -p "Enter username to unblock: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" "$work_dir/auth.txt"; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Execute the auth.sh script to unblock the VPN account
    cd $work_dir
    ./auth.sh unblock "$username"
    echo -e "${GREEN}Account unblocked successfully.${NC}"
    
    # Re-allow the user's IP address to access the internet via iptables
    user_ip=$(grep "^$username:" "$work_dir/auth.txt" | cut -d':' -f6)
    if [ -n "$user_ip" ]; then
        sudo iptables -D INPUT -s "$user_ip" -j DROP
        sudo iptables -A INPUT -s "$user_ip" -j ACCEPT
    fi
    
    # Display updated account details after unblocking
    display_account_details
}

# Function to renew a VPN account
renew_account() {
    banner
    echo -e "${ORANGE}Renew VPN Account${NC}"
    
    # Display current account details before prompting for renewal
    display_account_details
    
    read -p "Enter username to renew: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" "$work_dir/auth.txt"; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Enter new duration (in days): " new_duration
    
    # Execute the auth.sh script to renew the VPN account
    cd $work_dir
    ./auth.sh renew "$username" "$new_duration"
    echo -e "${GREEN}Account renewed successfully.${NC}"
    
    # Display updated account details after renewal
    display_account_details
}

# Function to remove a VPN account
remove_account() {
    banner
    echo -e "${ORANGE}Remove VPN Account${NC}"
    
    # Display current account details before prompting for removal
    display_account_details
    
    read -p "Enter username to remove: " username
    
    # Check if the username exists
    if ! grep -q "^$username:" "$work_dir/auth.txt"; then
        echo -e "${RED}Error:${NC} Username does not exist."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Disconnect the user's IP address from accessing the internet via iptables
    user_ip=$(grep "^$username:" "$work_dir/auth.txt" | cut -d':' -f6)
    if [ -n "$user_ip" ]; then
        sudo iptables -D INPUT -s "$user_ip" -j DROP
    fi
    
    # Execute the auth.sh script to remove the VPN account
    cd $work_dir
    ./auth.sh remove "$username"
    echo -e "${GREEN}Account removed successfully.${NC}"
    
    # Display updated account details after removal
    display_account_details
}

# Function to remove accounts with 0 days left
remove_expired_accounts() {
    banner
    echo -e "${ORANGE}Remove Expired Accounts${NC}"
    
    # Filter out accounts with 0 days left
    tmp_file=$(mktemp)
    
    while IFS= read -r line; do
        days_left=$(echo "$line" | cut -d':' -f3)
        
        # Filter out expired accounts (days_left > 0)
        if [ "$days_left" -gt 0 ]; then
            echo "$line" >> "$tmp_file"
        else
            # Disconnect the user's IP address from accessing the internet via iptables
            user_ip=$(echo "$line" | cut -d':' -f6)
            if [ -n "$user_ip" ]; then
                sudo iptables -D INPUT -s "$user_ip" -j DROP
            fi
        fi
    done < "$work_dir/auth.txt"
    
    # Overwrite "$work_dir/auth.txt" with the filtered accounts
    mv "$tmp_file" "$work_dir/auth.txt"
    
    echo -e "${GREEN}Expired accounts removed successfully.${NC}"
    read -p "Press Enter to continue..."
}
# Function to display centre banner
banner_centre() {
    clear
    figlet -c -k RICKYS | lolcat
    echo -e "${ORANGE}                       LinkLayer VPN Account Manager UI${NC}"
    echo -e "${ORANGE}                        version: 1.0.1 | by: @kwadeous${NC}"
}

# Function to display user account details
display_account_details() {
    banner_centre
    echo -e "${ORANGE}                            User Account Details${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${GREEN}Username        | Expiry Date | Days Left |      limit       | Status${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
    while IFS= read -r line; do
        username=$(echo "$line" | cut -d':' -f1)
        expiry_date=$(date -d "+$(echo "$line" | cut -d':' -f3) days" +%Y-%m-%d)
        days_left=$(echo "$line" | cut -d':' -f3)
        limit_conn_single=$(echo "$line" | cut -d':' -f4)
        status=$(echo "$line" | cut -d':' -f5)
        user_ip=$(echo "$line" | cut -d':' -f6)
        
        # Determine color based on status
        if [ "$status" = "active" ]; then
            status_color=$(echo -e "${GREEN}$status${NC}")  # Green for active
        elif [ "$status" = "blocked" ]; then
            status_color=$(echo -e "${RED}$status${NC}")  # Red for blocked
        else
            status_color="$status"  # Default color
        fi
        
        # Print details with cyan color
        printf "${CYAN}%-15s | %-11s | %-9s | %-16s | %s${NC}\n" "$username" "$expiry_date" "$days_left" "$limit_conn_single" "$status_color"
    done < "$work_dir/auth.txt" 
    echo -e "${BLUE}=====================================================================${NC}"
    read -p "Press Enter to continue..."
}
# New account details banner
banner_new_acc() {
    clear
    figlet -k  RICKYS | lolcat
    echo -e "${ORANGE}  LinkLayer VPN Account Manager UI${NC}"
    echo -e "${ORANGE}   version: 1.0.1 | by: @kwadeous${NC}"
}
# Function to display details of a single account
display_single_account() {
    banner_new_acc
    echo -e "${ORANGE}      New User Account Details${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}  Username${NC}": "${GREEN}$1${NC}"
    echo -e "${CYAN}  Password${NC}": "${GREEN}$2${NC}"
    echo -e "${CYAN}  Duration${NC}": "${GREEN}$3 days${NC}"
    echo -e "${CYAN}  Limit   ${NC}": "${GREEN}$4${NC}"
    echo -e "${CYAN}  Host/IP ${NC}": "${GREEN}$5$(hostname -I | cut -d' ' -f1)${NC}"
    echo -e "${BLUE}========================================${NC}"
    read -p "Press Enter to continue..."
}

# Function to update account statuses and disconnect expired accounts
update_account_status() {
    while true; do
        # Check for expired accounts with 0 days left
        tmp_file=$(mktemp)
        
        while IFS= read -r line; do
            days_left=$(echo "$line" | cut -d':' -f3)
            
            if [ "$days_left" -eq 0 ]; then
                # Disconnect the user's IP address from accessing the internet via iptables
                user_ip=$(echo "$line" | cut -d':' -f6)
                if [ -n "$user_ip" ]; then
                    sudo iptables -D INPUT -s "$user_ip" -j DROP
                fi
            else
                echo "$line" >> "$tmp_file"
            fi
        done < "$work_dir/auth.txt"
        
        # Overwrite "$work_dir/auth.txt" with the filtered accounts
        mv "$tmp_file" "$work_dir/auth.txt"
        
        sleep 300  # Adjust sleep interval based on your needs (e.g., every 5 minutes)
    done
}

# Main menu
update_account_status &  # Run update_account_status in the background
while true; do
    banner
    echo -e "${BLUE}••••••••••••••••••••••••••••••••••••••${NC}"
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
    echo -e "${BLUE}  ${NC} ${GREEN}[1] Display Server Info. ${NC}"
    echo -e "${BLUE}  ${NC} ${BLUE}[2] Create Account ${NC}"
    echo -e "${BLUE}  ${NC} ${ORANGE}[3] Block Account ${NC}"
    echo -e "${BLUE}  ${NC} ${BLUE}[4] Unblock Account  ${NC}"
    echo -e "${BLUE}  ${NC} ${GREEN}[5] Renew Account ${NC}"
    echo -e "${BLUE}  ${NC} ${RED}[6] Remove Account ${NC}"
    echo -e "${BLUE}  ${NC} ${CYAN}[7] Display Account Details ${NC}"
    echo -e "${BLUE}  ${NC} ${ORANGE}[8] Remove All Expired Accounts ${NC}"
    echo -e "${BLUE}  ${NC} ${RED}[0] Exit ${NC}"
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
    echo -e "${BLUE}••••••••••••••••••••••••••••••••••••••${NC}"
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
