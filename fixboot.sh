#!/usr/bin/env bash

GREEN='\033[0;32m'
RESET='\033[0m'

# Function to check if script is running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run the script as root."
    exit 1
  fi
}

# Function to display greeting
greet() {
  echo -e "${GREEN}Chaotic_Guru's hArch Installer - OniSec Fixboot Script"
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
  ███████║███████║██║░░╚═╝███████║  ██║░░░░░██║██╔██╗██║██║░░░██║░╚███╔╝░
  ██╔══██║██╔══██║██║░░██╗██╔══██║  ██║░░░░░██║██║╚████║██║░░░██║░██╔██╗░
  ██║░░██║██║░░██║╚█████╔╝██║░░██║  ███████╗██║██║░╚███║╚██████╔╝██╔╝╚██╗
  ╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝  ╚══════╝╚═╝╚═╝░░╚══╝░╚═════╝░╚═╝░░╚═╝

  "
  echo -e "${RESET}"
  echo ""
  echo ""
}

# Function for fixing fstab
fix_fstab() {
  echo -e "${GREEN}[*] Fixing fstab...${RESET}"
  root_partition_uuid=$(blkid -s UUID -o value /dev/mapper/cryptroot)
  boot_partition_uuid=$(blkid -s UUID -o value "${dev_path}p1")

  awk -v root_uuid="$root_partition_uuid" -v boot_uuid="$boot_partition_uuid" '$2 == "/" {$1 = "UUID="root_uuid} $2 == "/boot" {$1 = "UUID="boot_uuid} 1' /mnt/etc/fstab > /mnt/etc/fstab.tmp
  mv /mnt/etc/fstab.tmp /mnt/etc/fstab

  echo "fstab fixed successfully."
}

# Function for fixing crypttab
fix_crypttab() {
  echo -e "${GREEN}[*] Fixing crypttab...${RESET}"
  # Add the crypttab entry for the encrypted partition
  echo "cryptroot   UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)   none   luks" >> /mnt/etc/crypttab

  echo "crypttab fixed successfully."
}

# Function for fixing mkinitcpio
fix_mkinitcpio() {
  echo -e "${GREEN}[*] Fixing mkinitcpio...${RESET}"
  # Regenerate the initramfs
  arch-chroot /mnt mkinitcpio -P

  echo "mkinitcpio fixed successfully."
}

# Function for fixing GRUB installation
fix_grub() {
  echo -e "${GREEN}[*] Fixing GRUB installation...${RESET}"
  # Install GRUB to the EFI system partition
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

  # Generate the GRUB configuration file
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

  echo "GRUB installation fixed successfully."
}

# Function for unlocking encrypted partition and mounting
unlock_and_mount() {
  echo -e "${GREEN}[*] Unlocking encrypted partition and mounting...${RESET}"
  cryptsetup luksOpen "${dev_path}2" cryptroot
  mount /dev/mapper/cryptroot /mnt
  mount "${dev_path}1" /mnt/boot

  echo "Encrypted partition unlocked and mounted successfully."
}

# Main script execution
main() {
  check_root
  greet
  unlock_and_mount
  fix_fstab
  fix_crypttab
  fix_mkinitcpio
  fix_grub
}

main
