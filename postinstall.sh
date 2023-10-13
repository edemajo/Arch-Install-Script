pacman -Syu dialog

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

# Pacman custom config
#Add ParallelDownloads under [options]
sed -i '/\[options\]/a ParallelDownloads = 10' /mnt/etc/pacman.conf
#Add ILoveCandy under [options]
sed -i '/\[options\]/a ILoveCandy' /mnt/etc/pacman.conf
#Add Color under [options]
sed -i '/\[options\]/a Color' /mnt/etc/pacman.conf
#Enable [multilib]
sudo sed -i '/#\[multilib\]/,/#include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

# Xorg keyboard layout configuration
mkdir -p /mnt/etc/X11/xorg.conf.d/
echo 'Section "InputClass"' > /mnt/etc/X11/xorg.conf.d/10-keyboard.conf
echo '        Identifier "system-keyboard"' >> /mnt/etc/X11/xorg.conf.d/10-keyboard.conf
echo '        MatchIsKeyboard "on"' >> /mnt/etc/X11/xorg.conf.d/10-keyboard.conf
echo '        Option "XkbLayout" "it"' >> /mnt/etc/X11/xorg.conf.d/10-keyboard.conf
echo 'EndSection' >> /mnt/etc/X11/xorg.conf.d/10-keyboard.conf

install_DE() {

    ### Installazione pacchetti DE
    # Xfce4
    if [[ "$de_choice" == "xfce4" ]]; then
        if [[ "$de_install_type" == "full" ]]; then
            arch-chroot /mnt pacman -Sy xfce4 xfce4-goodies lightdm lightdm-gtk-greeter amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
            ### Configurazione lightdm per XFCE ###
            echo "[greeter]" > /mnt/etc/lightdm/lightdm-gtk-greeter.conf
            echo "theme-name = Adwaita" >> /mnt/etc/lightdm/lightdm-gtk-greeter.conf
            echo "icon-theme-name = Adwaita" >> /mnt/etc/lightdm/lightdm-gtk-greeter.conf
            echo "background = /usr/share/backgrounds/xfce/xfce-shapes.svg" >> /mnt/etc/lightdm/lightdm-gtk-greeter.conf
        else
            arch-chroot /mnt pacman -Sy xfce4 lightdm lightdm-gtk-greeter amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
        fi
        arch-chroot /mnt systemctl enable lightdm
    fi
    # Gnome
    if [[ "$de_choice" == "gnome" ]]; then
        if [[ "$de_install_type" == "full" ]]; then
            arch-chroot /mnt pacman -Sy gnome gnome-extra gnome-tweaks gdm amd-ucode nano pipewire git xf86-video-amdgpu bash-completion man-db man cups xdg-utils xdg-user-dirs mesa tlp acpid openssh bluez bluez-utils --needed --noconfirm
        else
            arch-chroot /mnt pacman -Sy gnome gdm amd-ucode nano pipewire git xf86-video-amdgpu bash-completion man-db man cups xdg-utils xdg-user-dirs mesa tlp acpid openssh bluez bluez-utils --needed --noconfirm
        fi
        arch-chroot /mnt systemctl enable gdm
        #arch-chroot /mnt sudo -u $user bash -c "dbus-launch gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'it')]\""

    fi
    # Kde plasma
    if [[ "$de_choice" == "kde" ]]; then
        if [[ "$de_install_type" == "full" ]]; then
            arch-chroot /mnt pacman -Sy plasma-meta plasma-wayland-session kde-applications sddm amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
        else
            arch-chroot /mnt pacman -Sy plasma-desktop plasma-wayland-session sddm amd-ucode nano pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
        fi
        arch-chroot /mnt systemctl enable sddm
        #arch-chroot /mnt sudo -u $user bash -c "kwriteconfig5 --file kdeglobals --group Input\ Devices --key XkbLayout it"

    fi
}

#install_additional_packages() {

 #   arch-chroot /mnt pacman -Syu amd-ucode nano grub pipewire sudo git vim xf86-video-amdgpu bash-completion man-db man network-manager-applet dialog wpa_supplicant cups xdg-utils xdg-user-dirs mesa xorg xorg-server tlp acpid openssh bluez bluez-utils --needed --noconfirm
#}

enable_services() {
    arch-chroot /mnt systemctl enable bluetooth
    arch-chroot /mnt systemctl enable sshd
    arch-chroot /mnt systemctl enable tlp
    arch-chroot /mnt systemctl enable fstrim.timer
    arch-chroot /mnt systemctl enable acpid
}

git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm

sudo pacman -S
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
            echo "Riavvio del sistema..."
            reboot
            ;;
        1)  # No è stato premuto
            echo "Tornando al TTY..."
            # lo script terminerà e l'utente tornerà al TTY
            ;;
        255) # ESC è stato premuto
            echo "[ESC] chiave premuta. Tornando al TTY..."
            # Anche qui, lo script terminerà e l'utente tornerà al TTY
            ;;
    esac
}


install_DE
enable_services
scegli_azione