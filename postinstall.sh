sudo pacman -Syu dialog

### Scelta del desktop environment ###
de_choice=$(dialog --stdout --menu "Scegli un Desktop Environment" 0 0 0 \
"xfce4" "XFCE4 - Ambiente desktop leggero e veloce" \
"gnome" "GNOME - Ambiente desktop moderno e pulito" \
"kde" "KDE Plasma - Ambiente desktop ricco e personalizzabile") || exit 1
clear

de_install_type=$(dialog --stdout --menu "Scegli il tipo di installazione per $de_choice" 0 0 0 \
"Full" "Installazione completa" \
"Minimal" "Installazione minimale") || exit 1
clear

# sudo pacman custom config
#Add ParallelDownloads under [options]
sudo sed -i '/\[options\]/a ParallelDownloads = 10' /etc/sudo pacman.conf
#Add ILoveCandy under [options]
sudo sed -i '/\[options\]/a ILoveCandy' /etc/sudo pacman.conf
#Add Color under [options]
sudo sed -i '/\[options\]/a Color' /etc/sudo pacman.conf
#Enable [multilib]
sudo sed -i '/#\[multilib\]/,/#include = \/etc\/sudo pacman.d\/mirrorlist/ s/^#//' /etc/sudo pacman.conf

# Xorg keyboard layout configuration
sudo mkdir -p /etc/X11/xorg.conf.d/
sudo echo 'Section "InputClass"' > /etc/X11/xorg.conf.d/10-keyboard.conf
sudo echo '        Identifier "system-keyboard"' >> /etc/X11/xorg.conf.d/10-keyboard.conf
sudo echo '        MatchIsKeyboard "on"' >> /etc/X11/xorg.conf.d/10-keyboard.conf
sudo echo '        Option "XkbLayout" "it"' >> /etc/X11/xorg.conf.d/10-keyboard.conf
sudo echo 'EndSection' >> /etc/X11/xorg.conf.d/10-keyboard.conf

install_DE() {

    ### Installazione pacchetti DE
    # Xfce4
    if [[ "$de_choice" == "xfce4" ]]; then
        if [[ "$de_install_type" == "full" ]]; then
            sudo pacman -Sy xfce4 xfce4-goodies lightdm lightdm-gtk-greeter amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
            ### Configurazione lightdm per XFCE ###
            sudo echo "[greeter]" > /etc/lightdm/lightdm-gtk-greeter.conf
            sudo echo "theme-name = Adwaita" >> /etc/lightdm/lightdm-gtk-greeter.conf
            sudo echo "icon-theme-name = Adwaita" >> /etc/lightdm/lightdm-gtk-greeter.conf
            sudo echo "background = /usr/share/backgrounds/xfce/xfce-shapes.svg" >> /etc/lightdm/lightdm-gtk-greeter.conf
        else
            sudo pacman -Sy xfce4 lightdm lightdm-gtk-greeter amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
        fi
        sudo systemctl enable lightdm
    fi
    # Gnome
    if [[ "$de_choice" == "gnome" ]]; then
        if [[ "$de_install_type" == "full" ]]; then
            sudo pacman -Sy gnome gnome-extra gnome-tweaks gdm amd-ucode nano pipewire git xf86-video-amdgpu bash-completion man-db man cups xdg-utils xdg-user-dirs mesa tlp acpid openssh bluez bluez-utils --needed --noconfirm
        else
            sudo pacman -Sy gnome gdm amd-ucode nano pipewire git xf86-video-amdgpu bash-completion man-db man cups xdg-utils xdg-user-dirs mesa tlp acpid openssh bluez bluez-utils --needed --noconfirm
        fi
        sudo systemctl enable gdm
        #sudo -u $user bash -c "dbus-launch gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'it')]\""

    fi
    # Kde plasma
    if [[ "$de_choice" == "kde" ]]; then
        if [[ "$de_install_type" == "full" ]]; then
            sudo pacman -Sy plasma-meta plasma-wayland-session kde-applications sddm amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
        else
            sudo pacman -Sy plasma-desktop plasma-wayland-session sddm amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
        fi
        sudo systemctl enable sddm
        #arch-chroot /mnt sudo -u $user bash -c "kwriteconfig5 --file kdeglobals --group Input\ Devices --key XkbLayout it"

    fi
}

#install_additional_packages() {

 #   sudo pacman -Syu amd-ucode nano grub pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
#}

enable_services() {
    sudo systemctl enable bluetooth
    sudo systemctl enable sshd
    sudo systemctl enable tlp
    sudo systemctl enable fstrim.timer
    sudo systemctl enable acpid
}

git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
rm -rf paru

paru -S --noconfirm mullvadvpn jellyfin-media-player librewolf-bin ttf-mf ttf-mf-fonts discord_arch_electron logseq_desktop_bin ttf-google-fonts-git tutanota-desktop

# Funzione per chiedere all'utente se riavviare o tornare al TTY
scegli_azione() {
    # Mostra la finestra di dialogo
    dialog --title "Riavvio sistema" \
           --backtitle "Opzioni post-installazione" \
           --yesno "Vuoi riavviare il sistema? (No per tornare al TTY)" 7 60

    # Controlla l'uscita di dialog
    case $? in
        0)  # Sì è stato premuto
            sudo echo "Riavvio del sistema..."
            reboot
            ;;
        1)  # No è stato premuto
            sudo echo "Tornando al TTY..."
            # lo script terminerà e l'utente tornerà al TTY
            ;;
        255) # ESC è stato premuto
            sudo echo "[ESC] chiave premuta. Tornando al TTY..."
            # Anche qui, lo script terminerà e l'utente tornerà al TTY
            ;;
    esac
}


install_DE
enable_services
scegli_azione
