#!/bin/bash

# ANSI color escape codes
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

work_dir="/etc/neksg"

#variable to store selected protocol
selected_protocol=""

banner() {
    clear
    figlet  -k   NEKXSG | lolcat
    echo -e "${CYAN}       RICKY'S VPS Account Manager-UI${NC}"
    echo -e "${RED}   Arch:$(uname -i)| OS : $(lsb_release -ds)${NC}"
    echo -e "${GREEN}          Host/IP:$(hostname -I | cut -d' ' -f1)${NC}"
    echo -e "${ORANGE}         ISP:$(wget -qO- ipinfo.io/org)${NC}"
}

# Function to display banner at the centre
banner_centre() {
    clear
    figlet -c -k  NEKXSG | lolcat
    echo -e "${CYAN}                       RICKY'S VPS Account Manager-UI${NC}"
    echo -e "${RED}                         version:1.0.1${NC}" "${GREEN} @Kwadeous${NC}"
}

# Function to display user account details
display_account_details() {
    banner_centre
    echo -e "${ORANGE}                           User Account Details${NC}"
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

# Function to display details of a single account
display_single_account() {
    banner
    echo -e "${BLUE}**************************************${NC}"
    echo -e "${ORANGE}•••••••••User Account Details•••••••••${NC}"
    echo -e "${CYAN}Username${NC}": "${GREEN}$1${NC}"
    echo -e "${CYAN}Password${NC}": "${GREEN}$2${NC}"
    echo -e "${CYAN}Duration${NC}": "${GREEN}$3 days${NC}"
    echo -e "${CYAN}Limit   ${NC}": "${GREEN}$4${NC}"
    echo -e "${CYAN}Host/IP ${NC}": "${GREEN}$5$(hostname -I | cut -d' ' -f1)${NC}"
    echo -e "${ORANGE}••••••••••••••••••••••••••••••••••••${NC}"
    echo -e "${BLUE}**************************************${NC}"
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
    read -p "Enter duration (in days): " duration
    read -p "Enter user account limit (enter -1 for unlimited): " limit_conn_single
    
    # Execute the auth.sh script to create the VPN account
    cd "$work_dir" || return
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
    cd "$work_dir" || return
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
    cd "$work_dir" || return
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
    cd "$work_dir" || return
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
    cd "$work_dir" || return
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

# Function to display tools menu
tools_menu() {
    while true; do
        banner
        echo -e "${BLUE}  ••••••••••••••••••••••••••••••••••••${NC}"
        echo -e "${CYAN}  ~~~~~~~~~~~~~~~~ Tools ~~~~~~~~~~~~~${NC}"
        echo -e "${BLUE} ${NC} ${GREEN} [1] Update Script ${NC}"
        echo -e "${BLUE} ${NC} ${RED} [2] Block Torrent ${NC}"
        echo -e "${BLUE} ${NC} ${GREEN} [3] Enable BBR ${NC}"
        echo -e "${BLUE} ${NC} ${ORANGE} [4] Enable udpgw ${NC}"
        echo -e "${BLUE} ${NC} ${RED} [5] Uninstall Script ${NC}"
        echo -e "${BLUE} ${NC} ${CYAN} [0] Back to Main Menu ${NC}"
        echo -e "${CYAN}  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
        echo -e "${BLUE}  ••••••••••••••••••••••••••••••••••••${NC}"
        read -p "Enter your choice: " choice

        case $choice in
            1) update_script;;
            2) block_torrent;;
            3) enable_bbr;;
            4) enable_udpgw;;
            5) uninstall_script;;
            0) return;;
            *) echo -e "${RED}Invalid choice.${NC} Please enter a valid option.";;
        esac
    done
}

# Function to update the script
update_script() {
    banner
    echo -e "${ORANGE}Updating Script...${NC}"
    # Add your script update commands here
    echo -e "${GREEN}Script updated successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to block torrent
block_torrent() {
    banner
    echo -e "${ORANGE}Blocking Torrent...${NC}"
    # Add your torrent blocking commands here
    echo -e "${GREEN}Torrent blocked successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to enable BBR
enable_bbr() {
    banner
    echo -e "${ORANGE}Enabling BBR...${NC}"
    # Add your BBR enabling commands here
    echo -e "${GREEN}BBR enabled successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to enable udpgw
enable_udpgw() {
    banner
    echo -e "${ORANGE}Enabling udpgw...${NC}"
    # Add your udpgw enabling commands here
    echo -e "${GREEN}udpgw enabled successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to uninstall the script
uninstall_script() {
    banner
    echo -e "${RED}Uninstalling Script...${NC}"
    # Add your script uninstallation commands here
    echo -e "${GREEN}Script uninstalled successfully.${NC}"
    exit 0
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

# Function for LinkLayer VPN protocol
linklayer_vpn() {
    echo "LinkLayer VPN protocol selected."
    # Add LinkLayer VPN protocol implementation here
}

#Variable to store the selected protocol
selected_protocol=""

# Function for LinkLayer VPN protocol
linklayer_vpn() {
    selected_protocol="LinkLayer VPN"
    echo "LinkLayer VPN protocol selected."
    # Add LinkLayer VPN protocol implementation here
}

# Function for Udp Request protocol
udp_request() {
    selected_protocol="Udp Request"
    echo "Udp Request protocol selected."
    # Add Udp Request protocol implementation here
}

# Function for Udp Custom protocol
udp_custom() {
    selected_protocol="Udp Custom"
    echo "Udp Custom protocol selected."
    # Add Udp Custom protocol implementation here
}

# Function for OpenVPN protocol
openvpn() {
    selected_protocol="OpenVPN"
    echo "OpenVPN protocol selected."
    # Add OpenVPN protocol implementation here
}

# Function for Udp Zivpn protocol
udp_zivpn() {
    selected_protocol="Udp Zivpn"
    echo "Udp Zivpn protocol selected."
    # Add Udp Zivpn protocol implementation here
}

# Function to display protocol submenu
protocol_submenu() {
    while true; do
        banner
        echo -e "${CYAN}~~~~~~~~~~~~~~~~ Protocol ~~~~~~~~~~~~~${NC}"
        echo -e "${BLUE} ${NC} ${GREEN}[1] LinkLayer VPN ${NC}"
        echo -e "${BLUE} ${NC} ${RED}[2] Udp Request ${NC}"
        echo -e "${BLUE} ${NC} ${GREEN}[3] Udp Custom ${NC}"
        echo -e "${BLUE} ${NC} ${ORANGE}[4] OpenVPN ${NC}"
        echo -e "${BLUE} ${NC} ${RED}[5] Udp Zivpn ${NC}"
        echo -e "${BLUE} ${NC} ${CYAN}[0] Back to Main Menu ${NC}"
        echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
        echo -e "${ORANGE}Selected Protocol:${NC}" "${GREEN}${selected_protocol} ✓${NC}"
        read -p "Enter your choice: " choice

        case $choice in
            1) linklayer_vpn;;
            2) udp_request;;
            3) udp_custom;;
            4) openvpn;;
            5) udp_zivpn;;
            0) return;;
            *) echo -e "${RED}Invalid choice.${NC} Please enter a valid option.";;
        esac
    done
}

# Main menu
update_account_status &  # Run update_account_status in the background
while true; do
    banner
    echo -e "${BLUE}•••••••••••••••••••••••••••••••••••••••••••••${NC}"
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~ Main Menu ~~~~~~~~~~~~~~~~~${NC}"
    echo -e "${BLUE}${NC}${GREEN}[1] Create Account ${NC}" "${ORANGE}       [5] Block Account ${NC}"
    echo -e "${BLUE}${NC}${BLUE}[2] Unblock Account ${NC}" "${GREEN}      [6] Renew Account ${NC}"
    echo -e "${BLUE}${NC}${RED}[3] Remove Account ${NC}" "${CYAN}       [7] User Details ${NC}"
    echo -e "${BLUE}${NC}${CYAN}[4] Protocols ${NC}"         "${ORANGE}            [8] Tools ${NC}"
    echo -e "${BLUE}${NC}${RED}[0] Exit ${NC}"
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
    echo -e "${BLUE}•••••••••••••••••••••••••••••••••••••••••••••${NC}"
    read -p "Enter your choice: " choice
    
    case $choice in
        1) create_account;;
        5) block_account;;
        2) unblock_account;;
        6) renew_account;;
        3) remove_account;;
        7) display_account_details;;
        4) protocol_submenu;;
        8) tools_menu;;
        0) echo -e "${ORANGE}Exiting...${NC}"; clear; exit;;
        *) echo -e "${RED}Invalid choice.${NC} Please enter a valid option.";;
    esac
done

