#!/bin/bash

# TWRP Build Script for Retroid Pocket 5 (kona)

DEVICE="kona"
VENDOR="moorechip"
DEVICE_PATH="device/$VENDOR/$DEVICE"

echo "=========================================="
echo "TWRP Build Script for Retroid Pocket 5"
echo "=========================================="

# Check if we're in TWRP source root
check_environment() {
    echo "Checking build environment..."
    
    if [ ! -f "build/envsetup.sh" ]; then
        echo "ERROR: Not in TWRP source root directory!"
        echo "Please run this script from your TWRP source root."
        exit 1
    fi
    
    if [ ! -d "$DEVICE_PATH" ]; then
        echo "ERROR: Device tree not found at $DEVICE_PATH"
        echo "Please ensure the device tree is properly placed."
        exit 1
    fi
    
    if [ ! -f "$DEVICE_PATH/prebuilt/Image" ]; then
        echo "WARNING: Kernel Image not found at $DEVICE_PATH/prebuilt/Image"
        echo "Please extract your kernel using extract_kernel.sh first."
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo "✓ Environment check passed"
}

# Setup build environment
setup_environment() {
    echo ""
    echo "Setting up build environment..."
    echo "=============================="
    
    # Source build environment
    source build/envsetup.sh
    
    # Choose lunch target
    echo "Selecting lunch target: twrp_${DEVICE}-eng"
    lunch twrp_${DEVICE}-eng
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to lunch twrp_${DEVICE}-eng"
        echo "Check your device tree configuration."
        exit 1
    fi
    
    echo "✓ Build environment ready"
}

# Clean previous builds
clean_build() {
    echo ""
    echo "Cleaning previous builds..."
    echo "=========================="
    
    # Clean recovery image
    rm -f out/target/product/${DEVICE}/recovery.img
    rm -f out/target/product/${DEVICE}/boot.img
    
    # Clean intermediate files
    make clean -j$(nproc) 2>/dev/null
    
    echo "✓ Clean completed"
}

# Build recovery
build_recovery() {
    echo ""
    echo "Building TWRP recovery..."
    echo "========================"
    
    # Build recovery image
    make recoveryimage -j$(nproc)
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ Build successful!"
        echo ""
        echo "Recovery image location:"
        echo "out/target/product/${DEVICE}/recovery.img"
        
        # Check if file exists and show size
        if [ -f "out/target/product/${DEVICE}/recovery.img" ]; then
            ls -lh "out/target/product/${DEVICE}/recovery.img"
            
            # Copy to device tree for easy access
            cp "out/target/product/${DEVICE}/recovery.img" "$DEVICE_PATH/twrp-${DEVICE}-$(date +%Y%m%d).img"
            echo "✓ Recovery copied to: $DEVICE_PATH/twrp-${DEVICE}-$(date +%Y%m%d).img"
        fi
        
    else
        echo ""
        echo "✗ Build failed!"
        echo ""
        echo "Common issues and solutions:"
        echo "1. Missing kernel: Run extract_kernel.sh to get kernel Image"
        echo "2. Wrong partition sizes: Check BoardConfig.mk partition sizes"
        echo "3. Missing dependencies: Ensure all TWRP dependencies are installed"
        echo "4. Syntax errors: Check device tree makefiles for syntax issues"
        
        exit 1
    fi
}

# Show build information
show_build_info() {
    echo ""
    echo "=========================================="
    echo "Build Information"
    echo "=========================================="
    echo "Device: $DEVICE"
    echo "Vendor: $VENDOR"
    echo "Device Tree: $DEVICE_PATH"
    echo "Build Date: $(date)"
    echo "Build User: $(whoami)"
    echo "Build Host: $(hostname)"
    echo ""
    
    if [ -f "out/target/product/${DEVICE}/recovery.img" ]; then
        echo "Recovery Image:"
        echo "  Path: out/target/product/${DEVICE}/recovery.img"
        echo "  Size: $(stat -c%s out/target/product/${DEVICE}/recovery.img 2>/dev/null || echo 'Unknown') bytes"
        echo "  MD5: $(md5sum out/target/product/${DEVICE}/recovery.img 2>/dev/null | cut -d' ' -f1 || echo 'Unknown')"
    fi
}

# Flash instructions
show_flash_instructions() {
    echo ""
    echo "=========================================="
    echo "Flashing Instructions"
    echo "=========================================="
    echo ""
    echo "Method 1: Fastboot (Recommended)"
    echo "--------------------------------"
    echo "1. Boot device to fastboot mode"
    echo "2. Connect device to computer"
    echo "3. Flash recovery:"
    echo "   fastboot flash recovery out/target/product/${DEVICE}/recovery.img"
    echo "4. Boot to recovery:"
    echo "   fastboot boot out/target/product/${DEVICE}/recovery.img"
    echo ""
    echo "Method 2: ADB (if root available)"
    echo "--------------------------------"
    echo "1. Push recovery to device:"
    echo "   adb push out/target/product/${DEVICE}/recovery.img /sdcard/"
    echo "2. Flash using dd (requires root):"
    echo "   adb shell su -c 'dd if=/sdcard/recovery.img of=/dev/block/bootdevice/by-name/recovery'"
    echo ""
    echo "IMPORTANT: Always backup your original recovery first!"
    echo "fastboot getvar all > device_info.txt"
    echo "fastboot boot twrp.img  # Test before flashing permanently"
}

# Main execution
main() {
    case "$1" in
        "clean")
            check_environment
            setup_environment
            clean_build
            ;;
        "build")
            check_environment
            setup_environment
            build_recovery
            show_build_info
            show_flash_instructions
            ;;
        "rebuild")
            check_environment
            setup_environment
            clean_build
            build_recovery
            show_build_info
            show_flash_instructions
            ;;
        *)
            echo "Usage: $0 {clean|build|rebuild}"
            echo ""
            echo "Commands:"
            echo "  clean   - Clean previous builds"
            echo "  build   - Build TWRP recovery"
            echo "  rebuild - Clean and build TWRP recovery"
            echo ""
            echo "Example: $0 build"
            exit 1
            ;;
    esac
}

# Run main function with arguments
main "$@"