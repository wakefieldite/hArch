#!/usr/bin/env bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'
declare -g dev_path

check_root() {
    [[ $EUID -ne 0 ]] && echo "Please run the script as root." && exit 1
}

greet() {
    echo -e "${GREEN}hArch Installer - OniSec Remix\n"
    echo "
    ██╗░░██╗░█████╗░░█████╗░██╗░░██╗███████╗██████╗░░██████╗██╗
    ██║░░██║██╔══██╗██╔══██╗██║░██╔╝██╔════╝██╔══██╗██╔════╝╚█║
    ███████║███████║██║░░╚═╝█████═╝░█████╗░░██████╔╝╚█████╗░░╚╝
    ██╔══██║██╔══██║██║░░██╗██╔═██╗░██╔══╝░░██╔══██╗░╚═══██╗░░░
    ██║░░██║██║░░██║╚█████╔╝██║░░╚██╗███████╗██║░░██║██████╔╝░░░
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

validate_device_path() {
    local dev_path=$1

    # Ensure the device path includes /dev/
    if [[ ! "$dev_path" =~ ^/dev/ ]]; then
        dev_path="/dev/$dev_path"
    fi

    # Validate device path
    if [[ ! -b "$dev_path" ]]; then
        echo "Invalid device path: $dev_path. Please provide a valid SSD device path."
        exit 1
    fi

    echo "$dev_path"
}

identify_installation_disk() {
    # Prompt user to identify the installation disk
    read -erp "Enter the device you want to install to [e.g., sda, nvme0n1]: " user_input

    # Ensure the device path includes /dev/
    if [[ ! "$user_input" =~ ^/dev/ ]]; then
        dev_path="/dev/$user_input"
    else
        dev_path="$user_input"
    fi

    # Validate device path
    if [[ ! -b "$dev_path" ]]; then
        echo "Invalid device path: $dev_path. Please provide a valid SSD device path."
        exit 1
    fi

    # Debugging: Show the selected device path
    echo "[DEBUG] Selected device path: $dev_path"

    # Display selected device information with partitions
    echo "[!] You have selected $dev_path for installation. Please make sure this is the correct drive."

    # Confirm user's choice
    read -p "Are you sure you want to install on $dev_path? This will erase all data on the drive. (y/n): " confirm_choice
    if [[ "$confirm_choice" != "y" ]]; then
        echo "Installation disk selection canceled."
        exit 1
    fi
}

partition_and_encrypt() {
    local encryption_choice=$1

    echo -e "${GREEN}[*] Creating boot partition...${RESET}"
    echo -e "${YELLOW}[DEBUG] dev_path before partitioning: $dev_path${RESET}"

    # Create partitions and format ESP
    execute_command "parted --script $dev_path mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 boot on mkpart primary 512MiB 100%" "create partitions on $dev_path"
    

    echo -e "${YELLOW}[DEBUG] dev_path after partitioning: $dev_path${RESET}"

    execute_command "mkfs.fat -F32 ${dev_path}p1" "format the ESP partition"
    

    if [ "$encryption_choice" == "y" ]; then
        echo -e "${GREEN}[*] Creating LUKS container on ${dev_path}p2...${RESET}"
        cryptsetup luksFormat --type luks2 --hash sha512 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 --sector-size 4096 "${dev_path}p2"
        

        echo -e "${GREEN}[*] Opening LUKS container on ${dev_path}p2 as cryptroot...${RESET}"
        cryptsetup open --type luks "${dev_path}p2" cryptroot

        execute_command "cryptsetup status cryptroot" "verify the device mapping for encryption"
        
    fi
}

securely_wipe_disk() {
    local dev_path=$1
    echo -e "${GREEN}[*] Securely wiping the disk...${RESET}"

    # Check if the device is an NVMe drive
    if ! nvme id-ctrl "$dev_path" &>/dev/null; then
        echo "Device $dev_path is not an NVMe drive, skipping secure erase."
        return
    fi

    # Get the vid value
    vid=$(nvme id-ctrl "$dev_path" | grep -i "vid" | awk '{print $3}')
    vid_hex=$(printf "0x%x" $vid)

    # Check for known virtual machine vendor IDs
    # Known virtual machine vendor IDs (VMware: 0x5549, VirtualBox: 0x80ee, QEMU: 0x1af4, Hyper-V: 0x1414)
    if [[ "$vid_hex" == "0x5549" || "$vid_hex" == "0x80ee" || "$vid_hex" == "0x1af4" || "$vid_hex" == "0x1414" ]]; then
        if [[ "$vid_hex" == "0x5549" ]]; then
            echo "Skipping secure erase operations for VMware virtual NVMe drive (VID: $vid_hex)."
        elif [[ "$vid_hex" == "0x80ee" ]]; then
            echo "Skipping secure erase operations for VirtualBox virtual NVMe drive (VID: $vid_hex)."
        elif [[ "$vid_hex" == "0x1af4" ]]; then
            echo "Skipping secure erase operations for QEMU virtual NVMe drive (VID: $vid_hex)."
        elif [[ "$vid_hex" == "0x1414" ]]; then
            echo "Skipping secure erase operations for Hyper-V virtual NVMe drive (VID: $vid_hex)."
        fi
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

fill_encrypted_partition() {
    echo -e "${GREEN}[*] Filling encrypted partition with random data...${RESET}"

    # Check if the device exists
    if [ ! -e /dev/mapper/cryptroot ]; then
        echo "Encrypted partition /dev/mapper/cryptroot does not exist. Please check your configuration."
        exit 1
    fi

    # Get the size of the encrypted partition
    total_size=$(blockdev --getsize64 /dev/mapper/cryptroot)

    if [[ -z "$total_size" ]]; then
        echo "Failed to retrieve the size of the encrypted partition. Please check your system configuration."
        exit 1
    fi

    chunk_size="10M"
    chunk_size_bytes=$((1024 * 1024 * ${chunk_size%[A-Z]*}))
    total_chunks=$(( (total_size + chunk_size_bytes - 1) / chunk_size_bytes ))

    for ((i = 0; i < total_chunks; i++)); do
        # Generate random data directly and write to the encrypted partition
        dd if=/dev/urandom of=/dev/mapper/cryptroot bs="$chunk_size" count=1 seek="$i" status=progress
    done

    echo -e "${GREEN}[*] Encrypted partition filled with random data successfully.${RESET}"
}

createLVM2() {
    local dev_path=$1
    local encryption_choice=$2

    echo -e "${GREEN}[*] Configuring LVM...${RESET}"

    local pv_path="/dev/mapper/cryptroot"

    if [ "$encryption_choice" != "y" ]; then
        pv_path="${dev_path}p2"
    fi

    echo -e "${GREEN}[*] Creating physical volume...${RESET}"
    pvcreate -ff "$pv_path"
    

    echo -e "${GREEN}[*] Creating volume group...${RESET}"
    vgcreate "vg0" "$pv_path"
    

    echo -e "${GREEN}[*] Creating logical volume for root...${RESET}"
    lvcreate -L 20G -n lv_root "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for home...${RESET}"
    lvcreate -l 100%FREE -n lv_home "vg0"
    

    echo -e "${GREEN}[*] Resizing home logical volume...${RESET}"
    lvresize -L 1G "/dev/vg0/lv_home"
    
    
    echo -e "${GREEN}[*] Creating logical volume for usr...${RESET}"
    lvcreate -L 20G -n lv_usr "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for var...${RESET}"
    lvcreate -L 10G -n lv_var "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for varlog...${RESET}"
    lvcreate -L 4G -n lv_varlog "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for varlogaudit...${RESET}"
    lvcreate -L 2G -n lv_varlogaudit "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for tmp...${RESET}"
    lvcreate -L 4G -n lv_tmp "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for vartmp...${RESET}"
    lvcreate -L 4G -n lv_vartmp "vg0"
    

    echo -e "${GREEN}[*] Creating logical volume for swap...${RESET}"
    lvcreate -L 8G -n lv_swap "vg0"
    

    echo -e "${GREEN}[*] Resizing home logical volume to use remaining free space...${RESET}"
    lvresize -l 100%FREE "/dev/vg0/lv_home"
    
}

formatPartitions() {
    local encryption_choice=$1

    echo -e "${GREEN}[*] Formatting partitions to Btrfs filesystem...${RESET}"

    echo -e "${GREEN}[*] Formatting root partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_root"
    
    echo -e "${GREEN}[*] Formatting home partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_home"
    
    echo -e "${GREEN}[*] Formatting usr partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_usr"
    
    echo -e "${GREEN}[*] Formatting var partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_var"
    
    echo -e "${GREEN}[*] Formatting varlog partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_varlog"
    
    echo -e "${GREEN}[*] Formatting varlogaudit partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_varlogaudit"
    
    echo -e "${GREEN}[*] Formatting tmp partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_tmp"
    
    echo -e "${GREEN}[*] Formatting vartmp partition...${RESET}"
    mkfs.btrfs "/dev/vg0/lv_vartmp"
    
    echo -e "${GREEN}[*] Formatting swap partition...${RESET}"
    mkswap "/dev/vg0/lv_swap"   
}

mountFilesystems() {
    local encryption_choice=$1

    echo -e "${GREEN}[*] Mounting filesystems...${RESET}"

    echo -e "${GREEN}[*] Mounting root filesystem...${RESET}"
    mount -o noatime,compress=zstd,autodefrag "/dev/vg0/lv_root" /mnt

    echo -e "${GREEN}[*] Creating and mounting boot directory...${RESET}"
    mkdir -p /mnt/boot
    mount "${dev_path}p1" /mnt/boot
    
    echo -e "${GREEN}[*] Creating and mounting home directory...${RESET}"
    mkdir -p /mnt/home
    mount -o noatime,compress=zstd,autodefrag "/dev/vg0/lv_home" /mnt/home
    
    echo -e "${GREEN}[*] Creating and mounting usr directory...${RESET}"
    mkdir -p /mnt/usr
    mount -o noatime,compress=zstd,autodefrag "/dev/vg0/lv_usr" /mnt/usr
    
    echo -e "${GREEN}[*] Creating and mounting var directory...${RESET}"
    mkdir -p /mnt/var
    mount -o noatime,compress=zstd,autodefrag "/dev/vg0/lv_var" /mnt/var
    
    echo -e "${GREEN}[*] Creating and mounting varlog directory...${RESET}"
    mkdir -p /mnt/var/log
    mount -o noatime "/dev/vg0/lv_varlog" /mnt/var/log

    echo -e "${GREEN}[*] Creating and mounting varlogaudit directory...${RESET}"
    mkdir -p /mnt/var/log/audit
    mount -o noatime "/dev/vg0/lv_varlogaudit" /mnt/var/log/audit

    echo -e "${GREEN}[*] Creating and mounting tmp directory...${RESET}"
    mkdir -p /mnt/tmp
    mount -o noatime "/dev/vg0/lv_tmp" /mnt/tmp

    echo -e "${GREEN}[*] Creating and mounting vartmp directory...${RESET}"
    mkdir -p /mnt/var/tmp
    mount -o noatime "/dev/vg0/lv_vartmp" /mnt/var/tmp

    echo -e "${GREEN}[*] Enabling swap...${RESET}"
    swapon "/dev/vg0/lv_swap" 
}

add_mount_options_to_fstab() {
    local dev_path=$1
    local encryption_choice=$2

    echo -e "${GREEN}[*] Adding mount options to /etc/fstab...${RESET}"

    # Generate fstab
    genfstab -U /mnt > /mnt/etc/fstab

    # Function to update fstab with desired mount options
    update_fstab_entry() {
        local device="$1"
        local mount_point="$2"
        local fstype="$3"
        local options="$4"

        device_escaped=$(echo "$device" | sed 's/\//\\\//g')
        mount_point_escaped=$(echo "$mount_point" | sed 's/\//\\\//g')

        # Update fstab entry with mount options
        sed -i "s|^$device_escaped\s\+$mount_point_escaped\s\+\w\+\s\+\w\+|$device_escaped $mount_point $fstype $options|" /mnt/etc/fstab
    }

    declare -A mount_points_options=(
        ["/dev/mapper/vg0-lv_root"]="/ btrfs noatime,compress=zstd,autodefrag"
        ["/dev/mapper/vg0-lv_home"]="/home btrfs noatime,compress=zstd,autodefrag"
        ["/dev/mapper/vg0-lv_usr"]="/usr btrfs noatime,compress=zstd,autodefrag"
        ["/dev/mapper/vg0-lv_var"]="/var btrfs noatime,compress=zstd,autodefrag"
        ["/dev/mapper/vg0-lv_varlog"]="/var/log btrfs noatime"
        ["/dev/mapper/vg0-lv_varlogaudit"]="/var/log/audit btrfs noatime"
        ["/dev/mapper/vg0-lv_tmp"]="/tmp btrfs noatime"
        ["/dev/mapper/vg0-lv_vartmp"]="/var/tmp btrfs noatime"
    )

    if [ -e /mnt/etc/systemd/system/zramswap.service ]; then
        echo "ZRAM is enabled, no swap entry in fstab"
    else
        mount_points_options["/dev/mapper/vg0-lv_swap"]="none swap sw 0 0"
        echo "Traditional swap is being used, adding swap entry to fstab"
    fi

    # Add or update entries for all mount points except boot
    for device in "${!mount_points_options[@]}"; do
        mount_point="${mount_points_options[$device]%% *}"
        fstype="${mount_points_options[$device]#* }"
        options="${fstype#* }"
        fstype="${fstype%% *}"
        update_fstab_entry "$device" "$mount_point" "$fstype" "$options"
    done

    # Add or update the entry for the boot partition using UUID
    boot_uuid=$(blkid -s UUID -o value "${dev_path}p1")
    sed -i "s|^UUID=$boot_uuid\s\+/boot\s\+\w\+\s\+\w\+|UUID=$boot_uuid /boot vfat noatime|" /mnt/etc/fstab

    echo -e "${GREEN}[*] Mount options added to /etc/fstab successfully.${RESET}"
}

set_root_password() {
    echo -e "${GREEN}[*] Setting the root password...${RESET}"
    arch-chroot /mnt passwd root
}

set_user_info() {
    read -p "Enter your username: " username
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo -e "${GREEN}[*] Setting the user password for $username...${RESET}"
    arch-chroot /mnt passwd "$username"
}

# Function to ask for hostname
ask_hostname() {
    while true; do
        read -p "Please enter a hostname: " hostname
        if [[ -z "$hostname" ]]; then
            echo "Hostname cannot be empty. Please enter a valid hostname."
        elif [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,62}[a-zA-Z0-9]$ ]]; then
            echo "Invalid hostname. It should be 2-63 characters long, start and end with an alphanumeric character, and only contain alphanumeric characters and hyphens."
        else
            break
        fi
    done
    
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc

    echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

    echo "$hostname" > /mnt/etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$hostname.localdomain $hostname" > /mnt/etc/hosts
}


install_software() {
    echo -e "${GREEN}[*] Installing additional software...${RESET}"
    arch-chroot /mnt pacman -S --noconfirm aerc alacritty alsa-utils bluez btop cmake dhcpcd dmenu fd ffmpeg ffmpegthumbnailer firefox fish flameshot git ibus iw keepassxc lm_sensors ly lvm2 mlocate mpd mpv ncmpcpp neofetch neovim networkmanager ntfs-3g obsidian openvpn pass pipewire pipewire-alsa pipewire-jack pipewire-pulse qbittorrent qpwgraph ranger ripgrep sddm sway systemd-resolvconf terminus-font tmux upower virtualbox w3m wildmidi yakuake
}

install_blackarch() {
    echo -e "${GREEN}[*] Installing BlackArch tools...${RESET}"
    arch-chroot /mnt curl -O https://blackarch.org/strap.sh
    arch-chroot /mnt chmod +x strap.sh
    arch-chroot /mnt ./strap.sh
}

install_graphics_driver() {
    echo -e "${GREEN}[*] Installing the graphics driver...${RESET}"
    
    video="unknown"
    
    # Check if running in a virtual machine
    case $(dmidecode -s system-product-name) in
        *VirtualBox*) video="virtualbox" ;;
        *VMware*) video="vmware" ;;
        *)
            gpu_detected=$(lspci | grep -iE "intel|nvidia|amd")
            if grep -qiE "intel|nvidia|amd" <<< "$gpu_detected"; then
                echo "Detected GPU(s): $gpu_detected"
                read -p "[?] Do you want to proceed with the installation? [Y/n]: " -r answer
                answer=${answer:-Y}
                [[ ! $answer =~ [Yy] ]] && echo "Aborted installation." && exit 0

                video=$(grep -oi "intel\|nvidia\|amd" <<< "$gpu_detected" | paste -sd+ -)
            else
                read -rp "[!] What is your GPU vendor: [intel] [nvidia] [amd]: " video
            fi
            ;;
    esac

    # Install the appropriate drivers
    case $video in
        intel) packages=(xf86-video-intel mesa) ;;
        nvidia) packages=(nvidia nvidia-settings) ;;
        amd) packages=(xf86-video-amdgpu mesa) ;;
        intel+nvidia) packages=(xf86-video-intel nvidia nvidia-settings) ;;
        intel+amd) packages=(xf86-video-intel xf86-video-amdgpu mesa) ;;
        nvidia+amd) packages=(nvidia nvidia-settings xf86-video-amdgpu mesa) ;;
        intel+nvidia+amd) packages=(xf86-video-intel nvidia nvidia-settings xf86-video-amdgpu mesa) ;;
        virtualbox) packages=(virtualbox-guest-utils) ;;
        vmware) packages=(xf86-video-vmware mesa) ;;
        *) log "Invalid GPU selection" && echo "Invalid GPU selection." && exit 1 ;;
    esac

    arch-chroot /mnt pacman -S "${packages[@]}" --noconfirm
}

configure_networking() {
    arch-chroot /mnt bash -c "
        pacman -S --noconfirm nftables && \
        systemctl enable nftables.service && \
        cat > /etc/nftables.conf <<EOF
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iif lo accept
        ip protocol icmp accept
        tcp dport ssh accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
        systemctl enable systemd-networkd.service && \
        systemctl enable dhcpcd.service && \
        systemctl enable systemd-resolved.service
    "
}

safely_unmount_devices() {
    echo -e "${GREEN}[*] Safely unmounting devices...${RESET}"
    umount -R /mnt
    swapoff -a
    if [ "$encryption_choice" == "y" ]; then
        cryptsetup close cryptroot
    fi
}

generate_initramfs() {
    local encryption_choice=$1
    echo -e "${GREEN}[*] Generating initramfs...${RESET}"

    if [ "$encryption_choice" == "y" ]; then
        hooks="base udev autodetect modconf kms block encrypt lvm2 btrfs usr filesystems keyboard fsck"
    else
        hooks="base udev autodetect modconf kms block lvm2 btrfs usr filesystems keyboard fsck"
    fi

    arch-chroot /mnt bash -c "sed -i 's/^HOOKS=.*/HOOKS=($hooks)/' /etc/mkinitcpio.conf && mkinitcpio -P linux"
}


create_crypttab_entry() {
    if uuid=$(blkid -s UUID -o value /dev/mapper/cryptroot); then
        echo "cryptroot   UUID=$uuid   none   luks" | tee /mnt/etc/crypttab > /dev/null
    else
        echo "Failed to retrieve UUID for /dev/mapper/cryptroot."
    fi
}

verify_files() {
    echo -e "${GREEN}[*] Verifying files and configurations...${RESET}"

    # List of files to check
    files=(
        "/mnt/boot/grub/grub.cfg"
        "/mnt/boot/initramfs-linux.img"
        "/mnt/etc/fstab"
    )

    # Check each file
    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && echo "$file not found. Please check your system configuration." && exit 1
    done
    echo "All necessary files are present and correct."
}

configure_dynamic_zram() {
    encryption_choice=$1
    echo -e "${GREEN}[*] Configuring dynamic ZRAM...${RESET}"

    # Explain ZRAM benefits and drawbacks
    echo -e "${YELLOW}[*] Why Enable ZRAM:${RESET}\n- Improved Performance: Faster swap operations using compressed RAM instead of disk-based swap.\n- Reduced I/O Overhead: Reduces load on disk I/O, enhancing system performance.\n- Memory Efficiency: Compresses data, allowing more effective use of RAM."
    echo -e "${RED}[*] Why Not Enable ZRAM:${RESET}\n- Sufficient RAM: If you have plenty of RAM and don't use swap often, ZRAM may not provide significant benefits.\n- System Overhead: Compression and decompression operations may introduce slight CPU overhead."

    # Prompt user to enable ZRAM
    while true; do
        read -rp "Do you want to enable ZRAM to replace swap? (yes/no): " user_input
        case $user_input in
            yes|no)
                break
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done

    if [[ "$user_input" != "yes" ]]; then
        echo -e "${RED}[*] ZRAM configuration aborted by user.${RESET}"
        return
    fi

    echo -e "${GREEN}[*] Installing and configuring ZRAM...${RESET}"
    pacstrap /mnt zram-generator || { echo "Error: Failed to install zram-generator." >&2; exit 1; }

    # Create ZRAM config file
    cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

    arch-chroot /mnt systemctl enable systemd-zram-setup@zram0.service || { echo "Error: Failed to enable zram service." >&2; exit 1; }
    echo "Zram setup with zram-generator complete."

    # Create sysctl config for ZRAM optimization
    cat <<EOF > /mnt/etc/sysctl.d/99-vm-zram-parameters.conf
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
    arch-chroot /mnt sysctl --system

    # Disable all swap and adjust logical volumes based on encryption choice
    swapoff -a
    if ! lvremove -y /dev/vg0/lv_swap; then
        echo "Error: Failed to remove swap logical volume." >&2
        exit 1
    fi
    umount /mnt/home || { echo "Error: Failed to unmount home logical volume." >&2; exit 1; }
    if ! lvextend -l +100%FREE /dev/vg0/lv_home; then
        echo "Error: Failed to extend home logical volume." >&2
        exit 1
    fi
    
    mount /dev/vg0/lv_home /mnt/home || { echo "Error: Failed to mount home logical volume." >&2; exit 1; }
    btrfs filesystem resize max /mnt/home || { echo "Error: Failed to resize home Btrfs filesystem." >&2; exit 1; }

    log "ZRAM configured successfully, swap removed, home LV expanded, and zramswap service created"
    echo -e "${GREEN}[*] ZRAM configured, swap removed, home LV expanded, and zramswap service created.${RESET}"
}

install_bootloader() {
    local dev_path=$1
    local encryption_choice=$2

    echo -e "${GREEN}[*] Installing bootloader...${RESET}"
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm

    # Install the GRUB bootloader
    echo -e "${GREEN}[*] Installing GRUB bootloader...${RESET}"
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Failed to install GRUB bootloader.${RESET}"
        exit 1
    fi

    # Set the GRUB_CMDLINE_LINUX based on the encryption choice
    if [ "$encryption_choice" == "y" ]; then
        luks_partition_uuid=$(blkid -s UUID -o value "${dev_path}p2")
        arch-chroot /mnt bash -c "echo 'GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash cryptdevice=UUID=$luks_partition_uuid:cryptroot root=/dev/mapper/vg0-lv_root\"' >> /etc/default/grub"
    else
        root_partition_uuid=$(blkid -s UUID -o value "/dev/vg0/lv_root")
        arch-chroot /mnt bash -c "echo 'GRUB_CMDLINE_LINUX_DEFAULT=\"root=UUID=$root_partition_uuid\"' >> /etc/default/grub"
    fi

    # Generate the GRUB configuration
    echo -e "${GREEN}[*] Generating GRUB configuration...${RESET}"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Failed to generate GRUB configuration.${RESET}"
        exit 1
    fi
    
    # Regenerate the initramfs
    echo -e "${GREEN}[*] Regenerating initramfs...${RESET}"
    arch-chroot /mnt mkinitcpio -P linux
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Failed to regenerate initramfs.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[*] Bootloader installation completed successfully.${RESET}"
}

installer() {
    echo -e "${GREEN}[*] Running installer...${RESET}"
    pacstrap /mnt base linux linux-firmware vim intel-ucode btrfs-progs sudo dhcpcd vi iwd --noconfirm
}

main() {
    greet
    check_root
    encryption_choice=$(ask_full_disk_encryption)
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL | grep -E 'disk|part'
    identify_installation_disk

    if [ "$encryption_choice" == "y" ]; then
        securely_wipe_disk
        
    fi

    partition_and_encrypt "$encryption_choice"

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
    set_user_info
    ask_hostname
    install_software
    #install_blackarch
    install_graphics_driver
    generate_initramfs "$encryption_choice"

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
