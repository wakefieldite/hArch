# hArch {Hackers' Arch} (Do not use - WIP)

![image](https://user-images.githubusercontent.com/49621391/189473325-b63e7711-f5bc-4a6e-b19d-6c104306ea1e.png)


A semi-automated, minimalist Arch installation with additional repositories for tools you may find useful when wasting your time going down rabbit holes :)

hArch is preferably for Security Researchers, specifically those who have Arch Linux experience and want to get into Penetration Testing/Reverse Engineering but have an old or slow system, or just just prefer seeing Arch in your neofetch printout instead of Manjaro or Black Arch. The tools (Downloaded during install or after, your choice) are many of the known but widely used tools available. hArch is intended to be ran on bare metal or in a virtual machine, unlike distros named after Hindu deities and birds, as awesome as they are. hArch is meant to be a daily driver, but there's nothing wrong with virtualizing whatever tools you want, I still do. hArch **should** be hypervisor-agnostic, however I have not tested in Qubes, Xen, or Qemu so if that is what you prefer, your mileage may vary.

Have an old laptop collecting dust? Throw hArch on it.

Default Features:

         Shell = Fish
         WM/DE = I3 
         Display Manager = Ly
        
__________________________________________________________________________________________________________________________________________________________________

To install, boot into Arch live ISO and:
  
    1. Perform ATA Secure Erase as instructed by your drive manufacturer.
    2. curl -O https://raw.githubusercontent.com/wakefieldite/hArch/main/install.sh
    3. chmod +x install.sh
    4. ./install.sh
    5. Once logged in, you'll need to add your user to `wheel` and use `visudo` to uncomment your line for wheel group to have sudo permissions if you want sudo permissions.
    6. No UI is currently provided, I'm currently sorting out Hyprland.
