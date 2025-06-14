#!/bin/bash

echo "=== Cross-Platform Build Test ==="
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo

# Check for required tools
check_tool() {
    if command -v $1 >/dev/null 2>&1; then
        echo "✓ $1 found: $(command -v $1)"
    else
        echo "✗ $1 not found"
        return 1
    fi
}

echo "Checking tools..."
check_tool clang
check_tool make
check_tool curl
check_tool xz
echo

# Clean and build
echo "Building..."
make clean
if make; then
    echo
    echo "✓ Build successful!"
    echo
    echo "Generated files:"
    ls -la bin/
    echo
    echo "File information:"
    file bin/* 2>/dev/null || echo "file command not available"
else
    echo
    echo "✗ Build failed!"
    exit 1
fi
