# hArch {Hackers' Arch} 

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
  
    1. curl -O https://raw.githubusercontent.com/wakefieldite/hArch/main/hArch
    2. chmod +x hArch
    3. ./hArch
    4. At the end of the hArch shell script, it will download hArchPOST
    5. arch-chroot /mnt
    7. ./hArchPOST
    
Prior to v1.0.0, tools will be added, until then it is a manual process. Tools will be broken down into categories for a more user preferred system, not every tool is needed. Master tool list is downloaded as of now!!!

    1. Web-Tools = Web App and Network Tools, i.e. Metasploit, Dirbuster etc...
    2. Cracking-Tools = Cracking tools, i.e Hydra, Hashcat etc...
    3. Forensic-Tools = Tools for Forensics, i.e. Maltego, Steghide etc...
    4. Master-toolList = You guessed it, all the tools in one txt file...
    
    If you wish to communicate with me on any updates or bugs: Create an issue, or find me on CHN discord until we migrate to Matrix.
