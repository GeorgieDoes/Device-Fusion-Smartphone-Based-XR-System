# Scrcpy H.265/HEVC Testing Framework for Raspberry Pi 5

**Complete testing framework for optimizing scrcpy delay and supporting camera/sensor input/output with H.265 codec.**

**2 Functional Test Files**
- `app/tests/test_delay_buffer.c` - Latency optimization (8 tests)
- `app/tests/test_io_stream.c` - Camera & sensor I/O (8 tests)

**Test Framework**
- `run_tests.sh` - Easy test runner
- Integrated with Meson build system
- H.265/HEVC optimized for Pi 5

---

## Quick Start

```bash
cd scrcpy-master
./run_tests.sh                      # Run all tests
./run_tests.sh test_delay_buffer    # Test latency
./run_tests.sh test_io_stream       # Test camera/sensor I/O
```

Expected output:
```
✓ All delay buffer tests passed (H.265/HEVC optimized)!
✓ All I/O tests passed!
```

---

## Documentation

| Path | Time | What to Read |
|------|------|--------------|
| ** Quick Start** | 5 min | Run commands above |
| ** Setup** | 30 min | `SETUP.md` |
| ** Testing** | 1 hour | `TESTING.md` |
| ** Optimization** | 2 hours | `OPTIMIZATION.md` |
| ** Reference** | As needed | `REFERENCE.md` |

---

## H.265/HEVC Key Benefits

- **40-50% better compression** than H.264
- **50% lower CPU usage** on Raspberry Pi 5
- **Hardware decoder support** (v4l2m2m acceleration)
- **Target: 40-60ms latency** @ 720p/30fps

---

## Project Structure

```
scrcpy-master/
├── app/
│   ├── tests/
│   │   ├── test_delay_buffer.c      ← Latency tests
│   │   └── test_io_stream.c         ← Camera/sensor tests
│   ├── src/
│   │   ├── delay_buffer.c/h         ← Edit for optimization
│   │   ├── input_manager.c/h        ← Control message handling
│   │   └── ...
│   └── meson.build                  ← Updated for tests
├── run_tests.sh                     ← Test runner
└── builddir/ (generated)            ← Compiled output
```

---

##  What Tests Cover

### Delay Buffer Tests (test_delay_buffer.c)
- Delay calculation accuracy
- First frame timing
- Queue initialization
- Latency measurements
- Multiple delay scenarios
- Clock synchronization
- Buffer overhead
- State transitions

### I/O Stream Tests (test_io_stream.c)  
- Camera frame input (H.265/HEVC)
- 3 sensor types (accelerometer, gyroscope, compass)
- Display output rendering
- End-to-end latency
- Concurrent input streams
- Data integrity validation
- High-frequency frame handling (30fps)
- Output queue management

---

## How to Use

### Run Tests
```bash
./run_tests.sh                          # All tests
./run_tests.sh test_delay_buffer        # Latency only
./run_tests.sh test_io_stream           # Camera/sensor only
```

### Modify Code & Test
```bash
# Edit app/src/delay_buffer.c or app/src/input_manager.c
# Then recompile:
meson compile -C builddir
# And test again:
./run_tests.sh
```

### Stream to Raspberry Pi 5
```bash
./builddir/scrcpy --video-codec=h265 --device <device_id>
```

---

## Documentation Files

- **SETUP.md** - Complete setup, checklist, and troubleshooting
- **TESTING.md** - Testing framework details and I/O testing
- **OPTIMIZATION.md** - Latency optimization strategies and examples
- **REFERENCE.md** - Commands, H.265 details, quick tips

---

No additional setup needed. Tests compile and run in **debug mode without full scrcpy build**.

Next steps:
1. Run `cd scrcpy-master && ./run_tests.sh` to verify
2. Read `REFERENCE.md` for quick commands
3. Read `OPTIMIZATION.md` to start modifying code
4. Read `TESTING.md` for camera/sensor I/O details

Enjoy optimizing scrcpy for H.265 streaming on your Raspberry Pi 5! 🎯
