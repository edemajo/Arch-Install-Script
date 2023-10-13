#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Devi eseguire questo script come root."
   exit 1
fi

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR



#!/bin/bash

clear
echo ""
echo "                  ================================================================== "   
echo "                 |                       AUTOMATIC INSTALLATION                     |"  
echo "                 |                            ARCH LINUX                            |"     
echo "                 |                                                                  |"    
echo "                  ==================================================================="      
echo "                 |                                                                  |"     
echo "                 |    Welcome! This script was created to simplify and automate     |"     
echo "                 |    the installation of Arch Linux, ensuring a consistent and     |"   
echo "                 |    hassle-free experience.                                       |"     
echo "                 |                                                                  |"
echo "                 |    Before proceeding, ensure you have a stable internet          |"    
echo "                 |    connection and have backed up all your data.                  |"     
echo "                 |                                                                  |"     
echo "                 |    WARNING: This script will ERASE ALL DATA on the target drive! |"     
echo "                 |    BACKUP all crucial data before continuing!                    |"     
echo "                 |                                                                  |"     
echo "                  ================================================================== "  
echo ""

read -p " >>>   Press [ENTER] to continue or CTRL+C to exit: "
 
### Scelta mirror più veloci con reflector e dialog ###
reflector --download-timeout 20 --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist

pacman-key --init
pacman-key --populate archlinux
pacman -Syy
pacman -S dialog --noconfirm
loadkeys it
timedatectl set-ntp true

### Get information from user with dialog ###
nome=$(dialog --stdout --inputbox "Inserisci il tuo nome" 0 0) || exit 1
clear

cognome=$(dialog --stdout --inputbox "Inserisci il tuo cognome" 0 0) || exit 1
clear

hostname=$(dialog --stdout --inputbox "Inserisci hostname" 0 0) || exit 1
clear
: ${hostname:?"Devi inserire l'hostname"}

user=$(dialog --stdout --inputbox "Inserisci nome utente sudoer" 0 0) || exit 1
clear
: ${user:?"Devi inserire il nome utente"}

password=$(dialog --stdout --passwordbox "Inserisci password" 0 0) || exit 1
clear
: ${password:?"Devi inserire la password"}
password2=$(dialog --stdout --passwordbox "Reinserisci la password" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Le password non corrispondono"; exit 1; )

dialog --colors --msgbox '\Zb\ATTENZIONE IL DISCO SCELTO VERRÀ FORMATTATO, TUTTI I FILE IN ESSO CONTENUTI VERRANNO CANCELLATI' 7 30

# Scelta del disco
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Seleziona il disco di installazione" 0 0 0 ${devicelist}) || exit 1
clear

### Scelta filesystem
filesystem=$(dialog --stdout --menu "Scegli il filesystem" 0 0 0 "ext4" "" "btrfs" "Supporta snapshots") || exit 1
clear

# Ottieni ulteriori dettagli sul dispositivo selezionato con lsblk
device_info=$(lsblk -o name,size $device -n)
device_name=$(echo $device_info | awk '{print $1}')
device_size=$(echo $device_info | awk '{print $2}')

# Dialog di conferma con dettagli aggiuntivi
dialog --colors \
    --title "Conferma la scelta del disco" \
    --yesno "\Zb\Z1ATTENZIONE\Zn\n\nStai per formattare il disco selezionato. Ecco alcuni dettagli:\n\nDispositivo: $device_name\nDimensione: $device_size\nFilesystem selezionato: $filesystem\n\nSei sicuro di voler procedere?" 20 60 || exit 1
clear

### Scelta del kernel ###
kernel_choice=$(dialog --stdout --menu "Scegli un kernel" 0 0 0 \
"linux" "Kernel standard" \
"linux-lts" "Kernel a lungo termine" \
"linux-zen" "Kernel ottimizzato per performance desktop" \
"linux-hardened" "Kernel con patch di sicurezza") || exit 1
clear



# Dialog timezone
zones=$(find /usr/share/zoneinfo/ -type f -not -path '*/right/*' -not -path '*/posix/*' | sed 's@.*/usr/share/zoneinfo/@@' | sort)

options=()

for zone in $zones; do
    options+=("$zone" "" off)
done
chosen_timezone=$(dialog --radiolist "Seleziona il fuso orario:" 22 76 16 "${options[@]}" 2>&1 >/dev/tty)
clear

#### Locale dialog
# Extract all commented locales from /etc/locale.gen and format for dialog with a number as the key
locales=$(grep "^#.*UTF-8" /etc/locale.gen | sed 's/#//;s/ UTF-8//' | awk '{print NR, $1}')

# Use dialog to get the user's choice
chosen_locale_key=$(dialog --clear \
                --title "Select your locale" \
                --menu "Choose one of the available locales:" \
                15 50 10 \
                ${locales} \
                2>&1 >/dev/tty)
#}

dialog --infobox "                    Installazione in corso...     " 10 40 &

### Output rediretto al file install.log
#exec > /mnt/install.log 2>&1

partitioning() {
    ### Setup the disk and partitions ###
    swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
    swap_end=$(( swap_size + 512 + 1 ))MiB  # Updated from 129 to 512

    # Fixed the mkpart lines
    parted --script "${device}" mklabel gpt \
        mkpart ESP fat32 1MiB 512MiB \
        set 1 boot on \
        mkpart primary linux-swap 512MiB "${swap_end}" \
        mkpart primary "${filesystem}" "${swap_end}" 100%

    part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
    part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"
    part_root="$(ls ${device}* | grep -E "^${device}p?3$")"

    wipefs "${part_boot}"
    wipefs "${part_swap}"
    wipefs "${part_root}"

    case "$filesystem" in
        ext4)
            mkfs.ext4 -F "${part_root}"
            ;;
        btrfs)
            mkfs.btrfs "${part_root}"
            ;;
    esac

    if [[ "$filesystem" == "btrfs" ]]; then
        mkfs.vfat -F32 "${part_boot}"
        mkswap "${part_swap}"
        mount "${part_root}" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@snapshots
        umount /mnt
        mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@ "${part_root}" /mnt
        mkdir -p /mnt/{boot,home,.snapshots}
        mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@home "${part_root}" /mnt/home
        mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@snapshots "${part_root}" /mnt/.snapshots
        mount "${part_boot}" /mnt/boot
        swapon "${part_swap}"
    else
        mkfs.vfat -F32 "${part_boot}"
        mkswap "${part_swap}"
        mount "${part_root}" /mnt
        mkdir -p /mnt/boot  # Added mkdir before mount
        mount "${part_boot}" /mnt/boot  # Changed --mkdir to mkdir -p /mnt/boot
        swapon "${part_swap}"
    fi
}

base_system() {
        
    ### Install and configure the basic system ###
    pacstrap -K /mnt base $kernel_choice $kernel_choice-headers $kernel_choice-docs linux-firmware efibootmgr grub networkmanager 

    genfstab -U /mnt >> /mnt/etc/fstab

    #enter chroot
    arch-chroot /mnt

    echo "${hostname}" > /etc/hostname
    echo "127.0.0.1	localhost" >> /etc/hosts
    echo "::1	localhost" >> /etc/hosts
    echo "127.0.1.1	${hostname}.localdomain	${hostname}" >> /etc/hosts

    ### Timezone ###
    if [ -n "$chosen_timezone" ]; then
        ln -sf "/usr/share/zoneinfo/$chosen_timezone" /etc/localtime
         hwclock --systohc
    else
        echo "Nessun fuso orario selezionato."
    fi

    # Get the corresponding locale from the list
    chosen_locale=$(echo "${locales}" | awk -v key="${chosen_locale_key}" '$1 == key {print $2}')

    # Check if user pressed Cancel
    if [ $? -eq 1 ]; then
        echo "Locale selection cancelled."
        exit 1
    fi

    # Uncomment the chosen locale in /etc/locale.gen
    sed -i "s/^#${chosen_locale}/${chosen_locale}/" /etc/locale.gen
    # Generate the locale
    locale-gen

    # Set the system's locale
    if [[ ${chosen_locale} == *.UTF-8 ]]; then
        localectl set-locale LANG=${chosen_locale}
    else
        localectl set-locale LANG=${chosen_locale}.UTF-8
    fi

    # Imposta la configurazione della tastiera per la console
    echo "KEYMAP=it" > /etc/vconsole.conf

    useradd -mG wheel $user

    ### Fornisce al DE nome e cognome completo dell'utente
    usermod -c "$nome $cognome" $user

    mkinitcpio -P

    # Imposta le password usando il comando passwd
    echo -e "$password\n$password" | passwd "$user"
    echo -e "$password\n$password" | passwd root
    echo "$user:$password" | chpasswd --root
    echo "root:$password" | chpasswd --root
    ### Aggiunge l'utente ai sudoers
    echo "$user ALL=(ALL) ALL" > /etc/sudoers.d/$user

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    systemctl enable NetworkManager  
}

### restituisce l'output al terminale
#exec &>/dev/tty

########def reboot
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

# Call to the functions
partitioning
base_system
scegli_azione
