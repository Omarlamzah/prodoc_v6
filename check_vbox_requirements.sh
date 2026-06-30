#!/bin/bash

# Check VirtualBox macOS Requirements
# This script checks if your system can run macOS in VirtualBox

echo "=========================================="
echo "VirtualBox macOS Requirements Check"
echo "=========================================="
echo ""

# Check VirtualBox
echo "📦 Checking VirtualBox..."
if command -v VBoxManage &> /dev/null; then
    VBOX_VERSION=$(VBoxManage --version)
    echo "✅ VirtualBox installed: $VBOX_VERSION"
else
    echo "❌ VirtualBox not found"
    echo "   Install: sudo apt install virtualbox"
    exit 1
fi

# Check CPU virtualization
echo ""
echo "🔧 Checking CPU virtualization support..."
if lscpu | grep -qi "Virtualization"; then
    VIRT_TYPE=$(lscpu | grep -i "Virtualization" | awk '{print $2}')
    echo "✅ Virtualization supported: $VIRT_TYPE"
else
    echo "⚠️  Virtualization support not detected"
    echo "   Check BIOS settings for AMD-V or Intel VT-x"
fi

# Check RAM
echo ""
echo "💾 Checking RAM..."
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "   Total RAM: ${TOTAL_RAM}GB"

if [ "$TOTAL_RAM" -ge 16 ]; then
    echo "✅ Excellent! Can allocate 8-12GB to VM"
    RECOMMENDED_RAM=8192
elif [ "$TOTAL_RAM" -ge 8 ]; then
    echo "✅ Good! Can allocate 4-6GB to VM"
    RECOMMENDED_RAM=4096
else
    echo "⚠️  Low RAM. macOS VM needs at least 4GB"
    RECOMMENDED_RAM=4096
fi

# Check disk space
echo ""
echo "💿 Checking disk space..."
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
echo "   Available space: ${AVAILABLE_SPACE}GB"

if [ "${AVAILABLE_SPACE//[!0-9]/}" -ge 50 ]; then
    echo "✅ Sufficient space for macOS VM (50GB+ recommended)"
else
    echo "⚠️  Low disk space. macOS needs ~50GB"
fi

# Check CPU cores
echo ""
echo "⚙️  Checking CPU..."
CPU_CORES=$(nproc)
echo "   CPU cores: $CPU_CORES"

if [ "$CPU_CORES" -ge 4 ]; then
    echo "✅ Good! Can allocate 2-4 cores to VM"
    RECOMMENDED_CORES=4
elif [ "$CPU_CORES" -ge 2 ]; then
    echo "✅ OK! Can allocate 2 cores to VM"
    RECOMMENDED_CORES=2
else
    echo "⚠️  Only 1 core available. VM will be very slow"
    RECOMMENDED_CORES=1
fi

# Summary
echo ""
echo "=========================================="
echo "📋 Recommended VM Settings:"
echo "=========================================="
echo "   RAM: ${RECOMMENDED_RAM}MB"
echo "   CPU Cores: ${RECOMMENDED_CORES}"
echo "   Disk: 50GB+ (dynamically allocated)"
echo "   Video Memory: 128MB"
echo ""

# Check for existing macOS VM
echo "🔍 Checking for existing macOS VM..."
EXISTING_VMS=$(VBoxManage list vms | grep -i "macos" || echo "")
if [ -n "$EXISTING_VMS" ]; then
    echo "✅ Found existing macOS VM:"
    echo "$EXISTING_VMS"
    echo ""
    echo "💡 To start it:"
    echo "   VBoxManage startvm \"<VM_NAME>\" --type gui"
else
    echo "ℹ️  No macOS VM found yet"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Get macOS ISO (see VBOX_DOCKER_IOS_GUIDE.md)"
    echo "   2. Create VM in VirtualBox GUI"
    echo "   3. Run: ./setup_vbox_macos.sh"
fi

echo ""
echo "=========================================="
echo "⚠️  Important Notes:"
echo "=========================================="
echo "   • macOS in VirtualBox violates Apple ToS"
echo "   • Performance will be 30-50% slower"
echo "   • Setup can take 2-4 hours"
echo "   • Consider Codemagic/GitHub Actions for easier setup"
echo ""

