#!/bin/bash

# TWRP Device Tree Kernel Extraction Script for Retroid Pocket 5 (kona)
# This script extracts kernel and boot parameters from stock images

DEVICE_PATH="device/moorechip/kona"
PREBUILT_DIR="$DEVICE_PATH/prebuilt"

echo "=========================================="
echo "TWRP Kernel Extraction for Retroid Pocket 5"
echo "=========================================="

# Check if required tools are available
check_tools() {
    echo "Checking required tools..."
    
    if ! command -v unpackbootimg &> /dev/null; then
        echo "ERROR: unpackbootimg not found!"
        echo "Please install Android Image Kitchen or build unpackbootimg from AOSP"
        echo "You can get it from: https://github.com/osm0sis/AIK-Linux"
        exit 1
    fi
    
    if ! command -v file &> /dev/null; then
        echo "ERROR: file command not found!"
        exit 1
    fi
    
    echo "✓ Required tools found"
}

# Extract boot image
extract_boot() {
    local img_file="$1"
    local img_type="$2"
    
    if [ ! -f "$img_file" ]; then
        echo "ERROR: $img_file not found!"
        return 1
    fi
    
    echo ""
    echo "Extracting $img_type image: $img_file"
    echo "----------------------------------------"
    
    # Create extraction directory
    local extract_dir="tmp_rovodev_${img_type}_extract"
    mkdir -p "$extract_dir"
    cd "$extract_dir"
    
    # Extract the image
    unpackbootimg -i "../$img_file"
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully extracted $img_type image"
        
        # Display information
        echo ""
        echo "$img_type Image Information:"
        echo "=========================="
        
        if [ -f "${img_file##*/}-kernel" ]; then
            echo "Kernel: Found"
            file "${img_file##*/}-kernel"
            
            # Copy kernel to prebuilt directory
            if [ "$img_type" = "boot" ]; then
                mkdir -p "../$PREBUILT_DIR"
                cp "${img_file##*/}-kernel" "../$PREBUILT_DIR/Image"
                echo "✓ Kernel copied to $PREBUILT_DIR/Image"
            fi
        fi
        
        if [ -f "${img_file##*/}-ramdisk.gz" ]; then
            echo "Ramdisk: Found"
            file "${img_file##*/}-ramdisk.gz"
        fi
        
        if [ -f "${img_file##*/}-dtb" ]; then
            echo "DTB: Found"
            file "${img_file##*/}-dtb"
        fi
        
        # Extract boot parameters
        echo ""
        echo "Boot Parameters:"
        echo "==============="
        
        if [ -f "${img_file##*/}-cmdline" ]; then
            echo "Kernel Command Line:"
            cat "${img_file##*/}-cmdline"
            echo ""
        fi
        
        if [ -f "${img_file##*/}-base" ]; then
            echo "Base Address: $(cat ${img_file##*/}-base)"
        fi
        
        if [ -f "${img_file##*/}-pagesize" ]; then
            echo "Page Size: $(cat ${img_file##*/}-pagesize)"
        fi
        
        if [ -f "${img_file##*/}-kerneloff" ]; then
            echo "Kernel Offset: $(cat ${img_file##*/}-kerneloff)"
        fi
        
        if [ -f "${img_file##*/}-ramdiskoff" ]; then
            echo "Ramdisk Offset: $(cat ${img_file##*/}-ramdiskoff)"
        fi
        
        if [ -f "${img_file##*/}-tagsoff" ]; then
            echo "Tags Offset: $(cat ${img_file##*/}-tagsoff)"
        fi
        
        if [ -f "${img_file##*/}-dtboff" ]; then
            echo "DTB Offset: $(cat ${img_file##*/}-dtboff)"
        fi
        
        if [ -f "${img_file##*/}-hashtype" ]; then
            echo "Hash Type: $(cat ${img_file##*/}-hashtype)"
        fi
        
        if [ -f "${img_file##*/}-osversion" ]; then
            echo "OS Version: $(cat ${img_file##*/}-osversion)"
        fi
        
        if [ -f "${img_file##*/}-oslevel" ]; then
            echo "OS Level: $(cat ${img_file##*/}-oslevel)"
        fi
        
    else
        echo "✗ Failed to extract $img_type image"
        return 1
    fi
    
    cd ..
    echo ""
}

# Generate BoardConfig.mk updates
generate_boardconfig_updates() {
    echo "Generating BoardConfig.mk updates..."
    echo "====================================="
    
    local config_file="tmp_rovodev_boardconfig_updates.txt"
    
    echo "# Updated BoardConfig.mk parameters based on extracted images" > "$config_file"
    echo "# Copy these values to your BoardConfig.mk file" >> "$config_file"
    echo "" >> "$config_file"
    
    # Check boot extraction results
    if [ -d "tmp_rovodev_boot_extract" ]; then
        cd "tmp_rovodev_boot_extract"
        
        if [ -f "boot.img-cmdline" ]; then
            echo "# Kernel Command Line" >> "../$config_file"
            echo "BOARD_KERNEL_CMDLINE := $(cat boot.img-cmdline)" >> "../$config_file"
            echo "" >> "../$config_file"
        fi
        
        if [ -f "boot.img-base" ]; then
            echo "# Boot Image Parameters" >> "../$config_file"
            echo "BOARD_KERNEL_BASE := $(cat boot.img-base)" >> "../$config_file"
        fi
        
        if [ -f "boot.img-pagesize" ]; then
            echo "BOARD_KERNEL_PAGESIZE := $(cat boot.img-pagesize)" >> "../$config_file"
        fi
        
        if [ -f "boot.img-ramdiskoff" ]; then
            echo "BOARD_RAMDISK_OFFSET := $(cat boot.img-ramdiskoff)" >> "../$config_file"
        fi
        
        if [ -f "boot.img-tagsoff" ]; then
            echo "BOARD_KERNEL_TAGS_OFFSET := $(cat boot.img-tagsoff)" >> "../$config_file"
        fi
        
        if [ -f "boot.img-dtboff" ]; then
            echo "BOARD_DTB_OFFSET := $(cat boot.img-dtboff)" >> "../$config_file"
        fi
        
        echo "" >> "../$config_file"
        cd ..
    fi
    
    echo "✓ BoardConfig.mk updates saved to $config_file"
    echo ""
    echo "Contents:"
    echo "--------"
    cat "$config_file"
}

# Main execution
main() {
    check_tools
    
    echo ""
    echo "Place your boot.img and/or recovery.img files in the current directory"
    echo "and run this script to extract kernel and boot parameters."
    echo ""
    
    # Look for image files
    if [ -f "boot.img" ]; then
        extract_boot "boot.img" "boot"
    else
        echo "boot.img not found in current directory"
    fi
    
    if [ -f "recovery.img" ]; then
        extract_boot "recovery.img" "recovery"
    else
        echo "recovery.img not found in current directory"
    fi
    
    # Generate configuration updates
    if [ -d "tmp_rovodev_boot_extract" ] || [ -d "tmp_rovodev_recovery_extract" ]; then
        echo ""
        generate_boardconfig_updates
    fi
    
    echo ""
    echo "=========================================="
    echo "Extraction Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Copy the extracted kernel (Image) to $PREBUILT_DIR/"
    echo "2. Update BoardConfig.mk with the extracted parameters"
    echo "3. Verify partition layout in recovery.fstab"
    echo "4. Test build your TWRP recovery"
    echo ""
    echo "To clean up temporary files, run:"
    echo "rm -rf tmp_rovodev_*"
}

# Run main function
main "$@"