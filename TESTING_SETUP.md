# Scrcpy Testing Guide - Delay Optimization & I/O Testing

## Quick Start: Run Tests Without Full Build

### 1. Build Only Tests (Debug Mode)
```bash
cd scrcpy-master
meson setup builddir --buildtype=debug
meson compile -C builddir
```

### 2. Run All Tests
```bash
meson test -C builddir
```

### 3. Run Specific Test
```bash
# Test delay buffer functions
meson test -C builddir test_delay_buffer

# Test frame buffer
meson test -C builddir test_frame_buffer

# Test input/output
meson test -C builddir test_io_stream
```

### 4. Run Tests with Verbose Output
```bash
meson test -C builddir --verbose test_delay_buffer
```

---

## Testing Delay Optimization

### Key Files to Modify for Testing:
- `app/src/delay_buffer.c` - Main buffering logic
- `app/src/clock.c` - Timing calculations
- `app/src/display.c` - Frame display timing

### Add Debug Output to delay_buffer.c:
Uncomment this line in `app/src/delay_buffer.h` to enable bufferng debug logs:
```c
//#define SC_BUFFERING_DEBUG // uncomment to debug
```

Then compile and run - timing info will be logged to console.

### Create Test Cases:
Add test files in `app/tests/test_delay_buffer.c` to test:
- Frame delay calculation accuracy
- Queue overflow scenarios
- Clock synchronization
- First frame handling

---

## Testing Input/Output (Cameras & Sensors)

### Input Stream Testing:
1. **Keyboard/Mouse Input**: Test in `app/src/input_manager.c`
2. **Touchscreen Input**: Test in `app/src/controller.c`
3. **Sensor Data**: Add tests in `app/tests/test_sensor_stream.c`

### Output Stream Testing:
1. **Video Output**: Test frame delivery in `app/tests/test_frame_buffer.c`
2. **Display Rendering**: Test in `app/src/display.c`
3. **Audio Output**: Test in `app/src/audio_player.c`

### Camera Stream Testing:
1. Simulate camera data stream
2. Test H.264 decoding with different camera inputs
3. Measure latency from capture to display

---

## Framework: Add New Tests

### Step 1: Create Test File
Create `app/tests/test_your_component.c`:
```c
#include "common.h"
#include <assert.h>

static void test_your_function(void) {
    // Test code using assert()
    assert(result == expected);
}

int main(void) {
    test_your_function();
    return 0;
}
```

### Step 2: Register Test in Meson
Edit `app/meson.build`, add to `tests` array:
```
['test_your_component', [
    'tests/test_your_component.c',
    'src/your_source.c',
    // other dependencies
]],
```

### Step 3: Compile & Run
```bash
meson test -C builddir test_your_component
```

---

## Quick Commands Reference

| Task | Command |
|------|---------|
| Setup debug build | `meson setup builddir --buildtype=debug` |
| Compile tests | `meson compile -C builddir` |
| Run all tests | `meson test -C builddir` |
| Run single test | `meson test -C builddir test_name` |
| Rebuild specific target | `meson compile -C builddir test_name` |
| Clean build | `rm -rf builddir && meson setup builddir --buildtype=debug` |
| See test code | `cat app/tests/test_*.c` |
| Add debug output | Comment/uncomment `#define` macros in source files |

---

## Modifying Code for Testing

### Enable Debug Logging:
```c
// In source file headers, uncomment:
#define SC_DEBUG_DELAY_BUFFER
#define SC_DEBUG_FRAME_TIMING
#define SC_BUFFERING_DEBUG
```

### Add Temporary Test Code:
```c
// Add this to test specific functions
#ifdef SC_TEST
void test_timing_accuracy(void) {
    sc_tick start = sc_tick_now();
    // your code
    sc_tick end = sc_tick_now();
    LOGI("Time elapsed: %" PRItick " µs", end - start);
}
#endif
```

### Run with Logging:
```c
// Modify log level during tests
LOGI("Delay buffer latency: %d ms", delay_ms);
```

---

## Testing Workflow for Optimization

1. **Identify bottleneck** - Add timing debug logs
2. **Run test** - `meson test -C builddir test_name`
3. **Check output** - Look for latency measurements
4. **Modify code** - Change algorithm/tuning values
5. **Recompile** - `meson compile -C builddir`
6. **Compare results** - Before/after latency metrics

---

## Input/Output Testing Framework

### Mock Input Stream:
```c
// Create synthetic input for testing
struct test_input_sample {
    uint32_t timestamp;
    uint8_t data[256];
};
```

### Mock Sensor/Camera Stream:
```c
// Simulate camera feed
void simulate_camera_stream(const char *test_video_path) {
    // Parse video file
    // Feed frames to delay buffer
    // Measure end-to-end latency
}
```

See `app/tests/test_io_stream.c` for full example.

---

## Files to Check/Modify

- `app/meson.build` - Register new tests here
- `app/tests/` - Add test source files here
- `app/src/delay_buffer.h` - Uncomment `SC_BUFFERING_DEBUG`
- `app/src/common.h` - Check logging macros
- `app/src/util/log.h` - Understand log levels (LOGI, LOGE, LOGD)
