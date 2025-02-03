#!/usr/bin/env bash

log_file="/var/log/installer.log"
log() {
    if [[ ! -d "/var/log" ]]; then
        mkdir -p "/var/log"
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RESET='\033[0m'

declare -g encryption_password  # Declare encryption_password as a global variable
declare -g root_password  # Declare root_password as a global variable
declare -g user_password  # Declare user_password as a global variable
declare -g username  # Declare username as a global variable

# Function to check if script is running as root
check_root() {
    log "Checking if running as root"
    [[ $EUID -ne 0 ]] && log "Not running as root. Exiting." && echo "Please run the script as root." && exit 1
}

greet() {
    log "Displaying greeting"
    echo -e "${PURPLE}hArch Installer - OniSec Remix\n"
    echo "
    ██╗░░██╗░█████╗░░█████╗░██╗░░██╗███████╗██████╗░░██████╗██╗
    ██║░░██║██╔══██╗██╔══██╗██║░██╔╝██╔════╝██╔══██╗██╔════╝╚█║
    ███████║███████║██║░░╚═╝█████═╝░█████╗░░██████╔╝╚█████╗░░╚╝
    ██╔══██║██╔══██║██║░░██╗██╔═██╗░██╔══╝░░██╔══██╗░╚═══██╗░░░
    ██║░░██║██║░░██║╚█████╔╝██║░╚██╗███████╗██║░░██║██████╔╝░░░
    ╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═════╝░░░░

    ░█████╗░██████╗░░█████╗░██╗░░██╗  ██╗░░░░░██╗███╗░░██╗██╗░░░██╗██╗░░██╗
    ██╔══██╗██╔══██╗██╔══██╗██║░░██║  ██║░░░░░██║████╗░██║██║░░░██║╚██╗██╔╝
    ███████║██████╔╝██║░░╚═╝███████║  ██║░░░░░██║██╔██╗██║██║░░░██║░╚███╔╝░
    ██╔══██║██╔══██╗██║░░██╗██╔══██║  ██║░░░░░██║██║╚████║██║░░░██║░██╔██╗░
    ██║░░██║██║░░██║╚█████╔╝██║░░██║  ███████╗██║██║░╚███║╚██████╔╝██╔╝╚██╗
    ╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝  ╚══════╝╚═╝╚═╝░░╚══╝░╚═════╝░╚═╝░░╚═╝
    "
    echo -e "${RESET}\n\n"
}

# Function to ask for the encryption password
deprecated_ask_encryption_password() {
    log "Prompting for encryption password"
    echo -e "${GREEN}[*] Setting the encryption password...${RESET}"
    while true; do
        password1=$(systemd-ask-password "Enter the encryption password: ")
        password2=$(systemd-ask-password "Re-enter the encryption password: ")
        if [[ "$password1" == "$password2" ]]; then
            encryption_password="$password1"
            log "Encryption passwords match"
            break
        fi
        log "Encryption passwords do not match"
        echo "Passwords do not match. Please try again."
    done
}

# Function to ask for the root password
ask_root_password() {
    log "Prompting for root password"
    echo -e "${GREEN}[*] Setting the root password...${RESET}"
    while true; do
        password1=$(systemd-ask-password "Enter the root password: ")
        password2=$(systemd-ask-password "Re-enter the root password: ")
        if [[ "$password1" == "$password2" ]]; then
            root_password="$password1"
            log "Root passwords match"
            break
        fi
        log "Root passwords do not match"
        echo "Passwords do not match. Please try again."
    done
}

ask_user_password() {
    log "Prompting for user password"
    echo -e "${GREEN}[*] Setting the user password...${RESET}"
    while true; do
        password1=$(systemd-ask-password "Enter the user password: ")
        password2=$(systemd-ask-password "Re-enter the user password: ")
        if [[ "$password1" == "$password2" ]]; then
            user_password="$password1"
            log "User passwords match"
            break
        fi
        log "User passwords do not match"
        echo "Passwords do not match. Please try again."
    done
}

# Function to execute a command and handle errors
execute_command() {
    local cmd="$1"
    local desc="$2"
    log "Starting: $desc"
    echo -e "${GREEN}[*] $desc...${RESET}"
    eval "$cmd" && log "Completed: $desc" || {
        log "Failed: $desc"
        echo "Failed to $desc. Please check your system configuration."
        read -rp "Press 'e' to exit or any other key to continue: " choice
        [[ "$choice" == "e" ]] && exit 1
    }
}

securely_wipe_disk() {
    log "Securely wiping the disk initiated"
    echo -e "${GREEN}[*] Securely wiping the disk...${RESET}"

    # Ask if the user wants to securely erase their drive
    read -p "Do you want to securely erase your drive? (y/n): " erase_choice
    [ "$erase_choice" != "y" ] && { log "Secure erase skipped by user"; echo "Skipping secure erase."; return; }

    read -p "Enter the SSD device path to securely wipe [Example: /dev/nvme0n1]: " dev_path

    if [[ ! -b "$dev_path" ]]; then
        log "Invalid device path: $dev_path"
        echo "Invalid device path. Please provide a valid SSD device path."
        exit 1
    fi

    # Check if the device is an NVMe drive
    nvme id-ctrl "$dev_path" &>/dev/null || { log "Device $dev_path is not an NVMe drive"; echo "Device $dev_path is not an NVMe drive."; exit 1; }

    # Check if the device is a virtual NVMe drive
    [[ $(nvme id-ctrl "$dev_path" -o json | jq -r '.vid') == "0x80ee" ]] && { log "Skipping secure erase operations for virtual NVMe drive"; echo "Skipping secure erase operations for virtual NVMe drive."; return; }

    # Perform Secure Erase
    log "Performing Secure Erase on $dev_path"
    echo -e "${GREEN}[!] Performing Secure Erase on $dev_path...${RESET}"
    nvme format "$dev_path" --ses=1 || { log "Failed to securely wipe the disk $dev_path"; echo "Failed to securely wipe the disk. Please check your system configuration and try again."; exit 1; }

    log "Securely wiped $dev_path successfully"
    echo -e "${GREEN}[*] Securely wiped $dev_path successfully.${RESET}"
}

partition_and_encrypt() {
    log "Partitioning and encrypting the SSD"
    echo -e "${GREEN}[*] Creating boot partition and LVM2 layout...${RESET}"
    lsblk

    # Prompt for SSD device path
    read -erp "Enter your SSD device path [Default: /dev/nvme3n1]: " dev_path
    dev_path=${dev_path:-/dev/nvme3n1}

    # Validate device path
    [[ ! -b "$dev_path" ]] && log "Invalid device path: $dev_path" && echo "Invalid device path. Please provide a valid SSD device path." && exit 1

    # Create partitions and format ESP
    execute_command "parted --script $dev_path mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 boot on mkpart primary 512MiB 100%" "create partitions on $dev_path"
    execute_command "mkfs.fat -F32 ${dev_path}p1" "format the ESP partition"

    # Create LUKS container and open it
    log "Prompting for encryption password for LUKS container"
    echo -e "${GREEN}[*] Creating LUKS container on ${dev_path}p2...${RESET}"
    cryptsetup luksFormat --type luks2 --hash sha512 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 --sector-size 4096 ${dev_path}p2

    echo -e "${GREEN}[*] Opening LUKS container on ${dev_path}p2 as cryptroot...${RESET}"
    cryptsetup open --type luks ${dev_path}p2 cryptroot

    # Verify device mapping for encryption
    execute_command "cryptsetup status cryptroot" "verify the device mapping for encryption"
}

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

createLVM2() {
    log "Configuring LVM on LUKS"
    echo -e "${GREEN}[*] Configuring LVM on LUKS...${RESET}"
    # Array of commands and descriptions
    cmds_and_descs=(
        "pvcreate /dev/mapper/cryptroot:create physical volume"
        "vgcreate lvmcrypt /dev/mapper/cryptroot:create volume group"
        "lvcreate -L 20G -n lv_root lvmcrypt:create root logical volume"
        "lvcreate -l 100%FREE -n lv_home lvmcrypt:create home logical volume"
        "lvresize -l -100%FREE /dev/lvmcrypt/lv_home:resize home logical volume (shrink to none)"
        "lvcreate -L 20G -n lv_usr lvmcrypt:create /usr logical volume"
        "lvcreate -L 10G -n lv_var lvmcrypt:create /var logical volume"
        "lvcreate -L 4G -n lv_varlog lvmcrypt:create /var/log logical volume"
        "lvcreate -L 2G -n lv_varlogaudit lvmcrypt:create /var/log/audit logical volume"
        "lvcreate -L 4G -n lv_tmp lvmcrypt:create /tmp logical volume"
        "lvcreate -L 4G -n lv_vartmp lvmcrypt:create /var/tmp logical volume"
        "lvcreate -L 8G -n lv_swap lvmcrypt:create swap logical volume"
        "lvresize -l 100%FREE /dev/lvmcrypt/lv_home:resize home logical volume to use remaining space"
    )

    # Iterate over the array and run commands
    for item in "${cmds_and_descs[@]}"; do
        IFS=":" read -r cmd desc <<< "$item"
        execute_command "$cmd" "$desc"
    done
}

formatPartitions() {
    log "Formatting encrypted partitions to Btrfs filesystem"
    echo -e "${GREEN}[*] Formatting encrypted partitions to Btrfs filesystem...${RESET}"

    # Arrays of commands and descriptions
    cmds_and_descs=(
        "mkfs.btrfs /dev/lvmcrypt/lv_root:format Root partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_home:format Home partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_usr:format User (/usr) partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_var:format Variable (/var) partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_varlog:format Log (/var/log) partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_varlogaudit:format Audit log (/var/log/audit) partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_tmp:format Temporary (/tmp) partition"
        "mkfs.btrfs /dev/lvmcrypt/lv_vartmp:format Temporary variable (/var/tmp) partition"
        "mkswap /dev/lvmcrypt/lv_swap:make Swap partition"
    )

    # Iterate over the array
    for item in "${cmds_and_descs[@]}"; do
        IFS=":" read -r cmd desc <<< "$item"
        execute_command "$cmd" "$desc"
    done
}

mountFilesystems() {
    log "Mounting filesystems"
    echo -e "${GREEN}[*] Installing the base system...${RESET}"

    # Array of commands and descriptions for mounting filesystems
    cmds_and_descs=(
        "mount -o noatime,compress=zstd,autodefrag /dev/lvmcrypt/lv_root /mnt:mount root filesystem"
        "mkdir -p /mnt/home /mnt/usr /mnt/var /mnt/var/log /mnt/var/log/audit /mnt/tmp /mnt/var/tmp:create mount points"
        "mount -o noatime,compress=zstd,autodefrag /dev/lvmcrypt/lv_home /mnt/home:mount home filesystem"
        "mount -o noatime,compress=zstd,autodefrag /dev/lvmcrypt/lv_usr /mnt/usr:mount /usr filesystem"
        "mount -o noatime,compress=zstd,autodefrag /dev/lvmcrypt/lv_var /mnt/var:mount /var filesystem"
        "mount -o noatime /dev/lvmcrypt/lv_varlog /mnt/var/log:mount /var/log filesystem"
        "mount -o noatime /dev/lvmcrypt/lv_varlogaudit /mnt/var/log/audit:mount /var/log/audit filesystem"
        "mount -o noatime /dev/lvmcrypt/lv_tmp /mnt/tmp:mount /tmp filesystem"
        "mount -o noatime /dev/lvmcrypt/lv_vartmp /mnt/var/tmp:mount /var/tmp filesystem"
        "swapon /dev/lvmcrypt/lv_swap:activate swap"
        "mkdir -p /mnt/boot:create boot directory"
        "mount ${dev_path}p1 /mnt/boot:mount boot filesystem"
    )

    # Iterate over the array and execute commands
    for item in "${cmds_and_descs[@]}"; do
        IFS=":" read -r cmd desc <<< "$item"
        execute_command "$cmd" "$desc"
    done
}

installer() {
    log "Installing essential packages"
    # Install essential packages
    execute_command "pacstrap /mnt base linux linux-firmware lvm2 vim intel-ucode btrfs-progs sudo dhcpcd vi iwd --noconfirm" "install essential packages"
}

configure_dynamic_zram() {
    log "Configuring dynamic ZRAM swap"
    echo -e "${GREEN}[*] Configuring dynamic ZRAM...${RESET}"
    # Explain ZRAM benefits and drawbacks
    echo -e "${YELLOW}[*] Why Enable ZRAM:${RESET}\n- Improved Performance: Faster swap operations using compressed RAM instead of disk-based swap.\n- Reduced I/O Overhead: Reduces load on disk I/O, enhancing system performance.\n- Memory Efficiency: Compresses data, allowing more effective use of RAM."
    echo -e "${RED}[*] Why Not Enable ZRAM:${RESET}\n- Sufficient RAM: If you have plenty of RAM and don't use swap often, ZRAM may not provide significant benefits.\n- System Overhead: Compression and decompression operations may introduce slight CPU overhead."

    # Prompt user to enable ZRAM
    read -p "Do you want to enable ZRAM to replace swap? (yes/no): " user_input
    [[ "$user_input" != "yes" ]] && echo -e "${RED}[*] ZRAM configuration aborted by user.${RESET}" && return

    echo -e "${GREEN}[*] Installing and configuring ZRAM...${RESET}"
    # Install zram-generator in /mnt
    pacstrap /mnt zram-generator || { echo "Error: Failed to install zram-generator." >&2; exit 1; }

    # Create ZRAM config file
    cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

    # Enable and start ZRAM service
    arch-chroot /mnt systemctl enable /usr/lib/systemd/systemd-zram-setup@zram0.service || { echo "Error: Failed to enable zram service." >&2; exit 1; }
    arch-chroot /mnt systemctl start systemd-zram-setup@zram0.service || { echo "Error: Failed to start zram service." >&2; exit 1; }
    arch-chroot /mnt swapon --show
    echo "Zram setup with zram-generator complete."

    # Create sysctl config for ZRAM optimization
    cat <<EOF > /mnt/etc/sysctl.d/99-vm-zram-parameters.conf
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
    arch-chroot /mnt sysctl --system

    # Disable/remove traditional swap, expand home LV
    swapoff /dev/lvmcrypt/lv_swap && lvremove -y /dev/lvmcrypt/lv_swap && lvextend -l +100%FREE /dev/lvmcrypt/lv_home && resize2fs /dev/lvmcrypt/lv_home || { echo "Error: Failed to adjust logical volumes." >&2; exit 1; }

    log "ZRAM configured successfully, swap removed, home LV expanded, and zramswap service created"
    echo -e "${GREEN}[*] ZRAM configured, swap removed, home LV expanded, and zramswap service created.${RESET}"
}

add_mount_options_to_fstab() {
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

    # Define mount points and options
    declare -A mount_points_options=(
        ["/dev/lvmcrypt/lv_root"]="/mnt noatime,compress=zstd,autodefrag"
        ["/dev/lvmcrypt/lv_home"]="/mnt/home noatime,compress=zstd,autodefrag"
        ["/dev/lvmcrypt/lv_usr"]="/mnt/usr noatime,compress=zstd,autodefrag"
        ["/dev/lvmcrypt/lv_var"]="/mnt/var noatime,compress=zstd,autodefrag"
        ["/dev/lvmcrypt/lv_varlog"]="/mnt/var/log noatime"
        ["/dev/lvmcrypt/lv_varlogaudit"]="/mnt/var/log/audit noatime"
        ["/dev/lvmcrypt/lv_tmp"]="/mnt/tmp noatime"
        ["/dev/lvmcrypt/lv_vartmp"]="/mnt/var/tmp noatime"
        ["${dev_path}p1"]="/mnt/boot noatime"
    )

    # Check if ZRAM is enabled or traditional swap is being used
    if [ -e /mnt/etc/systemd/system/zramswap.service ]; then
        log "ZRAM is enabled, no swap entry in fstab"
    else
        mount_points_options["/dev/lvmcrypt/lv_swap"]="none swap sw 0 0"
        log "Traditional swap is being used, adding swap entry to fstab"
    fi

    # Update fstab with custom mount options
    for device in "${!mount_points_options[@]}"; do
        mount_point="${mount_points_options[$device]%% *}"
        options="${mount_points_options[$device]#* }"
        update_fstab_entry "$device" "$mount_point" "$options"
    done

    log "Mount options added to /etc/fstab successfully"
    echo -e "${GREEN}[*] Mount options added to /etc/fstab successfully.${RESET}"
}

# Function for setting root password
set_root_password() {
    log "Setting root password"
    echo -e "${GREEN}[*] Setting root password...${RESET}"
    ask_root_password
    execute_command "chroot /mnt sh -c \"echo 'root:$root_password' | chpasswd\"" "set root password"
}

ask_username() {
    log "Prompting for username"
    while [[ -z $username || $confirm != "y" ]]; do
        read -rp "Enter the username: " username
        read -rp "Confirm username '$username' (y/n): " confirm
        [[ $confirm != "y" ]] && username=""
    done
}

set_user_info() {
    log "Adding user to wheel group and setting password"
    echo -e "${GREEN}[*] Setting user info...${RESET}"

    # Add user to the wheel group
    execute_command "arch-chroot /mnt useradd -m -G wheel -s /bin/bash '$username'" "add user to wheel group"

    # Configure sudoers file
    execute_command "arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers" "configure sudoers file"

    # Ask for user password
    ask_user_password

    # Set the user password in the chroot environment
    execute_command "arch-chroot /mnt bash -c \"echo '$username:$user_password' | chpasswd\"" "set user password"
}

# Function for installing additional software
install_software() {
    log "Installing additional software"
    echo -e "${GREEN}[*] Installing additional software...${RESET}"
    packages="aerc alacritty alsa-utils bluez btop cmake dhcpcd dmenu fd ffmpeg ffmpegthumbnailer firefox fish flameshot git ibus iw keepassxc lm_sensors lvm2 mlocate mpd mpv ncmpcpp neofetch neovim networkmanager ntfs-3g obsidian openvpn pass pipewire pipewire-alsa pipewire-jack pipewire-pulse qbittorrent qpwgraph ranger ripgrep sddm sway systemd-resolvconf terminus-font tmux upower virtualbox w3m wildmidi yakuake"
    
    if ! arch-chroot /mnt pacman -Sy $packages --noconfirm; then
        log "Failed to install additional software"
        echo "Failed to install additional software. Please check your internet connection and try again."
        exit 1
    fi
}

# Function for installing the BlackArch repository
install_blackarch() {
    log "Installing the BlackArch repository"
    echo -e "${GREEN}[*] Installing the BlackArch repository...${RESET}"
    
    # Download strap.sh
    if ! curl -O https://blackarch.org/strap.sh; then
        log "Failed to download BlackArch strap.sh"
        echo "Failed to download BlackArch strap.sh. Please check your internet connection and try again."
        exit 1
    fi

    # Make it executable and move it to /mnt
    chmod +x strap.sh
    mv strap.sh /mnt/strap.sh

    # Execute strap.sh in the chroot environment
    if ! arch-chroot /mnt /strap.sh; then
        log "Failed to install BlackArch"
        echo "Failed to install BlackArch. Please check your internet connection and try again."
        exit 1
    fi
}

install_graphics_driver() {
    log "Installing the graphics driver"
    echo -e "${GREEN}[*] Installing the graphics driver...${RESET}"
    
    video="unknown"
    
    # Check if running in a virtual machine
    case $(dmidecode -s system-product-name) in
        *VirtualBox*) video="virtualbox" ;;
        *VMware*) video="vmware" ;;
        *)
      *)
            gpu_detected=$(lspci | grep -iE "intel|nvidia|amd")
            if grep -qiE "intel|nvidia|amd" <<< "$gpu_detected"; then
                echo "Detected GPU(s): $gpu_detected"
                read -p "[?] Do you want to proceed with the installation? [Y/n]: " -r answer
                answer=${answer:-Y}
                [[ ! $answer =~ [Yy] ]] && log "Aborted installation" && echo "Aborted installation." && exit 0

                video=$(grep -oi "intel\|nvidia\|amd" <<< "$gpu_detected" | paste -sd+ -)
            else
                read -rp "[!] What is your GPU vendor: [intel] [nvidia] [amd]: " video
            fi
            ;;
    esac

    # Install the appropriate drivers
    case $video in
        intel) packages="xf86-video-intel mesa" ;;
        nvidia) packages="nvidia nvidia-settings" ;;
        amd) packages="xf86-video-amdgpu mesa" ;;
        intel+nvidia) packages="xf86-video-intel nvidia nvidia-settings" ;;
        intel+amd) packages="xf86-video-intel xf86-video-amdgpu mesa" ;;
        nvidia+amd) packages="nvidia nvidia-settings xf86-video-amdgpu mesa" ;;
        intel+nvidia+amd) packages="xf86-video-intel nvidia nvidia-settings xf86-video-amdgpu mesa" ;;
        virtualbox) packages="virtualbox-guest-utils" ;;
        vmware) packages="xf86-video-vmware mesa" ;;
        *) log "Invalid GPU selection" && echo "Invalid GPU selection." && exit 1 ;;
    esac

    arch-chroot /mnt pacman -S $packages --noconfirm
}

configure_networking() {
    log "Configuring networking"
    echo -e "${GREEN}[*] Configuring networking...${RESET}"

    arch-chroot /mnt bash -c "
        pacman -S --noconfirm iptables && \
        systemctl enable iptables.service && \
        iptables -P INPUT DROP && \
        iptables -P FORWARD DROP && \
        iptables -P OUTPUT ACCEPT && \
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT && \
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT && \
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT && \
        iptables-save > /etc/iptables/iptables.rules && \
        systemctl enable dhcpcd.service && \
        systemctl enable iwd.service && \
        systemctl enable systemd-resolved.service
    "
}

install_bootloader() {
    log "Installing bootloader"
    echo -e "${GREEN}[*] Installing bootloader...${RESET}"

    # Install GRUB and EFI boot manager in the chroot environment
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm

    # Get the UUID of the encrypted root partition (LUKS container)
    luks_partition_uuid=$(blkid -s UUID -o value ${dev_path}2)

    # Update GRUB configuration with the correct UUID for the LUKS container
    arch-chroot /mnt bash -c "echo 'GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$luks_partition_uuid:cryptroot root=/dev/mapper/lv_root\"' >> /etc/default/grub"

    # Install GRUB for EFI system
    execute_command "arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB" "install GRUB"

    # Generate GRUB configuration
    execute_command "arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg" "generate GRUB configuration"
}

generate_initramfs() {
    log "Generating initramfs"
    echo -e "${GREEN}[*] Generating initramfs...${RESET}"
    
    # Check for ZRAM usage and update hooks accordingly
    hooks="base udev autodetect modconf kms block encrypt lvm2 btrfs keyboard fsck"
    [ -f /mnt/etc/systemd/system/zramswap.service ] && hooks="$hooks zram"

    # Update HOOKS in mkinitcpio.conf and generate initramfs
    arch-chroot /mnt bash -c "sed -i 's/^HOOKS=.*/HOOKS=($hooks)/' /etc/mkinitcpio.conf && mkinitcpio -P"
}

create_crypttab_entry() {
    log "Creating crypttab entry"
    echo -e "${GREEN}[*] Creating crypttab entry...${RESET}"

    # Get the UUID of /dev/mapper/cryptroot and create crypttab entry
    if uuid=$(blkid -s UUID -o value /dev/mapper/cryptroot); then
        echo "cryptroot   UUID=$uuid   none   luks" | sudo tee /mnt/etc/crypttab > /dev/null
        log "crypttab entry created successfully"
    else
        log "Failed to retrieve UUID for /dev/mapper/cryptroot"
        echo "Failed to retrieve UUID for /dev/mapper/cryptroot."
    fi
}

verify_files() {
    log "Verifying files and configurations"
    echo -e "${GREEN}[*] Verifying files and configurations...${RESET}"

    # List of files to check
    files=(
        "/mnt/boot/grub/grub.cfg"
        "/mnt/boot/initramfs-linux.img"
        "/mnt/etc/fstab"
    )

    # Check each file
    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && log "$file not found" && echo "$file not found. Please check your system configuration." && exit 1
    done

    log "All necessary files are present and correct"
    echo "All necessary files are present and correct."
}

# Function to safely unmount all devices
safely_unmount_devices() {
    log "Safely unmounting devices"
    echo -e "${GREEN}[*] Safely unmounting devices...${RESET}"

    # Unmount filesystems in reverse order
    for dir in /mnt/var/tmp /mnt/tmp /mnt/var/log/audit /mnt/var/log /mnt/var /mnt/usr /mnt/home /mnt/boot /mnt; do
        if mountpoint -q "$dir"; then
            umount "$dir"
        else
            log "$dir is not mounted"
        fi
    done

    # Deactivate swap
    swapoff -a

    # Close the encrypted filesystems
    cryptsetup close cryptroot
}

main() {
    log "Script started"
    greet
    check_root
    securely_wipe_disk
    partition_and_encrypt
    fill_encrypted_partition_with_random_data
    createLVM2
    formatPartitions
    mountFilesystems
    installer
    configure_dynamic_zram
    set_root_password
    ask_username
    set_user_info
    install_software
    install_blackarch
    install_graphics_driver
    generate_initramfs
    create_crypttab_entry
    install_bootloader
    verify_files
    configure_networking
    safely_unmount_devices
    log "Script completed"
}

main
