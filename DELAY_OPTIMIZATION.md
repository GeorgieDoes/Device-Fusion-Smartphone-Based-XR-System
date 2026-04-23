# Delay Optimization Testing Guide

This guide explains how to modify and test the scrcpy delay buffer for latency optimization.

## Quick Start

### 1. Build and Run All Tests
```bash
cd scrcpy-master
chmod +x run_tests.sh
./run_tests.sh
```

### 2. Run Only Delay Buffer Tests
```bash
./run_tests.sh test_delay_buffer
```

### 3. Run Only I/O Stream Tests (Camera/Sensor)
```bash
./run_tests.sh test_io_stream
```

---

## Understanding Delay Buffer Architecture

### Key Files:
- `app/src/delay_buffer.h` - Delay buffer interface
- `app/src/delay_buffer.c` - Delay buffer implementation
- `app/src/clock.c` - Clock synchronization
- `app/tests/test_delay_buffer.c` - Unit tests

### The Challenge:
Scrcpy must balance:
- **Low latency** (want <35ms)
- **Frame continuity** (don't drop frames)
- **Bandwidth** (don't buffer too long)

Currently: 35-70ms latency (from README)
Goal: Optimize to consistently <50ms

---

## Optimization Workflow

### Step 1: Enable Debug Output
In `app/src/delay_buffer.h`, uncomment:
```c
#define SC_BUFFERING_DEBUG // uncomment to debug
```

This enables timestamped logging of:
- Frame push time
- Frame pop time
- Buffer depth
- Timing accuracy

### Step 2: Make a Code Change
Example: Reduce buffer hold time
```c
// In app/src/delay_buffer.c, adjust:
sc_tick deadline = sc_clock_to_system_time(&db->clock, pts) + db->delay;

// OLD: Strict delay adherence
// NEW: More aggressive rendering (reduce delay by 10%)
sc_tick adjusted_delay = (db->delay * 9) / 10;
sc_tick deadline = sc_clock_to_system_time(&db->clock, pts) + adjusted_delay;
```

### Step 3: Test the Change
```bash
# Recompile
meson compile -C builddir

# Run test
./run_tests.sh test_delay_buffer
```

### Step 4: Measure Results
Look for in output:
- "Delay calculation test" - verifies delay was set
- "Latency measurement" - actual timing
- "Buffer overhead" - performance impact

Example output:
```
✓ Delay calculation test passed (100ms delay set)
✓ Latency measurement test passed (delay: 100000µs)
✓ Buffer overhead test passed (1000 iterations in 1234µs)
```

---

## Modification Examples for Different Optimization Goals

### Goal 1: Reduce Buffering Latency

**File:** `app/src/delay_buffer.c`

**Change:** Make deadline more aggressive
```c
// BEFORE
sc_tick deadline = sc_clock_to_system_time(&db->clock, pts) + db->delay;

// AFTER - reduce wait time
sc_tick deadline = sc_clock_to_system_time(&db->clock, pts) + (db->delay * 3 / 4);
```

**Test:**
```bash
./run_tests.sh test_delay_buffer
# Check: "Latency measurement test" should show smaller time
```

---

### Goal 2: Improve Queue Performance

**File:** `app/src/delay_buffer.c`

**Change:** Optimize queue locking
```c
// BEFORE - hold mutex during full wait
sc_mutex_lock(&db->mutex);
while (!db->stopped && !timed_out) {
    timed_out = !sc_cond_timedwait(&db->wait_cond, &db->mutex, deadline);
}
sc_mutex_unlock(&db->mutex);

// AFTER - more efficient critical section
sc_mutex_lock(&db->mutex);
// quick check only
if (!db->stopped && !timed_out) {
    sc_mutex_unlock(&db->mutex);
    // sleep outside lock
    // re-acquire for verification
}
```

**Test:**
```bash
./run_tests.sh test_delay_buffer
# Check: "Buffer overhead test" - should be faster with multiple iterations
```

---

### Goal 3: Optimize for Sensor/Camera Streams

**File:** `app/src/delay_buffer.c`

**Change:** Adaptive delay based on source
```c
// Add at start of run_buffering():
bool is_camera_stream = strstr(db->name, "camera") != NULL;
sc_tick adaptive_delay = db->delay;

if (is_camera_stream) {
    // Camera streams can have lower latency
    adaptive_delay = (db->delay * 70) / 100;  // 30% faster
}

// Use adaptive_delay instead of db->delay
sc_tick deadline = sc_clock_to_system_time(&db->clock, pts) + adaptive_delay;
```

**Test:**
```bash
./run_tests.sh test_io_stream
# Check: "End-to-end latency test" - should be lower for camera input
```

---

## Testing with Real Devices

Once unit tests pass, test with real Android device:

### 1. Connect device
```bash
adb devices
```

### 2. Build with debug
```bash
cd scrcpy-master
meson setup builddir --buildtype=debug
meson compile -C builddir
```

### 3. Run with debug output
```bash
./builddir/scrcpy -m1024 2>&1 | grep -i "buffering\|latency\|clock"
```

This will show real timing measurements.

---

## Performance Monitoring

### Enable All Debug Flags

Edit `app/src/common.h` and add:
```c
#define SC_DEBUG_DELAY_BUFFER
#define SC_DEBUG_FRAME_TIMING
#define SC_BUFFERING_DEBUG
#define SC_DEBUG_DECODER_TIMING
```

### Monitor During Tests

```bash
# Run test with pipe to grep
./run_tests.sh test_delay_buffer 2>&1 | tee test_output.log

# Analyze results
grep "latency\|delay\|timing" test_output.log
```

---

## Optimization Metrics to Track

| Metric | How to Measure | Target |
|--------|----------------|--------|
| **Frame delay** | Timestamps in debug output | <50ms |
| **Queue depth** | Log queue size | 1-3 frames |
| **Clock drift** | PTS vs system time | <5% error |
| **Thread overhead** | Buffer overhead test time | <5ms per 1000 ops |
| **First frame latency** | Time from push to display | <100ms |

---

## Modifying Test to Match Your Optimization

### Example: Test Faster Rendering

Edit `app/tests/test_delay_buffer.c`:
```c
static void test_optimized_latency(void) {
    struct sc_delay_buffer db;
    
    // OLD delay
    sc_tick old_delay = SC_TICK_FROM_MS(100);
    sc_delay_buffer_init(&db, old_delay, false);
    
    // NEW reduced delay
    sc_tick new_delay = SC_TICK_FROM_MS(75);  // 25% faster
    
    // Run test with both...
    LOGI("Old latency: 100ms");
    LOGI("New latency: 75ms");
    LOGI("Improvement: 25%");
}
```

---

## Common Optimization Pitfalls

### ❌ Problem: Buffer Underrun
- **Symptom:** Flickering when reducing delay too much
- **Check:** Is queue becoming empty?
- **Fix:** Don't reduce delay below minimum (usually 20-30ms)

### ❌ Problem: High CPU Usage
- **Symptom:** System gets hot, battery drains
- **Check:** Profile thread overhead
- **Fix:** Reduce locking or use lock-free queue

### ❌ Problem: Sync Issues
- **Symptom:** Audio/video out of sync
- **Check:** Clock drift in debug output
- **Fix:** Don't mess with sc_clock_to_system_time()

### ✅ Solution: Incremental Changes
- Change ONE parameter at a time
- Run tests between changes
- Measure with real device
- Roll back if performance degrades

---

## Scripts for Batch Testing

### Run multiple test scenarios
```bash
#!/bin/bash
for delay in 50 75 100 125 150; do
    DELAY=$delay ./run_tests.sh test_delay_buffer
    echo "---"
done
```

### Compare before/after
```bash
echo "=== BEFORE ===" > results.txt
./run_tests.sh test_delay_buffer >> results.txt
echo "=== AFTER ===" >> results.txt
./run_tests.sh test_delay_buffer >> results.txt
diff results.txt
```

---

## Next Steps

1. **Run tests** - `./run_tests.sh` to verify setup works
2. **Enable debug** - Uncomment SC_BUFFERING_DEBUG in delay_buffer.h
3. **Make small change** - Reduce delay by 10-20%
4. **Test** - Run test suite
5. **Measure** - Check latency improvements
6. **Integrate** - Test with real Android device
7. **Iterate** - Repeat with different optimizations

---

## Resources

- **Unit tests**: `app/tests/test_delay_buffer.c`, `test_io_stream.c`
- **Main code**: `app/src/delay_buffer.c`
- **Docs**: `doc/develop.md` in scrcpy project

## Questions?

Check the test output or enable debug flags for detailed timing information.
