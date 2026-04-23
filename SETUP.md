# Setup Guide: Scrcpy H.265/HEVC Testing Framework

Complete setup instructions for testing and optimizing scrcpy with H.265 codec on Raspberry Pi 5.

---

## ⚡ 5-Minute Quick Setup

```bash
cd scrcpy-master
./run_tests.sh                      # Verify tests work
./run_tests.sh test_delay_buffer    # Test latency
./run_tests.sh test_io_stream       # Test camera/sensor I/O
```

Expected output:
```
✓ All delay buffer tests passed (H.265/HEVC optimized)!
✓ All I/O tests passed!
Camera H.265/HEVC frames received: 10
Sensor readings received: 23
```

---

## 🔧 Step-by-Step Setup

### Step 1: Build Debug Environment (First Time Only)

```bash
cd scrcpy-master
mkdir -p builddir
cd builddir

# Configure debug build (no optimization, includes symbols, enables logging)
meson .. --buildtype=debug
cd ..
```

### Step 2: Compile Tests

```bash
meson compile -C builddir test_delay_buffer test_io_stream
```

### Step 3: Run Tests

```bash
# Method 1: Using test runner (easiest)
./run_tests.sh

# Method 2: Meson test command
meson test -C builddir

# Method 3: Direct binaries
./builddir/test_delay_buffer
./builddir/test_io_stream
```

---

## 📋 Setup Checklist

- [ ] Git clone complete
- [ ] No build already exists (clean start)
- [ ] Meson installed (`meson --version` shows v0.63+)
- [ ] GCC/Clang available (`gcc --version`)
- [ ] LibAV development files installed
- Debian: `sudo apt install libavutil-dev libavcodec-dev`
- [ ] Run `./run_tests.sh` - all tests pass ✅
- [ ] Test output shows H.265/HEVC references
- [ ] Can modify test file without errors

---

## 🚀 Your Testing Workflow

### 1️⃣ Run Baseline Tests

```bash
./run_tests.sh test_delay_buffer
# Note the output numbers
```

### 2️⃣ Enable Debug Output (Optional)

Edit `app/src/delay_buffer.h`:
```c
// Uncomment to enable debug output
#define SC_BUFFERING_DEBUG
```

### 3️⃣ Make One Small Change

Edit `app/src/delay_buffer.c` around line 65:
```c
// Original:
// sc_tick adjusted_delay = db->delay;

// Optimized (reduce delay by 20%):
sc_tick adjusted_delay = (db->delay * 80) / 100;
```

### 4️⃣ Recompile

```bash
meson compile -C builddir test_delay_buffer
```

### 5️⃣ Test Again

```bash
./run_tests.sh test_delay_buffer
```

Compare outputs - look for:
- Different latency measurements
- No new errors
- Same number of operations

---

## Test Commands Reference

| Command | Purpose |
|---------|---------|
| `./run_tests.sh` | Run all tests |
| `./run_tests.sh test_delay_buffer` | Latency optimization tests |
| `./run_tests.sh test_io_stream` | Camera/sensor I/O tests |
| `meson compile -C builddir` | Rebuild all |
| `meson compile -C builddir test_delay_buffer` | Rebuild one test |
| `meson test -C builddir --verbose` | Run tests with full output |
| `./builddir/test_delay_buffer` | Run test binary directly |

---

## 🛠️ Troubleshooting Setup Issues

### Issue: `meson: command not found`
**Solution:** Install meson
```bash
# Ubuntu/Debian
sudo apt install meson

# Fedora/RedHat
sudo dnf install meson

# macOS
brew install meson
```

### Issue: `error: could not find libavutil.so`
**Solution:** Install FFmpeg development files
```bash
# Ubuntu/Debian
sudo apt install libavutil-dev libavcodec-dev

# Fedora/RedHat
sudo dnf install ffmpeg-devel

# macOS
brew install ffmpeg
```

### Issue: Tests compile but won't run
**Solution:** Check build type
```bash
# Make sure debug build is selected
meson configure builddir --buildtype=debug
meson compile -C builddir
./run_tests.sh
```

### Issue: Permission denied when running `./run_tests.sh`
**Solution:** Make script executable
```bash
chmod +x run_tests.sh
./run_tests.sh
```

---

## 🎯 Raspberry Pi 5 Specific Setup

### Pi 5 System Requirements
- **OS:** Raspberry Pi OS (Bookworm 64-bit recommended)
- **Space:** 2GB (build system)
- **CPU:** Quad-core ARM Cortex-A76
- **RAM:** 4GB+ recommended
- **Video:** HDMI output or V4L2 compatible display

### Pi 5 Installation Steps

```bash
# 1. Update system
sudo raspi-config nonint do_update
sudo apt update && sudo apt upgrade -y

# 2. Install build tools
sudo apt install -y build-essential meson pkg-config

# 3. Install FFmpeg with H.265 support
sudo apt install -y libavutil-dev libavcodec-dev libavformat-dev

# 4. Clone and setup scrcpy
git clone https://github.com/Genymobile/scrcpy.git
cd scrcpy
mkdir builddir && cd builddir
meson .. --buildtype=debug
cd ..

# 5. Run tests
./run_tests.sh
```

### Verify H.265 Hardware Support
```bash
# Check for HEVC decoder on Pi 5
v4l2-ctl --list-devices | grep -i hevc

# Should output something like:
# ...v4l2-ctl: command not found - install with:
sudo apt install v4l2-utils

# Then check:
v4l2-ctl --all | grep -i hevc
```

---

## 📁 Project Files Structure After Setup

```
Device-Fusion-Smartphone-Based-XR-System/
├── README.md                          ← Start here
├── SETUP.md                           ← You are here
├── TESTING.md                         ← Testing details
├── OPTIMIZATION.md                    ← Code optimization
├── REFERENCE.md                       ← Quick reference
├── scrcpy-master/
│   ├── app/
│   │   ├── tests/
│   │   │   ├── test_delay_buffer.c    ← Latency tests
│   │   │   └── test_io_stream.c       ← Camera/sensor tests
│   │   ├── src/
│   │   │   ├── delay_buffer.c         ← Edit for optimization
│   │   │   ├── input_manager.c        ← Control handling
│   │   │   └── ...
│   │   └── meson.build                ← Updated for tests
│   ├── builddir/                      ← Generated during build
│   │   ├── test_delay_buffer          ← Binary
│   │   ├── test_io_stream             ← Binary
│   │   └── ...
│   ├── run_tests.sh                   ← Test runner
│   ├── meson.build
│   └── ...
└── ...
```

---

## ✅ Setup Complete!

You can now:
1. ✅ Run tests without full scrcpy build
2. ✅ Modify delay_buffer.c and test immediately
3. ✅ Test camera/sensor I/O with mock frames
4. ✅ Optimize latency for your use case
5. ✅ Stream H.265/HEVC to Raspberry Pi 5

Next: Read **OPTIMIZATION.md** to start modifying code for your latency targets!
