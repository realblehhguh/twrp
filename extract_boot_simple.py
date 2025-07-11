#!/usr/bin/env python3

import struct
import os
import sys

def extract_boot_img(img_path):
    """Extract boot image components and parameters"""
    
    if not os.path.exists(img_path):
        print(f"Error: {img_path} not found!")
        return False
    
    print(f"Analyzing {img_path}...")
    print("=" * 50)
    
    with open(img_path, 'rb') as f:
        # Read boot image header (first 1648 bytes for Android boot image v0-v2)
        header = f.read(1648)
        
        if len(header) < 1648:
            print("Error: File too small to be a valid boot image")
            return False
        
        # Check magic
        magic = header[:8]
        if magic != b'ANDROID!':
            print("Error: Not a valid Android boot image (magic mismatch)")
            return False
        
        print("✓ Valid Android boot image detected")
        
        # Parse header fields
        kernel_size = struct.unpack('<I', header[8:12])[0]
        kernel_addr = struct.unpack('<I', header[12:16])[0]
        ramdisk_size = struct.unpack('<I', header[16:20])[0]
        ramdisk_addr = struct.unpack('<I', header[20:24])[0]
        second_size = struct.unpack('<I', header[24:28])[0]
        second_addr = struct.unpack('<I', header[28:32])[0]
        tags_addr = struct.unpack('<I', header[32:36])[0]
        page_size = struct.unpack('<I', header[36:40])[0]
        header_version = struct.unpack('<I', header[40:44])[0]
        os_version = struct.unpack('<I', header[44:48])[0]
        
        # Extract name, cmdline, and id
        name = header[48:64].rstrip(b'\x00').decode('ascii', errors='ignore')
        cmdline = header[64:576].rstrip(b'\x00').decode('ascii', errors='ignore')
        id_hash = header[576:608].hex()
        extra_cmdline = header[608:1536].rstrip(b'\x00').decode('ascii', errors='ignore')
        
        # Combine cmdlines
        full_cmdline = cmdline
        if extra_cmdline:
            full_cmdline += " " + extra_cmdline
        
        print(f"Boot Image Information:")
        print(f"  Name: {name}")
        print(f"  Header Version: {header_version}")
        print(f"  OS Version: 0x{os_version:08x}")
        print(f"  Page Size: {page_size}")
        print(f"  Kernel Size: {kernel_size} bytes")
        print(f"  Ramdisk Size: {ramdisk_size} bytes")
        print(f"  Second Size: {second_size} bytes")
        print()
        
        print(f"Memory Addresses:")
        print(f"  Kernel Address: 0x{kernel_addr:08x}")
        print(f"  Ramdisk Address: 0x{ramdisk_addr:08x}")
        print(f"  Second Address: 0x{second_addr:08x}")
        print(f"  Tags Address: 0x{tags_addr:08x}")
        print()
        
        print(f"Kernel Command Line:")
        print(f"  {full_cmdline}")
        print()
        
        # Calculate base address (kernel_addr - 0x00008000 is typical)
        base_addr = kernel_addr - 0x00008000
        kernel_offset = kernel_addr - base_addr
        ramdisk_offset = ramdisk_addr - base_addr
        tags_offset = tags_addr - base_addr
        
        print(f"Calculated Offsets (base: 0x{base_addr:08x}):")
        print(f"  Kernel Offset: 0x{kernel_offset:08x}")
        print(f"  Ramdisk Offset: 0x{ramdisk_offset:08x}")
        print(f"  Tags Offset: 0x{tags_offset:08x}")
        print()
        
        # Extract kernel
        if kernel_size > 0:
            f.seek(page_size)  # Skip header page
            kernel_data = f.read(kernel_size)
            
            kernel_filename = f"{img_path}-kernel"
            with open(kernel_filename, 'wb') as kf:
                kf.write(kernel_data)
            print(f"✓ Kernel extracted to: {kernel_filename}")
            
            # Copy to prebuilt directory if this is boot.img
            if 'boot' in img_path.lower():
                os.makedirs('prebuilt', exist_ok=True)
                with open('prebuilt/Image', 'wb') as pf:
                    pf.write(kernel_data)
                print(f"✓ Kernel copied to: prebuilt/Image")
        
        # Extract ramdisk
        if ramdisk_size > 0:
            # Calculate ramdisk position
            kernel_pages = (kernel_size + page_size - 1) // page_size
            ramdisk_pos = page_size * (1 + kernel_pages)
            
            f.seek(ramdisk_pos)
            ramdisk_data = f.read(ramdisk_size)
            
            ramdisk_filename = f"{img_path}-ramdisk.gz"
            with open(ramdisk_filename, 'wb') as rf:
                rf.write(ramdisk_data)
            print(f"✓ Ramdisk extracted to: {ramdisk_filename}")
        
        # Generate BoardConfig.mk parameters
        config_filename = f"tmp_rovodev_boardconfig_updates.txt"
        with open(config_filename, 'w') as cf:
            cf.write("# Updated BoardConfig.mk parameters based on extracted images\n")
            cf.write("# Copy these values to your BoardConfig.mk file\n\n")
            
            cf.write("# Kernel Command Line\n")
            cf.write(f'BOARD_KERNEL_CMDLINE := {full_cmdline}\n\n')
            
            cf.write("# Boot Image Parameters\n")
            cf.write(f'BOARD_KERNEL_BASE := 0x{base_addr:08x}\n')
            cf.write(f'BOARD_KERNEL_PAGESIZE := {page_size}\n')
            cf.write(f'BOARD_RAMDISK_OFFSET := 0x{ramdisk_offset:08x}\n')
            cf.write(f'BOARD_KERNEL_TAGS_OFFSET := 0x{tags_offset:08x}\n')
            if header_version > 0:
                cf.write(f'BOARD_BOOT_HEADER_VERSION := {header_version}\n')
            cf.write('\n')
            
            cf.write("# Partition Sizes (update these based on your device)\n")
            cf.write(f'BOARD_BOOTIMAGE_PARTITION_SIZE := {os.path.getsize(img_path)}\n')
            if 'recovery' in img_path.lower():
                cf.write(f'BOARD_RECOVERYIMAGE_PARTITION_SIZE := {os.path.getsize(img_path)}\n')
        
        print(f"✓ BoardConfig.mk updates saved to: {config_filename}")
        
        return True

def main():
    print("Android Boot Image Extractor")
    print("=" * 40)
    
    # Look for boot and recovery images
    images_found = []
    
    for img_name in ['boot.img', 'recovery.img', 'boot_a.img', 'recovery_a.img']:
        if os.path.exists(img_name):
            images_found.append(img_name)
    
    if not images_found:
        print("No boot or recovery images found in current directory!")
        print("Please place your boot.img and/or recovery.img files here.")
        return 1
    
    print(f"Found images: {', '.join(images_found)}")
    print()
    
    success = True
    for img in images_found:
        if not extract_boot_img(img):
            success = False
        print()
    
    if success:
        print("=" * 50)
        print("Extraction Complete!")
        print("=" * 50)
        print()
        print("Next steps:")
        print("1. Review tmp_rovodev_boardconfig_updates.txt")
        print("2. Update BoardConfig.mk with the extracted parameters")
        print("3. Run ./analyze_partitions.sh to analyze partition layout")
        print("4. Test build your TWRP recovery")
        print()
        print("To clean up temporary files:")
        print("rm -f *.img-kernel *.img-ramdisk.gz tmp_rovodev_*")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())