#!/usr/bin/env bash

log_file="/var/log/installer.log"
log() {
    if [[ ! -d "/var/log" ]]; then
        mkdir -p "/var/log"
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

identify_installation_disk() {
    log "Identifying installation disk"
    echo -e "${GREEN}[*] Identifying installation disk...${RESET}"

    # Run lsblk command and show output
    echo "Running command: lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL

    if [ $? -ne 0 ]; then
        echo "lsblk command failed. Please check your system configuration."
        exit 1
    fi

    # Pause to ensure output is visible
    sleep 2

    echo "Running command: lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL | grep -E 'disk|part'"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL | grep -E 'disk|part'

    if [ $? -ne 0 ]; then
        echo "lsblk + grep command failed. Please check your system configuration."
        exit 1
    fi

    # Pause to ensure output is visible
    sleep 2
}

main() {
    log "Script started"
    identify_installation_disk
    log "Script completed"
}

main
