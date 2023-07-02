#!/usr/bin/env bash

# Function for partitioning and encrypting the disk
partition_and_encrypt() {
  echo "Partitioning and encrypting the disk..."
  read -p "Enter your SSD device path [Example: /dev/nvme0n1]: " dev_path
  parted --script $dev_path mklabel gpt mkpart ESP fat32 1MiB 300MiB set 1 boot on mkpart primary 300MiB 1300MiB mkpart primary 1300MiB 100%
  mkfs.fat -F32 ${dev_path}p1
  cryptsetup luksFormat --type luks2 --hash sha256 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 ${dev_path}p2
  cryptsetup luksFormat --type luks2 --hash sha256 --key-size 512 --iter-time 5000 --pbkdf argon2id --cipher aes-xts-plain64 ${dev_path}p3
  cryptsetup open --type luks ${dev_path}p2 cryptboot
  cryptsetup open --type luks ${dev_path}p3 cryptroot
  pvcreate /dev/mapper/cryptroot
  vgcreate vgname /dev/mapper/cryptroot
  lvcreate -L 8G vgname -n swap
  lvcreate -l 95%FREE vgname -n root
  mkfs.ext4 /dev/mapper/vgname-root
  mkswap /dev/mapper/vgname-swap
  mkfs.ext4 /dev/mapper/cryptboot
  mount /dev/mapper/vgname-root /mnt
  mkdir /mnt/boot
  mount /dev/mapper/cryptboot /mnt/boot
  swapon /dev/mapper/vgname-swap
  mkdir /mnt/boot/efi
  mount ${dev_path}p1 /mnt/boot/efi
  echo 'server = http://mirror.rackspace.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
  pacstrap /mnt base linux linux-firmware lvm2 vim intel-ucode --noconfirm
  genfstab -U /mnt >> /mnt/etc/fstab
}

# Function for setting the bootloader
booter() {
  echo "Setting Bootloader..."
  read -p "Enter the EFI directory path [Example: /boot/EFI]: " efi_dir
  read -p "Enter the device to install bootloader [Example: /dev/nvme0n1]: " boot_dev
  if [[ -d "/sys/firmware/efi" ]]
  then
    pacman -S efibootmgr dosfstools mtools os-prober --noconfirm
    grub-install --target=x86_64-efi --bootloader-id=HARCH_UEFI --efi-directory=$efi_dir --recheck
    grub-mkconfig -o /boot/grub/grub.cfg
  else
    grub-install --target=i386-pc $boot_dev --recheck
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

# Function for setting user info
userInfo() {
  echo "Please set ROOT password!!!"
  passwd
  read -p "Enter a new Username: " username
  echo "Welcome to your new system $username!"
  useradd -m -g users -G wheel,storage,power -s /bin/bash $username
  echo "Please set password for user: $username!!!"
  passwd $username
}

# Function for installing necessary packages
install_software() {
  echo "Installing software packages..."
  pacman -S dhcpcd iwd mlocate cmake grub yay git ntfs-3g xorg xorg-server i3-gaps xorg-xinit i3status dmenu lm_sensors upower networkmanager ibus bluez alsa-utils iw yakuake ranger neofetch tmux w3m ffmpeg ffmpegthumbnailer alacritty fish btop terminus-font flameshot pipewire qpwgraph pipewire-alsa pipewire-pulse pipewire-jack mpd ncmpcpp wildmidi mpv emacs git ripgrep fd keepassxc firefox obsidian qbittorrent vmware-workstation virtualbox openvpn pass systemd-resolvconf aerc sddm --noconfirm
}

# Function to install blackarch repository
install_blackarch() {
  echo "Installing BlackArch Repo..."
  curl -O https://blackarch.org/strap.sh
  chmod +x strap.sh
  ./strap.sh /dev/null 2>&1
}

# Main script execution
main() {
  partition_and_encrypt
  arch-chroot /mnt /bin/bash -c "$(declare -f install_software); install_software"
  arch-chroot /mnt /bin/bash -c "$(declare -f userInfo); userInfo"
  arch-chroot /mnt /bin/bash -c "$(declare -f booter); booter"
  arch-chroot /mnt /bin/bash -c "$(declare -f install_blackarch); install_blackarch"
  exit
}

main
