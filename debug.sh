#!/bin/bash

log_file="/var/log/installer.log"

# Function to log messages
log() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root."
        exit 1
    fi
}

# Function to ask for full disk encryption
ask_full_disk_encryption() {
    read -p "Do you want to enable full disk encryption? (y/n): " encryption_choice
    echo "$encryption_choice"
}

# Function to validate device path
validate_device_path() {
    local dev_path=$1

    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    if [[ ! -b "$dev_path" ]]; then
        log "Invalid device path: $dev_path"
        echo "Invalid device path. Please provide a valid SSD device path."
        exit 1
    fi

    echo "$dev_path"
}

# Function to identify the installation disk
identify_installation_disk() {
    log "Identifying installation disk"
    read -erp "Enter the device you want to install to [e.g., sda, nvme0n1]: " dev_path

    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    echo "Debug: Installation device path is $dev_path"
    echo "[!] You have selected $dev_path for installation. Please make sure this is the correct drive."
    
    read -p "Are you sure you want to install on $dev_path? This will erase all data on the drive. (y/n): " confirm_choice
    [ "$confirm_choice" != "y" ] && { log "Installation disk selection canceled by user"; echo "Installation disk selection canceled."; exit 1; }

    echo "$dev_path"
}

# Function to securely wipe the disk
securely_wipe_disk() {
    local dev_path=$1
    log "Securely wiping the disk initiated"
    echo -e "${GREEN}[*] Securely wiping the disk...${RESET}"

    if ! nvme id-ctrl "$dev_path" &>/dev/null; then
        log "Device $dev_path is not an NVMe drive, skipping secure erase"
        return
    fi

    if [[ $(nvme id-ctrl "$dev_path" -o json | jq -r '.vid') == "0x80ee" ]]; then
        log "Skipping secure erase operations for virtual NVMe drive"
        echo "Skipping secure erase operations for virtual NVMe drive."
        return
    fi

    log "Performing Secure Erase on $dev_path"
    echo -e "${GREEN}[!] Performing Secure Erase on $dev_path...${RESET}"
    if ! nvme format "$dev_path" --ses=1; then
        log "Failed to securely wipe the disk $dev_path"
        echo "Failed to securely wipe the disk. Please check your system configuration and try again."
        exit 1
    fi

    log "Securely wiped $dev_path successfully"
    echo -e "${GREEN}[*] Securely wiped $dev_path successfully.${RESET}"
}

# Function to partition and encrypt the disk
partition_and_encrypt() {
    local dev_path=$1
    local encryption_choice=$2

    dev_path=$(validate_device_path "$dev_path")
    log "Partitioning and setting up the SSD"
    echo -e "${GREEN}[*] Creating boot partition...${RESET}"

    echo "Debug: Before parted, dev_path = $dev_path"
    parted --script "$dev_path" mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 boot on mkpart primary 512MiB 100%
    echo "Debug: After parted, dev_path = $dev_path"

    mkfs.fat -F32 "${dev_path}p1"
    echo "Debug: After mkfs, dev_path = $dev_path"

    if [ "$encryption_choice" == "y" ]; then
        log "Prompting for encryption password for LUKS container"
        echo -e "${GREEN}[*] Creating LUKS container on ${dev_path}p2...${RESET}"
        cryptsetup luksFormat --type luks2 --hash sha512 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 --sector-size 4096 "${dev_path}p2"
        
        echo "Debug: After LUKS format, dev_path = $dev_path"
        cryptsetup open --type luks "${dev_path}p2" cryptroot
        echo "Debug: After LUKS open, dev_path = $dev_path"
        cryptsetup status cryptroot
    fi
}

# Function to fill encrypted partition with random data
fill_encrypted_partition_with_random_data() {
    log "Filling encrypted partition with random data initiated"
    echo -e "${GREEN}[*] Filling encrypted partition with random data...${RESET}"

    if ! dd if=/dev/urandom of=/dev/mapper/cryptroot bs=10M status=progress; then
        log "Failed to fill encrypted partition with random data"
        echo "Failed to fill encrypted partition with random data. Please check your system configuration."
        exit 1
    fi

    log "Encrypted partition filled with random data successfully"
    echo -e "${GREEN}[*] Encrypted partition filled with random data successfully.${RESET}"
}

# Function to create LVM
createLVM2() {
    local dev_path=$1
    local encryption_choice=$2

    dev_path=$(validate_device_path "$dev_path")
    local vg_name="lvmcrypt"
    local pv_path="/dev/mapper/cryptroot"

    if [ "$encryption_choice" != "y" ]; then
        vg_name="lvmplain"
        pv_path="${dev_path}p2"
    fi

    log "Configuring LVM"
    echo -e "${GREEN}[*] Configuring LVM...${RESET}"

    pvcreate "$pv_path"
    vgcreate "$vg_name" "$pv_path"
    lvcreate -L 20G -n lv_root "$vg_name"
    lvcreate -l 100%FREE -n lv_home "$vg_name"
    lvresize -l -100%FREE "/dev/$vg_name/lv_home"
    lvcreate -L 20G -n lv_usr "$vg_name"
    lvcreate -L 10G -n lv_var "$vg_name"
    lvcreate -L 4G -n lv_varlog "$vg_name"
    lvcreate -L 2G -n lv_varlogaudit "$vg_name"
    lvcreate -L 4G -n lv_tmp "$vg_name"
    lvcreate -L 4G -n lv_vartmp "$vg_name"
    lvcreate -L 8G -n lv_swap "$vg_name"
    lvresize -l 100%FREE "/dev/$vg_name/lv_home"
}

# Function to format partitions
formatPartitions() {
    local encryption_choice=$1

    log "Formatting partitions to Btrfs filesystem"
    echo -e "${GREEN}[*] Formatting partitions to Btrfs filesystem...${RESET}"

    local vg_name="lvmcrypt"
    [ "$encryption_choice" != "y" ] && vg_name="lvmplain"

    mkfs.btrfs "/dev/${vg_name}/lv_root"
    mkfs.btrfs "/dev/${vg_name}/lv_home"
    mkfs.btrfs "/dev/${vg_name}/lv_usr"
    mkfs.btrfs "/dev/${vg_name}/lv_var"
    mkfs.btrfs "/dev/${vg_name}/lv_varlog"
    mkfs.btrfs "/dev/${vg_name}/lv_varlogaudit"
    mkfs.btrfs "/dev/${vg_name}/lv_tmp"
    mkfs.btrfs "/dev/${vg_name}/lv_vartmp"
    mkswap "/dev/${vg_name}/lv_swap"
}

# Function to mount filesystems
mountFilesystems() {
    local dev_path=$1
    local encryption_choice=$2

    dev_path=$(validate_device_path "$dev_path")
    log "Mounting filesystems"
    echo -e "${GREEN}[*] Installing the base system...${RESET}"

    local vg_name="lvmcrypt"
    [ "$encryption_choice" != "y" ] && vg_name="lvmplain"

    mount -o noatime,compress=zstd,autodefrag "/dev/${vg_name}/lv_root" /mnt
    mkdir -p /mnt/home /mnt/usr /mnt/var /mnt/var/log /mnt/var/log/audit /mnt/tmp /mnt/var/tmp
    mount -o noatime,compress=zstd,autodefrag "/dev/${vg_name}/lv_home" /mnt/home
    mount -o noatime,compress=zstd,autodefrag "/dev/${vg_name}/lv_usr" /mnt/usr
    mount -o noatime,compress=zstd,autodefrag "/dev/${vg_name}/lv_var" /mnt/var
        mount -o noatime "/dev/${vg_name}/lv_varlog" /mnt/var/log
    mount -o noatime "/dev/${vg_name}/lv_varlogaudit" /mnt/var/log/audit
    mount -o noatime "/dev/${vg_name}/lv_tmp" /mnt/tmp
    mount -o noatime "/dev/${vg_name}/lv_vartmp" /mnt/var/tmp
    swapon "/dev/${vg_name}/lv_swap"
    mkdir -p /mnt/boot
    mount "${dev_path}p1" /mnt/boot
}

# Function to add mount options to /etc/fstab
add_mount_options_to_fstab() {
    local dev_path=$1
    local encryption_choice=$2

    log "Adding mount options to /etc/fstab"
    echo -e "${GREEN}[*] Adding mount options to /etc/fstab...${RESET}"

    # Generate fstab
    genfstab -U /mnt > /mnt/etc/fstab

    # Function to update fstab with desired mount options
    update_fstab_entry() {
        local device="$1"
        local mount_point="$2"
        local options="$3"
        
        uuid=$(blkid -s UUID -o value "$device")

        # Escape forward slashes for sed
        uuid_escaped=$(echo "$uuid" | sed 's/\//\\\//g')
        mount_point_escaped=$(echo "$mount_point" | sed 's/\//\\\//g')

        # Update fstab entry with mount options
        sed -i "s|^UUID=$uuid_escaped\s\+$mount_point_escaped\s\+\w\+\s\+\w\+|UUID=$uuid_escaped $mount_point btrfs $options|" /mnt/etc/fstab
    }

    local vg_name="lvmcrypt"
    [ "$encryption_choice" != "y" ] && vg_name="lvmplain"

    declare -A mount_points_options=(
        ["/dev/${vg_name}/lv_root"]="/mnt noatime,compress=zstd,autodefrag"
        ["/dev/${vg_name}/lv_home"]="/mnt/home noatime,compress=zstd,autodefrag"
        ["/dev/${vg_name}/lv_usr"]="/mnt/usr noatime,compress=zstd,autodefrag"
        ["/dev/${vg_name}/lv_var"]="/mnt/var noatime,compress=zstd,autodefrag"
        ["/dev/${vg_name}/lv_varlog"]="/mnt/var/log noatime"
        ["/dev/${vg_name}/lv_varlogaudit"]="/mnt/var/log/audit noatime"
        ["/dev/${vg_name}/lv_tmp"]="/mnt/tmp noatime"
        ["/dev/${vg_name}/lv_vartmp"]="/mnt/var/tmp noatime"
        ["${dev_path}p1"]="/mnt/boot noatime"
    )

    if [ -e /mnt/etc/systemd/system/zramswap.service ]; then
        log "ZRAM is enabled, no swap entry in fstab"
    else
        mount_points_options["/dev/${vg_name}/lv_swap"]="none swap sw 0 0"
        log "Traditional swap is being used, adding swap entry to fstab"
    fi

    for device in "${!mount_points_options[@]}"; do
        mount_point="${mount_points_options[$device]%% *}"
        options="${mount_points_options[$device]#* }"
        update_fstab_entry "$device" "$mount_point" "$options"
    done

    log "Mount options added to /etc/fstab successfully"
    echo -e "${GREEN}[*] Mount options added to /etc/fstab successfully.${RESET}"
}

# Function to install the bootloader
install_bootloader() {
    local dev_path=$1
    local encryption_choice=$2

    log "Installing bootloader"
    echo -e "${GREEN}[*] Installing bootloader...${RESET}"

    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm

    if [ "$encryption_choice" == "y" ]; then
        luks_partition_uuid=$(blkid -s UUID -o value "${dev_path}p2")
        arch-chroot /mnt bash -c "echo 'GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$luks_partition_uuid:cryptroot root=/dev/mapper/lv_root\"' >> /etc/default/grub"
    else
        root_partition_uuid=$(blkid -s UUID -o value "${dev_path}p2")
        arch-chroot /mnt bash -c "echo 'GRUB_CMDLINE_LINUX=\"root=UUID=$root_partition_uuid\"' >> /etc/default/grub"
    fi

    execute_command "arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB" "install GRUB"
    execute_command "arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg" "generate GRUB configuration"
}

# Additional configuration functions
set_root_password() {
    log "Setting root password"
    arch-chroot /mnt passwd
}

ask_username() {
    read -p "Enter your username: " username
    echo "$username"
}

set_user_info() {
    local username=$1

    log "Creating user $username"
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    arch-chroot /mnt passwd "$username"
}

install_software() {
    log "Installing additional software"
    arch-chroot /mnt pacman -S --noconfirm base-devel linux linux-headers linux-firmware
}

install_blackarch() {
    log "Installing BlackArch tools"
    arch-chroot /mnt curl -O https://blackarch.org/strap.sh
    arch-chroot /mnt chmod +x strap.sh
    arch-chroot /mnt ./strap.sh
    arch-chroot /mnt pacman -Syyu --noconfirm blackarch
}

install_graphics_driver() {
    log "Installing graphics driver"
    arch-chroot /mnt pacman -S --noconfirm xf86-video-intel
}

generate_initramfs() {
    log "Generating initramfs"
    arch-chroot /mnt mkinitcpio -P
}

create_crypttab_entry() {
    local dev_path=$1

    log "Creating crypttab entry"
    luks_partition_uuid=$(blkid -s UUID -o value "${dev_path}p2")
    echo "cryptroot UUID=$luks_partition_uuid none luks" >> /mnt/etc/crypttab
}

verify_files() {
    log "Verifying installed files"
    arch-chroot /mnt pacman -Qk
}

configure_networking() {
    log "Configuring networking"
    arch-chroot /mnt systemctl enable NetworkManager
}

safely_unmount_devices() {
    log "Safely unmounting all devices"
    umount -R /mnt
    swapoff -a
}

# Main function
main() {
    log "Script started"

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
    
    # The installer step (assuming the user adds their installer commands here)
    installer
    
    # The configure dynamic zram step (assuming the user adds their zram configuration here)
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
        create_crypttab_entry "$dev_path"
    fi

    install_bootloader "$dev_path" "$encryption_choice"
    verify_files
    configure_networking
    safely_unmount_devices

    log "Script completed"
}

main
