hArch tweaks
- pacman:
	- linux-headers 

hArchPOST tweaks
- pacman:
	- a lot to add later

Post-install commands:
- sudo systemctl enable dhcpcd
- sudo systemctl start dhcpcd
- sudo modprobe -a vmw_vmci vmmon
- sudo systemctl enable vmware-networks
- sudo systemctl enable vmware-usbarbitrator
- paru -S mkinitcpio-firmware virtualbox-ext-oracle discord tor-browser alacritty-themes freshfetch-git ly
- sudo pacman -R sddm
- systemctl enable ly
- echo "set preview_images true" >> ~/.config/ranger/rc.conf
