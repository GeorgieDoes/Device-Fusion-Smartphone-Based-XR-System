# Quick Reference: Scrcpy Testing Setup

## TL;DR - Get Started Now

```bash
cd scrcpy-master
./run_tests.sh                      # Run all tests
./run_tests.sh test_delay_buffer    # Test delay optimization
./run_tests.sh test_io_stream       # Test camera/sensor I/O
```

---

## 5-Minute Setup

### 1. First Time Only - Build Debug Environment
```bash
cd /home/jojo/Documents/Device-Fusion-Smartphone-Based-XR-System/scrcpy-master
meson setup builddir --buildtype=debug
```

### 2. Run Tests Anytime
```bash
./run_tests.sh                      # All tests
./run_tests.sh test_delay_buffer    # Just delay buffer
./run_tests.sh test_io_stream       # Just I/O streams
```

### 3. Expected Output (Success)
```
✓ All delay buffer tests passed!
✓ All I/O tests passed!
```

---

## What Was Set Up For You

### 📁 New Test Files Created
- `app/tests/test_delay_buffer.c` - Tests for latency optimization
- `app/tests/test_io_stream.c` - Tests for camera & sensor input/output
- `run_tests.sh` - Easy test runner script

### 📄 Documentation Files Created  
- `TESTING_SETUP.md` - Complete testing guide
- `DELAY_OPTIMIZATION.md` - How to optimize for low latency
- `CAMERA_SENSOR_TESTING.md` - How to test camera and sensor inputs
- `CODE_OPTIMIZATION_EXAMPLES.md` - Specific code changes to try

### ⚙️ Modified Files
- `app/meson.build` - Registered new tests

---

## Your Testing Workflow

### Step 1: Run Baseline Tests
```bash
./run_tests.sh test_delay_buffer
# Note output numbers
```

### Step 2: Enable Debug Output
Edit `app/src/delay_buffer.h`, find and uncomment:
```c
#define SC_BUFFERING_DEBUG
```

### Step 3: Make One Small Change
Edit `app/src/delay_buffer.c`

Example - reduce delay by 20%:
```c
// Find this line around line 65:
sc_tick adjusted_delay = (db->delay * 80) / 100;  // Was: db->delay
```

### Step 4: Recompile & Test
```bash
meson compile -C builddir
./run_tests.sh test_delay_buffer
```

### Step 5: Check Results
Look for:
- Latency measurement changes
- No new errors
- Same number of operations

---

## Test Commands Reference

| Command | Purpose |
|---------|---------|
| `./run_tests.sh` | Run all tests |
| `./run_tests.sh test_delay_buffer` | Latency optimization |
| `./run_tests.sh test_io_stream` | Camera/sensor input |
| `meson compile -C builddir test_delay_buffer` | Rebuild one test |
| `meson test -C builddir --verbose test_delay_buffer` | See full output |

---

## Files You'll Work With

### For Delay Optimization
- `app/src/delay_buffer.c` - Main buffering logic
- `app/src/clock.c` - Timing calculations  
- `app/tests/test_delay_buffer.c` - Tests

### For Camera/Sensor Input
- `app/src/input_manager.c` - Handle inputs
- `app/src/decoder.c` - Decode camera frames
- `app/src/display.c` - Render output
- `app/tests/test_io_stream.c` - Tests

---

## Common Tasks

### "I want to run tests"
```bash
./run_tests.sh
```

### "I want to test only delay buffer"
```bash
./run_tests.sh test_delay_buffer
```

### "I want to test camera/sensor"
```bash
./run_tests.sh test_io_stream
```

### "I broke something"
```bash
git checkout app/src/delay_buffer.c    # Undo changes
meson compile -C builddir              # Rebuild
./run_tests.sh test_delay_buffer       # Test again
```

### "I want to see exact timings"
```bash
# Uncomment debug in app/src/delay_buffer.h:
#define SC_BUFFERING_DEBUG

# Recompile and run:
meson compile -C builddir
./run_tests.sh test_delay_buffer 2>&1 | grep -i timing
```

### "I want to change latency values"
Edit `app/src/delay_buffer.c`, around line 65:
```c
sc_tick adjusted_delay = (db->delay * PERCENT) / 100;  // Change PERCENT
```

---

## Testing with Real Android Device

After tests pass:

```bash
# 1. Connect device
adb devices

# 2. Build
meson compile -C builddir

# 3. Run scrcpy normally
./builddir/scrcpy -m720

# 4. Observe
# - Is video responsive?
# - Any lag on touch input?
# - Any glitches/stuttering?
```

---

## Optimization Ideas to Try

### Idea 1: Less Buffering (20% faster)
```c
// In delay_buffer.c around line 65:
sc_tick adjusted_delay = (db->delay * 80) / 100;
```

### Idea 2: Skip Late Frames (More responsive)
```c
// In delay_buffer.c around line 95:
if (now > frame_deadline + SC_TICK_FROM_MS(10)) {
    // Skip frame that's already late
    continue;
}
```

### Idea 3: Faster First Frame (Better startup)
```c
// In delay_buffer.c, set first_frame_asap:
sc_delay_buffer_init(&db, delay, true);  // Was: false
```

---

## Help & Debugging

### Tests Don't Compile
```bash
# 1. Check meson.build has your tests registered
cat app/meson.build | grep test_delay_buffer

# 2. Make sure you're in debug mode
meson setup builddir --buildtype=debug

# 3. Clean and rebuild
rm -rf builddir
meson setup builddir --buildtype=debug
meson compile -C builddir
```

### Tests Show Errors  
```bash
# 1. Run with verbose output
./run_tests.sh test_delay_buffer --verbose

# 2. Check for assertion failures
grep -i "assert\|error\|failed" test_output.log

# 3. Revert last change
git diff app/src/delay_buffer.c  # See what changed
git checkout app/src/delay_buffer.c  # Revert
```

### Latency Still Too High
- Check you enabled debug: `#define SC_BUFFERING_DEBUG`
- Try larger reduction: 80% → 70% → 60%
- Test on a real device, not just unit tests

---

## File Organization

```
scrcpy-master/
├── app/
│   ├── src/
│   │   ├── delay_buffer.c ...................... (EDIT: Line 65+ for optimization)
│   │   ├── clock.c ............................ (Reference for timing)
│   │   └── display.c .......................... (Output rendering)
│   ├── tests/
│   │   ├── test_delay_buffer.c ................ (NEW: Latency tests)
│   │   └── test_io_stream.c ................... (NEW: Camera/sensor tests)
│   └── meson.build ............................ (MODIFIED: Test registration)
├── run_tests.sh ............................. (NEW: Easy test runner)
└── [other files]

DOCUMENTATION/
├── TESTING_SETUP.md ......................... (Complete guide)
├── DELAY_OPTIMIZATION.md .................... (Latency tuning)
├── CAMERA_SENSOR_TESTING.md ................. (I/O testing)
└── CODE_OPTIMIZATION_EXAMPLES.md ............ (Specific code changes)
```

---

## What Happens When You Run Tests

```
1. test_delay_buffer.c compiles with delay_buffer.c code
2. All tests in test_delay_buffer.c() run sequentially
3. Each test verifies one aspect:
   - Delay calculation ✓
   - First frame handling ✓
   - Queue operations ✓
   - Latency measurement ✓
4. If any assertion fails → error shown
5. All pass → "All tests passed!"

Similarly for test_io_stream.c with camera/sensor mocking
```

---

## Performance Impact Expectations

| Change | Latency Impact | Risk Level |
|--------|---|---|
| Reduce delay 10% | -10ms | Low ✅ |
| Reduce delay 20% | -20ms | Low-Med ⚠️ |
| Skip late frames | -50ms | High ❌ |
| Reduce lock time | -5ms | Med ⚠️ |
| Enable aggressive clock | -15ms | High ❌ |

Start with low-risk changes first!

---

## Success Metrics

After optimization, on a real device you should see:
- ✅ Faster touch response
- ✅ Smoother video playback
- ✅ Lower frame latency (< 50ms)
- ✅ Less audio sync drift
- ⚠️ Maybe occasional stutters (acceptable trade-off)

---

## Next Steps

1. **Right now:**
   ```bash
   ./run_tests.sh               # Verify setup works
   ```

2. **First optimization:**
   - Read `CODE_OPTIMIZATION_EXAMPLES.md`
   - Try Optimization 1 (Reduce buffering delay)
   - Change AGGRESSIVE_FACTOR from 100 to 80
   - Test and measure

3. **Integration:**
   - Connect real Android device
   - Run optimized scrcpy
   - Compare latency before/after

4. **Advanced:**
   - Try multiple optimizations
   - Measure performance metrics
   - Profile CPU usage
   - Test camera input

---

## Emergency Revert

If everything breaks:
```bash
cd scrcpy-master
git status                           # See what changed
git checkout .                       # Undo ALL changes
rm -rf builddir                      # Clean
meson setup builddir --buildtype=debug
./run_tests.sh test_delay_buffer    # Verify it works again
```

---

## Questions?

1. **Check the docs first:**
   - `TESTING_SETUP.md` - How tests work
   - `CODE_OPTIMIZATION_EXAMPLES.md` - What code to change
   - `DELAY_OPTIMIZATION.md` - Full troubleshooting guide

2. **Run tests with verbose output:**
   ```bash
   ./run_tests.sh test_delay_buffer --verbose
   ```

3. **Check build logs:**
   ```bash
   meson test -C builddir --verbose test_delay_buffer
   ```

---

## You're Ready! 🚀

Start testing:
```bash
cd scrcpy-master
./run_tests.sh
```

That's it! Your testing infrastructure is ready to go.
