#!/bin/bash

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Test the device path validation
test_device_path() {
    dev_path=$1

    # Debug: Print the device path
    echo "Testing device path: $dev_path"

    # Validate device path
    if [[ ! -b "$dev_path" ]]; then
        log "Invalid device path: $dev_path"
        echo "Invalid device path. Please provide a valid SSD device path."
        exit 1
    else
        echo "Valid device path: $dev_path"
    fi
}

# Example usage
test_device_path "/dev/nvme0n1"
