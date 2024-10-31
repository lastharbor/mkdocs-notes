#!/bin/bash

# Variables
vmid=""
version=""
vm_name=""

echo "############## Start of Script ################"
echo "Checking if temp dir is available..."
if [ -d /root/temp ]; then
    echo "-- Directory exists!"
else
    echo "-- Creating temp dir!"
    mkdir /root/temp
fi

# List available images in /root/temp
echo "== Available Images =="
images=($(ls /root/temp/chr-*.img 2>/dev/null))
if [ ${#images[@]} -eq 0 ]; then
    echo "No images found in /root/temp"
else
    for i in "${!images[@]}"; do
        echo "$((i+1)): ${images[$i]}"
    done
fi

# Ask user for image selection or version input
echo "## Preparing for image download and VM creation!"
echo "You can choose an existing image or input a new CHR version to deploy."
read -p "Enter the number of an existing image (or input a new CHR version): " choice

if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -le ${#images[@]} ]; then
    filename=${images[$((choice-1))]}
    echo "-- Using existing image: $filename"
else
    version=$choice

    # Check if image is available and download if needed
    if [ -f /root/temp/chr-$version.img ]; then
        echo "-- CHR image is available."
        filename="/root/temp/chr-$version.img"
    else
        echo "-- Downloading CHR $version image file."
        cd /root/temp
        echo "---------------------------------------------------------------------------"
        wget https://download.mikrotik.com/routeros/$version/chr-$version.img.zip
        unzip chr-$version.img.zip
        filename="/root/temp/chr-$version.img"
        echo "---------------------------------------------------------------------------"
    fi
fi

# Print list of VMs
echo "== List of VMs =="
qm list
echo ""
read -p "Enter the VM ID to use: " vmid
echo ""
read -p "Enter the VM Name (must be a valid DNS name): " vm_name

# Check and recreate storage for VM if necessary
if [ -d /mnt/pve/large-pool/images/$vmid ]; then
    echo "VM dir exists. Recreating directory..."
    rm -rf /mnt/pve/large-pool/images/$vmid
    mkdir /mnt/pve/large-pool/images/$vmid
else
    echo "Creating VM image dir"
    mkdir /mnt/pve/large-pool/images/$vmid
fi

# Creating qcow2 image
echo "Converting image to qcow2"
qemu-img convert -f raw -O qcow2 "$filename" /mnt/pve/large-pool/images/$vmid/vm-$vmid-disk-1.qcow2

# Create VM
echo "Creating VM"
qm create $vmid --name $vm_name --net0 virtio,bridge=vmbr0 --bootdisk virtio0 --ostype l26 --memory 256 --onboot no --sockets 1 --cores 1 --virtio0 large-pool:$vmid/vm-$vmid-disk-1.qcow2

echo "############## End of Script ##############"
