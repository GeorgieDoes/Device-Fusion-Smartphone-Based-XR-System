# Reference Guide: H.265/HEVC Quick Commands & Technical Details

Quick reference for commands, H.265 codec specifications, and technical implementation details.

---

## ⚡ Quick Commands

### Run Tests
```bash
cd scrcpy-master

# Run all tests
./run_tests.sh

# Run specific test
./run_tests.sh test_delay_buffer
./run_tests.sh test_io_stream

# Direct binary execution
./builddir/test_delay_buffer
./builddir/test_io_stream
```

### Build & Compile
```bash
# Initial setup (first time only)
cd scrcpy-master
meson setup builddir --buildtype=debug

# Rebuild after code changes
meson compile -C builddir

# Rebuild specific test
meson compile -C builddir test_delay_buffer

# Clean rebuild
meson setup --wipe builddir --buildtype=debug && meson compile -C builddir
```

### Stream to Raspberry Pi 5
```bash
# List connected devices
adb devices

# Stream with H.265 codec
./builddir/scrcpy --video-codec=h265 --device <device_id>

# Stream with H.265 + specific resolution
./builddir/scrcpy --video-codec=h265 -m 720 --device <device_id>

# Stream with H.265 + 30fps
./builddir/scrcpy --video-codec=h265 --fps 30 --device <device_id>
```

### Debug & Profiling
```bash
# Run tests with verbose output
meson test -C builddir --verbose

# Check for memory leaks
valgrind ./builddir/test_delay_buffer

# Enable debug logging
# Edit app/src/delay_buffer.h and uncomment: #define SC_BUFFERING_DEBUG
```

---

## 🎥 H.265/HEVC Codec Overview

### What is H.265/HEVC?

**H.265** (also called **HEVC** - High Efficiency Video Coding)

**Latest video compression standard:**
- Approved: 2013 (ITU-T & ISO)
- Current version: 2016
- Status: Industry standard

**Replaces:** H.264/AVC (from 2003)

---

## 📊 H.265 vs H.264 Comparison

| Feature | H.264 | H.265/HEVC |
|---------|-------|-----------|
| **Compression** | 1.0x (baseline) | 1.4-1.5x (40-50% better) |
| **File Size** | 100MB | 50-60MB (same quality) |
| **CPU Usage** | 100% | 50-60% (on Pi 5) |
| **Bitrate** | 5000 kbps | 2500-3000 kbps (720p/30fps) |
| **Quality** | Good | Excellent |
| **Adoption** | Mature | Growing fast |
| **License** | Patent pool | Patent pool (different) |

### Real-World Example (720p @ 30fps)

**H.264:**
- Bitrate: 5000 kbps
- File/min: 37.5 MB
- CPU: 60-70% on Pi 5

**H.265:**
- Bitrate: 2500-3000 kbps (40-50% reduction)
- File/min: 18-22 MB
- CPU: 30-40% on Pi 5

---

## 🔧 Technical Details

### H.265 Codec Features

**Main Tool Set:**
- **Larger block sizes** (up to 64x64 vs H.264's 16x16)
- **Better entropy coding** (CABAC only, no CAVLC)
- **Advanced motion prediction**
- **Transform improvements** (DST for low bitrates)

**Benefits for Streaming:**
- Lower bandwidth consumption
- Maintains quality at lower bitrates
- Tolerates network jitter better
- Better for mobile/wireless

### H.265 NAL Units (for testing)

**NAL unit types used in testing:**

| Type | Hex | Name | Purpose |
|------|-----|------|---------|
| 32 | 0x40 | VPS | Video Parameter Set |
| 33 | 0x42 | SPS | Sequence Parameter Set |
| 34 | 0x44 | PPS | Picture Parameter Set |
| 19 | 0x4C | IDR | Instantaneous Decoder Refresh |
| 1 | 0x02 | Slice | Regular frame data |

**In Frame Headers:**
```
H.265 frame starts with: [0x00, 0x00, 0x00, 0x01]
Followed by NAL unit: [0x40] (VPS), [0x42] (SPS), [0x44] (PPS), [0x4C] (IDR)
```

---

## 🍓 Raspberry Pi 5 Hardware Support

### CPU Specifications
- **Processor:** Broadcom BCM2712
- **Cores:** 4x ARM Cortex-A76 @ 2.4 GHz
- **GPU:** VideoCore VII
- **RAM:** 4GB (with 8GB option)

### H.265 Decoder (Hardware)
- **Standard:** HEVC (H.265)
- **Max Resolution:** 4K @ 60fps
- **Decode Speed:** 60fps @ 720p
- **Acceleration:** v4l2m2m (Video4Linux2 Memory-to-Memory)
- **CPU Impact:** ~5-10% when active (rest offloaded to GPU)

### Enable H.265 on Pi 5
```bash
# 1. Verify on Pi:
v4l2-ctl --list-devices | grep -i hevc

# 2. Build with hardware support
cd scrcpy-master
meson setup builddir --buildtype=release -Dc_args='-DHAVE_V4L2_CODEC'

# 3. Verify in code
./builddir/scrcpy --list-codecs | grep -i h265
```

---

## 💾 Memory & CPU Budget (Pi 5 @ 720p/30fps)

### Memory Allocation
```
Frame buffers (8 frames):      ~50 MB
Decoder buffer:               ~20 MB
Sensor data buffers:          ~5 MB
Audio buffers:                ~10 MB
Scrcpy overhead:              ~15 MB
System/other:                 3+ GB available
───────────────────────────
Total used:                   ~100 MB (out of 4GB)
Available:                    ~3.9 GB
```

### CPU Budget
```
H.265 decode (hardware):      5-10%
Scrcpy processing:            10-15%
Sensor I/O handling:          2-5%
Network/USB:                  5-10%
Display update:               2-3%
───────────────────────────
Total estimated:              30-45%
Available:                    55-70%
```

### Thermal Management
- Idle: 25-35°C
- Decoding 720p/30fps: 45-55°C
- Maximum safe: 85°C
- Thermal throttle: 85°C+
- No cooling needed for streaming

---

## 🎯 Performance Targets Summary

### Scrcpy with H.265 on Pi 5

**720p @ 30fps (Main target):**
- Bitrate: 2500-3000 kbps
- Latency: 50-60ms
- CPU load: 35-45%
- Quality: Excellent
- **Status: ✅ Recommended**

**1080p @ 30fps:**
- Bitrate: 4000-5000 kbps
- Latency: 80-100ms
- CPU load: 50-60%
- Quality: Excellent
- **Status: ✅ Supported**

**480p @ 30fps:**
- Bitrate: 1500-1800 kbps
- Latency: 40-50ms
- CPU load: 25-30%
- Quality: Very Good
- **Status: ✅ Best for 4G**

---

## 🔀 Stream Configuration Examples

### Low Latency (Real-time)
```bash
# Minimize delays and buffering
./builddir/scrcpy \
  --video-codec=h265 \
  --bit-rate=2500 \
  --fps 30 \
  -m 720 \
  --lock-video-orientation=0 \
  --device <id>

# Expected latency: 50-60ms
```

### High Quality (Local Network)
```bash
# Prioritize quality over latency
./builddir/scrcpy \
  --video-codec=h265 \
  --bit-rate=5000 \
  --fps 30 \
  -m 1080 \
  --device <id>

# Expected latency: 80-100ms
```

### Mobile 4G (Optimized)
```bash
# Optimize for cellular bandwidth
./builddir/scrcpy \
  --video-codec=h265 \
  --bit-rate=1800 \
  --fps 24 \
  -m 480 \
  --device <id>

# Expected latency: 40-60ms (varies with network)
```

---

## 📚 File Locations Reference

### Test Framework
```
scrcpy-master/
├── app/tests/
│   ├── test_delay_buffer.c      ← Latency optimization tests
│   └── test_io_stream.c         ← Camera/sensor I/O tests
├── run_tests.sh                 ← Test runner script
└── builddir/
    ├── test_delay_buffer        ← Compiled binary
    └── test_io_stream           ← Compiled binary
```

### Code to Modify
```
scrcpy-master/app/src/
├── delay_buffer.c/h             ← Latency optimization
├── frame_buffer.c/h             ← Frame buffering
├── input_manager.c/h            ← Input/sensor handling
├── decoder.c/h                  ← H.265 decoding
├── display.c/h                  ← Output rendering
└── ...other files...
```

### Build Configuration
```
scrcpy-master/
├── meson.build                  ← Main build config
├── app/meson.build              ← App-specific config
└── app/tests/meson.build        ← Test configuration (auto-generated)
```

---

## 🔍 Codec Selection Logic

**When to use H.265:**
- ✅ 720p/30fps streaming
- ✅ Limited bandwidth (< 5Mbps)
- ✅ Raspberry Pi 5 target
- ✅ Long-duration recordings
- ✅ Battery-constrained devices

**When to use H.264:**
- ✅ Legacy device support
- ✅ Real-time encoding (CPU limited)
- ✅ Older Pi versions (Pi 3, 4)
- ✅ Maximum compatibility

**Hybrid Approach (H.265 + H.264 fallback):**
```c
// In scrcpy code:
if (device_supports_h265 && pi_version >= 5) {
    use_codec = HEVC;  // H.265
} else {
    use_codec = H264;  // Fallback
}
```

---

## 🐛 Troubleshooting Reference

### H.265 Not Working
```bash
# 1. Check if hardware decoder available
ffmpeg -codecs | grep hevc

# 2. Verify Pi 5 library
dpkg -l | grep libavcodec

# 3. Try software decoder (slow)
./builddir/scrcpy --video-codec=h265 -m 360
```

### High Latency (>150ms)
1. Check CPU load: `top` while streaming
2. Check network: `ping <device>`
3. Reduce resolution: `-m 480` or `-m 360`
4. Reduce fps: `--fps 24`

### Test Failures
1. Recompile: `meson compile -C builddir`
2. Check dependencies: `meson test -C builddir --verbose`
3. Clear cache: `rm -rf builddir && meson setup builddir --buildtype=debug`

---

## 📖 Documentation Map

| File | Purpose | Best For |
|------|---------|----------|
| **README.md** | Overview & quick start | First-time users |
| **SETUP.md** | Installation & configuration | Getting the system running |
| **TESTING.md** | Test framework details | Understanding the tests |
| **OPTIMIZATION.md** | Code optimization | Reducing latency |
| **REFERENCE.md** | Commands & technical specs | Quick lookup |

---

## ✅ All References Complete!

Keep this file bookmarked for:
- Command copy-paste
- H.265 technical details
- Performance specifications
- Troubleshooting tips
- File locations

Next: Choose your path from **README.md** or jump to **OPTIMIZATION.md** to start optimizing!
