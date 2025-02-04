# Function to validate device path
validate_device_path() {
    local dev_path=$1

    # Check if the path includes /dev/
    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    # Debug: Print the corrected device path
    echo "Corrected device path: $dev_path"

    # Validate device path
    if [[ ! -b "$dev_path" ]]; then
        log "Invalid device path: $dev_path"
        echo "Invalid device path. Please provide a valid SSD device path."
        exit 1
    fi

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
        # Create LUKS container and open it
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

    # Prompt user to identify the installation disk
    read -erp "Enter the device path you want to install to [e.g., /dev/sda, /dev/nvme0n1]: " dev_path

    encryption_choice="y" # or prompt user for encryption choice

    # Debug: Print initial values
    echo "Debug: Initial dev_path is $dev_path"
    echo "Debug: Initial encryption_choice is $encryption_choice"

    partition_and_encrypt "$dev_path" "$encryption_choice"

    log "Script completed"
}

main
