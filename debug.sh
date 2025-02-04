log_file="/var/log/installer.log"
log() {
    if [[ ! -d "/var/log" ]]; then
        mkdir -p "/var/log"
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

identify_installation_disk() {
    log "Identifying installation disk"
    # Prompt user to identify the installation disk
    read -erp "Enter the device you want to install to [e.g., sda, nvme0n1]: " dev_path

    # Ensure the device path includes /dev/
    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    # Debug: Print the device path
    echo "Debug: Installation device path is $dev_path"

    # Display selected device information with partitions
    echo "[!] You have selected $dev_path for installation. Please make sure this is the correct drive."
    
    # Confirm user's choice
    read -p "Are you sure you want to install on $dev_path? This will erase all data on the drive. (y/n): " confirm_choice
    [ "$confirm_choice" != "y" ] && { log "Installation disk selection canceled by user"; echo "Installation disk selection canceled."; exit 1; }

    echo "$dev_path"
}
partition_and_encrypt() {
    dev_path=$(validate_device_path "$1")
    encryption_choice=$2

    log "Partitioning and setting up the SSD"
    echo -e "${GREEN}[*] Creating boot partition...${RESET}"

    # Debug: Print dev_path and encryption_choice
    echo "Debug: dev_path is $dev_path"
    echo "Debug: encryption_choice is $encryption_choice"

    # Create partitions and format ESP
    execute_command "parted --script $dev_path mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 boot on mkpart primary 512MiB 100%" "create partitions on $dev_path"
    execute_command "mkfs.fat -F32 ${dev_path}p1" "format the ESP partition"

    if [ "$encryption_choice" == "y" ]; then
        log "Prompting for encryption password for LUKS container"
        echo -e "${GREEN}[*] Creating LUKS container on ${dev_path}p2...${RESET}"
        cryptsetup luksFormat --type luks2 --hash sha512 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 --sector-size 4096 "${dev_path}p2"

        echo -e "${GREEN}[*] Opening LUKS container on ${dev_path}p2 as cryptroot...${RESET}"
        cryptsetup open --type luks "${dev_path}p2" cryptroot

        # Verify device mapping for encryption
        execute_command "cryptsetup status cryptroot" "verify the device mapping for encryption"
    fi
}
main() {
    log "Script started"

    dev_path=$(identify_installation_disk)
    encryption_choice="y" # or prompt user for encryption choice

    echo "Debug: dev_path before partition_and_encrypt is $dev_path"

    securely_wipe_disk "$dev_path"
    partition_and_encrypt "$dev_path" "$encryption_choice"

    log "Script completed"
}

main
