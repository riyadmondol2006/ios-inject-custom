#!/bin/bash
# Save as check_setup.sh

echo "=== iOS Injection Setup Checker ==="
echo

# Check if we're on iOS
if [[ ! -f /System/Library/CoreServices/SystemVersion.plist ]]; then
    echo "❌ Not running on iOS"
    exit 1
fi

# Check jailbreak
if [[ ! -f /usr/bin/cydia ]] && [[ ! -f /usr/bin/sileo ]] && [[ ! -d /var/jb ]]; then
    echo "❌ Device doesn't appear to be jailbroken"
else
    echo "✅ Jailbreak detected"
fi

# Check for Frida
if command -v frida &> /dev/null; then
    echo "✅ Frida CLI found: $(frida --version)"
else
    echo "❌ Frida CLI not found"
fi

# Check Swift runtime
if [[ -d /usr/lib/swift ]]; then
    echo "✅ Swift runtime found"
    ls -la /usr/lib/swift/libswiftCore.dylib 2>/dev/null || echo "  ⚠️  libswiftCore.dylib not accessible"
else
    echo "❌ Swift runtime directory not found"
fi

# Check entitlements
echo
echo "=== Checking binary entitlements ==="
if [[ -f bin/inject ]]; then
    codesign -d --entitlements - bin/inject 2>&1 | grep -E "(task_for_pid|get-task-allow)" || echo "❌ Missing required entitlements"
else
    echo "❌ bin/inject not found - run 'make' first"
fi

echo
echo "=== Environment Variables ==="
echo "DYLD_LIBRARY_PATH: ${DYLD_LIBRARY_PATH:-not set}"
echo "PATH: $PATH"

echo
echo "Done!"
