
This document serves to provide a list of customizations and reasons why one tool was chosen over another.
For example: 
<details>
<summary>Desktop Environment/Window Manager: [i3-gaps-rounded](https://aur.archlinux.org/packages/i3-gaps-rounded-git)</summary>
  Originally I was looking to use i3 with some elements from KDE, I've since found all things I really wanted from KDE can be done quite well in i3, so I decided to try just i3-gaps-rounded. There are however many WMs I want to try, I would use sway but as an nvidia user the performance hit with free drivers isn't appealing My pay does run Sway though, absolutely love it. If you have AMD GPU or just integrated then Sway may be good for you..</details>

<details>
<summary>Display Manager: [Ly](https://aur.archlinux.org/packages/ly)</summary>
  minimalist while still modern. There are plenty of alternatives which would be commandline, such as emptty. I am however seeing a problem logging out to Ly from i3 where you have to reboot to get back to Ly, so investigating this and hopefully fixing this otherwise I will have to pick a different display manager.</details>

<details>
<summary>File Manager: [ranger](https://github.com/ranger/ranger) + w3m + ffmpeg + ffmpegthumbnailer</summary>
  Originally I wanted to use thunar as a file manager because of a riced out thunar I saw with a background image in the navigation pane. I chose to use ranger as a file manager because everything I wanted out of KDE could be achieved using just i3. When I found out I could just use ranger for most things, I decided to give it a shot. The only area of inconvenience I see is that without a file manager I cannot quickly look through files just looking at the thumbnail. However, if I just organize better and use more meaningful names for files, that won't be necessary anyways. With the packages listed after ranger, and echoing one line to an rc file I can preview the files I need to in the terminal and it works with alacritty or kitty if that's what you prefer. It's somewhat works in konsole but it isn't anywhere close to perfect. It's important to note that all you need is the one line enabling previews in your rc file, the sh file and extra settings seems to cause issues, like kitty asks for PIL (pillow). Providing PIL does nothing. Just leave the one line shown in the tweaks.md file on line 18.</details>

<details>
  <summary>Terminal Emulator: alacritty and yakuake (konsole)</summary>
  Originally I was planning on using yakuake and rxvt-unicode because of media previewing in ranger. I later found out I could do the same with alacritty, performance wise alacritty is supposed to outperform kitty and outperformed rxvt-unicode by far. Yakuake is being kept for drop down, multi-tab purposes, and persistence between workspaces. Primarily used for convenience with hotkeys to show/hide and shift through tabs while running multiple processes simultaneously when doing penetration testing or working on HTB and similar CTFs, plus castero/ncmpcpp in yakuake allows me to pause/play from any workspace. The only other reason to keep it is because alacritty uses GPU power and unless I'm going to pay for some NPK time in AWS, I'm going to want my GPU resources available for hashcat at times and so konsole would be a better choice in terms of conserving resources. Yakuake may end up being replaced by tmux due to being able to see all terminals at once in which case I would probably switch out konsole for xterm or something if I can control the transparency via i3.
</details>

<details>
  <summary>Podcast Player: [castero](https://github.com/xgi/castero/)</summary>
  I like podcasts, I wanted a TUI, because why run a GUI for something that can be done in a TUI and look good in i3-gaps? Why not Shellcaster? By default Shellcaster opens up a GUI window of VLC to play podcasts while castero doesn't create additional windows.
</details>
