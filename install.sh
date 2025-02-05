#!/bin/bash

# Colors for messages
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RESET='\033[0m'

# Declare global variables
declare -g root_password
declare -g user_password
declare -g username
declare -g dev_path

# Function to check if script is running as root
check_root() {
    [[ $EUID -ne 0 ]] && echo "Please run the script as root." && exit 1
}

# Greeting function
greet() {
    echo -e "${PURPLE}hArch Installer - OniSec Remix\n"
    echo "
    ██╗░░██╗░█████╗░░█████╗░██╗░░██╗███████╗██████╗░░██████╗██╗
    ██║░░██║██╔══██╗██╔══██╗██║░██╔╝██╔════╝██╔══██╗██╔════╝╚█║
    ███████║███████║██║░░╚═╝█████═╝░█████╗░░██████╔╝╚█████╗░░╚╝
    ██╔══██║██╔══██║██║░░██╗██╔═██╗░██╔══╝░░██╔══██╗░╚═══██╗░░░
    ██║░░██║██║░░██║╚█████╔╝██║░╚██╗███████╗██║░░██║██████╔╝░░░
    ╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═════╝░░░░

    ░█████╗░██████╗░░█████╗░██╗░░██╗░░██╗░░░░░██╗███╗░░██╗██╗░░░██╗██╗░░██╗
    ██╔══██╗██╔══██╗██╔══██╗██║░░██║░░██║░░░░░██║████╗░██║██║░░░██║╚██╗██╔╝
    ███████║██████╔╝██║░░╚═╝███████║░░██║░░░░░██║██╔██╗██║██║░░░██║░╚███╔╝░
    ██╔══██║██╔══██╗██║░░██╗██╔══██║░░██║░░░░░██║██║╚████║██║░░░██║░██╔██╗░
    ██║░░██║██║░░██║╚█████╔╝██║░░██║░░███████╗██║██║░╚███║╚██████╔╝██╔╝╚██╗
    ╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝░░╚══════╝╚═╝╚═╝░░╚══╝░╚═════╝░╚═╝░░╚═╝
    "
    echo -e "${RESET}\n\n"
}

# Function to ask for full disk encryption
ask_full_disk_encryption() {
    while true; do
        read -rp "Do you want to enable full disk encryption? (y/n): " encryption_choice
        case $encryption_choice in
            [Yy]* ) echo "y"; return ;;
            [Nn]* ) echo "n"; return ;;
            * ) echo "Please answer y or n." ;;
        esac
    done
}

# Function to ask for the root password
ask_root_password() {
    echo -e "${GREEN}[*] Setting the root password...${RESET}"
    while true; do
        password1=$(systemd-ask-password "Enter the root password: ")
        password2=$(systemd-ask-password "Re-enter the root password: ")
        if [[ "$password1" == "$password2" ]]; then
            root_password="$password1"
            break
        fi
        echo "Passwords do not match. Please try again."
    done
}

# Function to ask for the user password
ask_user_password() {
    echo -e "${GREEN}[*] Setting the user password...${RESET}"
    while true; do
        password1=$(systemd-ask-password "Enter the user password: ")
        password2=$(systemd-ask-password "Re-enter the user password: ")
        if [[ "$password1" == "$password2" ]]; then
            user_password="$password1"
            break
        fi
        echo "Passwords do not match. Please try again."
    done
}

# Function to execute a command and handle errors
execute_command() {
    local cmd="$1"
    local desc="$2"
    echo -e "${GREEN}[*] $desc...${RESET}"
    
    if eval "$cmd"; then
        echo -e "${GREEN}[*] Completed: $desc${RESET}"
    else
        echo -e "${RED}[!] Failed: $desc. Please check your system configuration.${RESET}"
        read -rp "Press 'e' to exit or any other key to continue: " choice
        if [[ "$choice" == "e" ]]; then
            exit 1
        fi
    fi
}

# Function to validate device path
validate_device_path() {
    local dev_path=$1

    # Ensure the device path includes /dev/
    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    # Validate device path
    if [[ ! -b "$dev_path" ]]; then
        echo "Invalid device path. Please provide a valid SSD device path."
        exit 1
    fi

    echo "$dev_path"
}

# Function to identify the installation disk
identify_installation_disk() {
    # Prompt user to identify the installation disk
    read -erp "Enter the device you want to install to [e.g., sda, nvme0n1]: " dev_path

    # Ensure the device path includes /dev/
    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    # Display selected device information with partitions
    echo "[!] You have selected $dev_path for installation. Please make sure this is the correct drive."
    
    # Confirm user's choice
    read -p "Are you sure you want to install on $dev_path? This will erase all data on the drive. (y/n): " confirm_choice
    [ "$confirm_choice" != "y" ] && echo "Installation disk selection canceled." && exit 1

    echo "$dev_path"
}

# Function to securely wipe the disk
securely_wipe_disk() {
    dev_path=$(validate_device_path "$1")
    echo -e "${GREEN}[*] Securely wiping the disk...${RESET}"

    # Check if the device is an NVMe drive
    if ! nvme id-ctrl "$dev_path" &>/dev/null; then
        echo "Device $dev_path is not an NVMe drive, skipping secure erase"
        return
    fi

    # Check if the device is a virtual NVMe drive
    if [[ $(nvme id-ctrl "$dev_path" -o json | jq -r '.vid') == "0x80ee" ]]; then
        echo "Skipping secure erase operations for virtual NVMe drive."
        return
    fi

    # Perform Secure Erase
    echo -e "${GREEN}[!] Performing Secure Erase on $dev_path...${RESET}"
    if ! nvme format "$dev_path" --ses=1; then
        echo "Failed to securely wipe the disk. Please check your system configuration and try again."
        exit 1
    fi

    echo -e "${GREEN}[*] Securely wiped $dev_path successfully.${RESET}"
}

# Function to partition and encrypt the disk
partition_and_encryptpartition_and_encrypt() {
    dev_path=$(validate_device_path "$1")
    encryption_choice=$2

    echo -e "${GREEN}[*] Creating boot partition...${RESET}"

    # Create partitions and format ESP
    execute_command "parted --script $dev_path mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 boot on mkpart primary 512MiB 100%" "create partitions on $dev_path"
    execute_command "mkfs.fat -F32 ${dev_path}p1" "format the ESP partition"

    if [ "$encryption_choice" == "y" ]; then
        echo -e "${GREEN}[*] Creating LUKS container on ${dev_path}p2...${RESET}"
        cryptsetup luksFormat --type luks2 --hash sha512 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 --sector-size 4096 "${dev_path}p2"

        echo -e "${GREEN}[*] Opening LUKS container on ${dev_path}p2 as cryptroot...${RESET}"
        cryptsetup open --type luks "${dev_path}p2" cryptroot

        # Verify device mapping for encryption
        execute_command "cryptsetup status cryptroot" "verify the device mapping for encryption"
    fi
}

# Function to create crypttab entry
create_crypttab_entry() {
    echo -e "${GREEN}[*] Creating crypttab entry...${RESET}"
    luks_partition_uuid=$(blkid -s UUID -o value "${dev_path}p2")
    echo "cryptroot UUID=$luks_partition_uuid none luks" >> /mnt/etc/crypttab
}

# Function to verify files
verify_files() {
    echo -e "${GREEN}[*] Verifying installed files...${RESET}"
    arch-chroot /mnt pacman -Qk
}

# Function to configure networking
configure_networking() {
    echo -e "${GREEN}[*] Configuring networking...${RESET}"
    arch-chroot /mnt systemctl enable NetworkManager
}

# Function to safely unmount devices
safely_unmount_devices() {
    echo -e "${GREEN}[*] Safely unmounting devices...${RESET}"
    umount -R /mnt
    swapoff -a
}

# Main function
main() {
    greet
    check_root
    encryption_choice=$(ask_full_disk_encryption)
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL | grep -E 'disk|part'
    dev_path=$(identify_installation_disk)

    if [ "$encryption_choice" == "y" ]; then
        securely_wipe_disk "$dev_path"
    fi

    partition_and_encrypt "$dev_path" "$encryption_choice"

    if [ "$encryption_choice" == "y" ]; then
        read -rp "Do you want to fill the disk with random data before creating logical volumes? (y/n): " fill_choice
        if [ "$fill_choice" == "y" ]; then
            fill_encrypted_partition_with_random_data
        fi
    fi

    createLVM2 "$dev_path" "$encryption_choice"
    formatPartitions "$encryption_choice"
    mountFilesystems "$dev_path" "$encryption_choice"
    installer
    configure_dynamic_zram "$encryption_choice"
    add_mount_options_to_fstab "$dev_path" "$encryption_choice"
    set_root_password
    username=$(ask_username)
    set_user_info "$username"
    install_software
    install_blackarch
    install_graphics_driver
    generate_initramfs

    if [ "$encryption_choice" == "y" ]; then
        create_crypttab_entry
    fi

    install_bootloader "$dev_path" "$encryption_choice"
    verify_files
    configure_networking
    safely_unmount_devices

    echo -e "${GREEN}[*] Installation completed successfully!${RESET}"
}

main
