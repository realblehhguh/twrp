#!/bin/bash

# Partition Analysis Script for Retroid Pocket 5 (kona)
# This script helps analyze partition layout from various sources

echo "=========================================="
echo "Partition Analysis for Retroid Pocket 5"
echo "=========================================="

# Function to analyze recovery ramdisk for fstab
analyze_recovery_ramdisk() {
    echo ""
    echo "Analyzing Recovery Ramdisk for fstab..."
    echo "======================================"
    
    if [ ! -d "tmp_rovodev_recovery_extract" ]; then
        echo "No recovery extraction found. Run extract_kernel.sh first."
        return 1
    fi
    
    cd tmp_rovodev_recovery_extract
    
    if [ -f "recovery.img-ramdisk.gz" ]; then
        echo "Extracting recovery ramdisk..."
        
        # Create ramdisk extraction directory
        mkdir -p ramdisk_extract
        cd ramdisk_extract
        
        # Extract ramdisk
        gunzip -c ../recovery.img-ramdisk.gz | cpio -i 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✓ Recovery ramdisk extracted"
            
            # Look for fstab files
            echo ""
            echo "Looking for fstab files..."
            find . -name "*fstab*" -type f
            
            # Look for recovery.fstab specifically
            if [ -f "system/etc/recovery.fstab" ]; then
                echo ""
                echo "Found recovery.fstab:"
                echo "===================="
                cat system/etc/recovery.fstab
            elif [ -f "etc/recovery.fstab" ]; then
                echo ""
                echo "Found recovery.fstab:"
                echo "===================="
                cat etc/recovery.fstab
            fi
            
            # Look for other fstab files
            for fstab_file in $(find . -name "*fstab*" -type f); do
                if [[ "$fstab_file" != *"recovery.fstab"* ]]; then
                    echo ""
                    echo "Found additional fstab: $fstab_file"
                    echo "=================================="
                    cat "$fstab_file"
                fi
            done
            
        else
            echo "✗ Failed to extract recovery ramdisk"
        fi
        
        cd ..
    fi
    
    cd ..
}

# Function to check for partition information in kernel cmdline
analyze_cmdline() {
    echo ""
    echo "Analyzing Kernel Command Line..."
    echo "==============================="
    
    for extract_dir in tmp_rovodev_boot_extract tmp_rovodev_recovery_extract; do
        if [ -d "$extract_dir" ]; then
            cd "$extract_dir"
            
            if [ -f "*.img-cmdline" ]; then
                cmdline_file=$(ls *.img-cmdline 2>/dev/null | head -1)
                if [ -f "$cmdline_file" ]; then
                    echo ""
                    echo "Command line from $extract_dir:"
                    echo "$(cat $cmdline_file)"
                    
                    # Look for partition-related parameters
                    echo ""
                    echo "Partition-related parameters:"
                    grep -o 'androidboot\.[^[:space:]]*' "$cmdline_file" | grep -E '(slot|partition|super)'
                fi
            fi
            
            cd ..
        fi
    done
}

# Function to generate partition size recommendations
generate_partition_recommendations() {
    echo ""
    echo "Partition Size Recommendations..."
    echo "==============================="
    
    cat << 'EOF'
Based on typical Qualcomm devices, here are recommended partition sizes:

# Boot/Recovery partitions (typically 64MB or 100MB)
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864        # 64MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864    # 64MB

# Or for larger partitions:
BOARD_BOOTIMAGE_PARTITION_SIZE := 104857600       # 100MB  
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600   # 100MB

# Super partition (adjust based on your device's actual size)
# Common sizes: 6GB, 8GB, 9GB, 12GB
BOARD_SUPER_PARTITION_SIZE := 9126805504          # ~8.5GB
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 9122611200   # Super size - 4MB

To find your actual partition sizes:
1. Boot into fastboot mode
2. Run: fastboot getvar all | grep partition-size
3. Or check /proc/partitions on a rooted device
4. Or use: cat /proc/cmdline | grep androidboot.super_partition.size

EOF
}

# Function to create a partition extraction script
create_partition_script() {
    echo ""
    echo "Creating partition extraction helper script..."
    echo "============================================="
    
    cat > tmp_rovodev_get_partitions.sh << 'EOF'
#!/bin/bash

# Helper script to get partition information
# Run this on your device (requires root) or in ADB shell

echo "=== Partition Information ==="

echo ""
echo "1. Partition sizes from /proc/partitions:"
echo "========================================"
cat /proc/partitions

echo ""
echo "2. Block device links:"
echo "===================="
ls -la /dev/block/bootdevice/by-name/ 2>/dev/null || ls -la /dev/block/by-name/ 2>/dev/null

echo ""
echo "3. Super partition info (if available):"
echo "======================================"
if [ -f /sys/class/block/dm-0/size ]; then
    echo "Dynamic partition detected"
    ls -la /dev/block/mapper/
fi

echo ""
echo "4. Mount points:"
echo "==============="
mount | grep -E "(system|vendor|product|odm)"

echo ""
echo "5. Kernel command line:"
echo "======================"
cat /proc/cmdline

EOF

    chmod +x tmp_rovodev_get_partitions.sh
    echo "✓ Created tmp_rovodev_get_partitions.sh"
    echo "  You can push this to your device and run it to get partition info"
}

# Main function
main() {
    # Analyze extracted images
    analyze_recovery_ramdisk
    analyze_cmdline
    
    # Generate recommendations
    generate_partition_recommendations
    
    # Create helper script
    create_partition_script
    
    echo ""
    echo "=========================================="
    echo "Analysis Complete!"
    echo "=========================================="
    echo ""
    echo "Summary of generated files:"
    echo "- tmp_rovodev_get_partitions.sh: Run on device to get partition info"
    echo ""
    echo "Next steps:"
    echo "1. Review any extracted fstab files above"
    echo "2. Run tmp_rovodev_get_partitions.sh on your device if possible"
    echo "3. Update recovery.fstab with correct partition paths"
    echo "4. Update BoardConfig.mk with correct partition sizes"
}

# Run main function
main "$@"