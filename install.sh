#!/usr/bin/env bash

GREEN='\033[0;32m'
RESET='\033[0m'

declare -g encryption_password  # Declare encryption_password as a global variable
declare -g root_password  # Declare root_password as a global variable
declare -g user_password  # Declare user_password as a global variable
declare -g username  # Declare username as a global variable

# Function to check if script is running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run the script as root."
    exit 1
  fi
}

greet() {
	echo -e "${GREEN}Chaotic_Guru's hArch Installer - OniSec Remix"
	echo ""
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
	echo -e "${RESET}"
	echo ""
	echo ""
}


# Function to ask for the encryption password
ask_encryption_password() {
  echo -e "${GREEN}[*] Setting the encryption password...${RESET}"
  while true; do
    password1=$(systemd-ask-password "Enter the encryption password: ") 
    echo
    password2=$(systemd-ask-password "Re-enter the encryption password: ")
    echo
    if [[ "$password1" == "$password2" ]]; then
      encryption_password="$password1"
      break
    else
      echo "Passwords do not match. Please try again."
    fi
  done
}

# Function to ask for the root password
ask_root_password() {
  echo -e "${GREEN}[*] Setting the root password...${RESET}"
  while true; do
    password1=$(systemd-ask-password "Enter the root password: ")
    echo
    password2=$(systemd-ask-password "Re-enter the root password: ")
    echo
    if [[ "$password1" == "$password2" ]]; then
      root_password="$password1"
      break
    else
      echo "Passwords do not match. Please try again."
    fi
  done
}

# Function to ask for the user password
ask_user_password() {
  echo -e "${GREEN}[*] Setting the user password...${RESET}"
  while true; do
    password1=$(systemd-ask-password "Enter the user password: ")
    echo
    password2=$(systemd-ask-password "Re-enter the user password: ")
    echo
    if [[ "$password1" == "$password2" ]]; then
      user_password="$password1"
      break
    else
      echo "Passwords do not match. Please try again."
    fi
  done
}

# Function for securely wiping the disk
securely_wipe_disk() {
  echo -e "${GREEN}[*] Securely wiping the disk...${RESET}"
  read -p "Enter the SSD device path to securely wipe [Example: /dev/nvme0n1]: " dev_path

  if [[ ! -b "$dev_path" ]]; then
    echo "Invalid device path. Please provide a valid SSD device path."
    exit 1
  fi

  # Check if the device is a virtual NVMe drive
  if [[ $(nvme id "$dev_path" -o json | jq -r '.nvme_ctrl.vendor_id') == "0x80ee" ]]; then
    echo "Skipping secure erase and TRIM operations for virtual NVMe drive."
    return
  fi

  echo -e "${GREEN}[!] Performing Secure Erase on $dev_path...${RESET}"
  if ! nvme format "$dev_path" --ses=1; then
    echo "Failed to securely wipe the disk. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Disabling Secure Erase and Cryptographic Erase on $dev_path...${RESET}"
  if ! nvme sanitize "$dev_path" --sanact=0; then
    echo "Failed to disable Secure Erase and Cryptographic Erase on the disk. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Disabling TRIM on $dev_path...${RESET}"
  if ! nvme set-feature "$dev_path" -f 0x0c -v 0x0; then
    echo "Failed to disable TRIM. Please check your system configuration and try again."
    exit 1
  fi
}

# Function for partitioning and encrypting the disk
partition_and_encrypt() {
  echo -e "${GREEN}[*] Partitioning and encrypting the disk...${RESET}"
  read -ep "Enter your SSD device path [Default: /dev/nvme0n1]: " dev_path

  # Set default value if dev_path is empty
  if [[ -z "$dev_path" ]]; then
    dev_path="/dev/nvme0n1"
  fi

  if [[ ! -b "$dev_path" ]]; then
    echo "Invalid device path. Please provide a valid SSD device path."
    exit 1
  fi

  echo -e "${GREEN}[*] Creating partitions on $dev_path...${RESET}"
  if ! parted --script "$dev_path" mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 boot on mkpart primary 512MiB 100%; then
    echo "Failed to create partitions on $dev_path. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Formatting the ESP partition...${RESET}"
  if ! mkfs.fat -F32 "${dev_path}p1"; then
    echo "Failed to format the ESP partition. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Creating LUKS container on ${dev_path}p2...${RESET}"
  if ! cryptsetup luksFormat --type luks2 --hash sha512 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 "${dev_path}p2"; then
    echo "Failed to create LUKS container on ${dev_path}p2. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Opening LUKS container on ${dev_path}p2 as cryptroot...${RESET}"
  if ! cryptsetup open --type luks "${dev_path}p2" cryptroot; then
    echo "Failed to open LUKS container on ${dev_path}p2. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Verifying the device mapping for encryption...${RESET}"
  if ! cryptsetup status cryptroot; then
    echo "Failed to verify the device mapping for encryption. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Adding encryption key to cryptroot...${RESET}"
  if ! { echo "$encryption_password"; echo "$encryption_password"; echo "$encryption_password"; } | cryptsetup luksAddKey "${dev_path}p2" -; then
    echo "Failed to add encryption key to cryptroot. Please check your system configuration and try again."
    exit 1
  fi

  echo -e "${GREEN}[*] Filling encrypted partition with random data...${RESET}"
random_data_file="/tmp/random_data"
chunk_size="10M"

# Get the size of the encrypted partition
total_size=$(blockdev --getsize64 /dev/mapper/cryptroot)

if [[ -z "$total_size" ]]; then
  echo "Failed to retrieve the size of the encrypted partition. Please check your system configuration."
  exit 1
fi

chunk_size_bytes=$((1024 * 1024 * ${chunk_size%[A-Z]*}))
total_chunks=$(( (total_size + chunk_size_bytes - 1) / chunk_size_bytes ))

for ((i = 0; i < total_chunks; i++)); do
  dd if=/dev/urandom of="$random_data_file" bs="$chunk_size" count=1 status=none
  dd if="$random_data_file" of=/dev/mapper/cryptroot bs="$chunk_size" status=none
done

rm "$random_data_file"

echo -e "${GREEN}[*] Encrypted partition filled with random data successfully.${RESET}"

echo -e "${GREEN}[*] Formatting encrypted partition to Btrfs filesystem...${RESET}"
if mkfs.btrfs /dev/mapper/cryptroot; then
  echo -e "${GREEN}[+] Encrypted partition formatted to Btrfs filesystem successfully.${RESET}"
else
  echo "Failed to format encrypted partition to Btrfs filesystem. Please check your system configuration and try again."
  read -p "Press 'e' to exit or any other key to continue: " choice
  if [[ "$choice" == "e" ]]; then
    exit 1
  fi
fi

  echo -e "${GREEN}[*] Partitioning and encryption completed successfully.${RESET}"
}

# Function for installing the base system
installer() {
  echo -e "${GREEN}[*] Installing the base system...${RESET}"
  mount /dev/mapper/cryptroot /mnt
  mkdir /mnt/boot
  mount "${dev_path}p1" /mnt/boot
  pacstrap /mnt base linux linux-firmware vim intel-ucode btrfs-progs --noconfirm
  genfstab -U /mnt > /mnt/etc/fstab
}

# Function for setting root password
set_root_password() {
  echo -e "${GREEN}[*] Setting root password...${RESET}"
  ask_root_password
  echo "root:$root_password" | chroot /mnt chpasswd
}

# Function for setting user info
set_user_info() {
  echo -e "${GREEN}[*] Setting user info...${RESET}"
  read -p -r "Enter the username: " username
  arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
  arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
  ask_user_password
  echo "$username:$user_password" | chroot /mnt chpasswd
}

# Function for installing additional software
install_software() {
  echo -e "${GREEN}[*] Installing additional software...${RESET}"
  if ! arch-chroot /mnt pacman -Sy aerc alacritty alsa-utils bluez btop cmake dhcpcd dmenu emacs fd ffmpeg ffmpegthumbnailer firefox fish flameshot git i3-gaps i3status ibus iw iwd keepassxc lm_sensors mlocate mpd mpv ncmpcpp neofetch networkmanager ntfs-3g obsidian openvpn pass pipewire pipewire-alsa pipewire-jack pipewire-pulse qbittorrent qpwgraph ranger ripgrep sddm systemd-resolvconf terminus-font tmux upower virtualbox w3m wildmidi xorg xorg-server xorg-xinit yakuake --noconfirm; then
    echo "Failed to install additional software. Please check your internet connection and try again."
    exit 1
  fi
}

# Function for installing the BlackArch repository
install_blackarch() {
  echo -e "${GREEN}[*] Installing the BlackArch repository...${RESET}"
  if ! curl -O https://blackarch.org/strap.sh; then
    echo "Failed to download BlackArch strap.sh. Please check your internet connection and try again."
    exit 1
  fi

  chmod +x strap.sh
  mv strap.sh /mnt/strap.sh

  if ! arch-chroot /mnt /strap.sh; then
    echo "Failed to install BlackArch. Please check your internet connection and try again."
    exit 1
  fi
}

# Function for installing the graphics driver
install_graphics_driver() {
  echo -e "${GREEN}[*] Installing the graphics driver...${RESET}"
  read -p -r "[!] What is your GPU: [amd] [nvidia] or [intel]: " video
  case $video in
    amd)
      arch-chroot /mnt pacman -S xf86-video-ati mesa --noconfirm
      ;;
    nvidia)
      arch-chroot /mnt pacman -S nvidia nvidia-settings --noconfirm
      ;;
    intel)
      arch-chroot /mnt pacman -S xf86-video-intel mesa intel-ucode --noconfirm
      ;;
    *)
      echo "Invalid GPU selection. Please select either [amd], [nvidia], or [intel]."
      exit 1
      ;;
  esac
}

# Function for configuring the firewall
configure_firewall() {
  echo -e "${GREEN}[*] Configuring firewall...${RESET}"
  arch-chroot /mnt pacman -S --noconfirm iptables
  arch-chroot /mnt systemctl enable iptables.service
  arch-chroot /mnt iptables -P INPUT DROP
  arch-chroot /mnt iptables -P FORWARD DROP
  arch-chroot /mnt iptables -P OUTPUT ACCEPT
  arch-chroot /mnt iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  arch-chroot /mnt iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
  arch-chroot /mnt sh -c 'iptables-save > /etc/iptables/iptables.rules'
}

# Function for installing the bootloader
install_bootloader() {
  echo -e "${GREEN}[*] Installing bootloader...${RESET}"
  arch-chroot /mnt pacman -S grub efibootmgr --noconfirm
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# Function for generating initramfs
generate_initramfs() {
  echo -e "${GREEN}[*] Generating initramfs...${RESET}"
  arch-chroot /mnt sed -i '/^HOOKS=/s/)$/) encrypt btrfs)/' /etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -p linux
}

# Function for verifying files and configurations
verify_files() {
  echo -e "${GREEN}[*] Verifying files and configurations...${RESET}"
  if [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
    echo "Bootloader configuration file not found. The bootloader may not be installed correctly."
    exit 1
  fi

  if [[ ! -f /mnt/boot/initramfs-linux.img ]]; then
    echo "Initramfs file not found. The initramfs may not have been generated correctly."
    exit 1
  fi

  if [[ ! -f /mnt/etc/fstab ]]; then
    echo "File /etc/fstab not found. The system may not be properly configured."
    exit 1
  fi

  echo -e "${GREEN}[*] Verifying root and boot partitions in /etc/fstab...${RESET}"
  
  root_partition="/dev/mapper/cryptroot"  # Update this with the correct root partition
  boot_partition="${dev_path}p1"  # Update this with the correct boot partition

  if ! grep -q "$root_partition" /mnt/etc/fstab; then
    echo "Root partition ($root_partition) is not properly configured in /etc/fstab."
    exit 1
  fi

  if ! grep -q "$boot_partition" /mnt/etc/fstab; then
    echo "Boot partition ($boot_partition) is not properly configured in /etc/fstab."
    exit 1
  fi

  cat /mnt/etc/fstab

  echo -e "${GREEN}[!] Please verify that the partitions, file systems, and configurations are set up correctly.${RESET}"
  read -p -r "Press Enter to continue..."
}

# Main script execution
main() {
  greet
  check_root
  ask_encryption_password
  securely_wipe_disk
  partition_and_encrypt
  installer
  set_root_password
  set_user_info
  install_software
  install_blackarch
  install_graphics_driver
  configure_firewall
  install_bootloader
  generate_initramfs
  verify_files
}

main
