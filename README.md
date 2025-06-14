# ios-inject-custom

Cross-platform iOS injection example using [Frida](https://frida.re). This project demonstrates how to inject a custom dynamic library (`agent.dylib`) into a running iOS process using Frida's low-level APIs.

✅ **Builds on macOS and Linux**
✅ **Supports Frida 17.1.5**
✅ **Swift runtime support**
✅ **Mock builds on Linux (for testing only)**
✅ **Improved error handling and diagnostics**

---

## 📦 Features

* Hooks `open()` and logs file access from the target process
* Uses Frida Gum to implement the hook
* Works on modern iOS versions (14.0+)
* Automatically resolves Swift runtime issues (`@rpath/libswift*.dylib`)
* Platform-aware `Makefile` (macOS: real build, Linux: mock binaries)

---

## 🛠️ Requirements

### macOS

* Xcode with iOS SDK
* Jailbroken iOS device (for testing)

### Linux

* `clang`, `make`, `curl`, `xz-utils`
* No iOS SDK required (builds mock binaries)

---

## 🚀 Build Instructions

### macOS

```bash
make clean
make
```

### Linux

```bash
sudo apt install clang build-essential curl xz-utils
make clean
make
```

### Test Build

```bash
chmod +x test-build.sh
./test-build.sh
```

---

## 📂 Project Structure

```
ios-inject-custom/
├── Makefile           # Cross-platform build system
├── agent.c            # Hook logic using Gum
├── inject.c           # Injector logic using frida-core
├── victim.c           # Test target (calls open())
├── inject.xcent       # iOS entitlements (only used on macOS)
├── test-build.sh      # Build verification script
├── COPYING.txt        # License (Public Domain)
└── README.md          # This file
```

---

## 🧪 How It Works

1. `victim` runs in a loop and calls `open()` on system files
2. `inject` uses Frida's injector APIs to inject `agent.dylib`
3. `agent.dylib` hooks `open()` and logs all calls to `stderr`

---

## 🔗 Deployment (iOS Device)

```bash
# Copy binaries to your jailbroken iOS device
scp -r bin/ root@<device-ip>:/var/root/ios-inject-example
```

---

## ✅ Runtime Example

```bash
# Terminal 1 on device
cd /var/root/ios-inject-example
./victim
# Victim running with PID 1234

# Terminal 2 on device
./inject 1234
# [+] Agent loaded successfully
# [+] Successfully hooked open()
# [YYYY-MM-DD HH:MM:SS] open("/etc/hosts", 0x0)
```

---

## 🧰 Troubleshooting

### Common Issues

| Error                                 | Solution                                                      |
| ------------------------------------- | ------------------------------------------------------------- |
| `@rpath/libswiftCore.dylib` not found | Automatically fixed by Makefile using `install_name_tool`     |
| `xcrun` not found                     | Only needed on macOS. Ignored on Linux                        |
| `lipo`, `codesign` not found          | Used on macOS. Skipped on Linux                               |
| `Injection failed`                    | Make sure the process exists and has appropriate entitlements |

---

## 📜 License

This software is released into the public domain. See `COPYING.txt`.

---

