# Camera & Sensor Input/Output Testing

This guide shows how to test and integrate camera and sensor data inputs, along with display output handling in scrcpy.

## Overview

The I/O testing framework allows you to:
- Simulate camera frame streams
- Test sensor data (gyroscope, accelerometer, compass)
- Measure display output latency
- Test concurrent input/output streams
- Validate data integrity through the pipeline

---

## Running I/O Tests

### Quick Test
```bash
cd scrcpy-master
./run_tests.sh test_io_stream
```

### Expected Output
```
=== Scrcpy Input/Output (Camera & Sensor) Test Suite ===
Testing camera input stream...
✓ Camera input test passed (3 frames received)
Testing sensor data input...
✓ Sensor input test passed (3 sensor types)
Testing display output...
✓ Display output test passed
Testing end-to-end latency (camera -> display)...
✓ End-to-end latency test passed (latency: 1234µs)
...
=== All I/O tests passed! ===
Camera frames received: 10
Sensor readings received: 8
```

---

## Understanding Camera Input

### What the Test Does

1. **Captures frames** - Simulates receiving H.264 encoded frames from camera
2. **Tracks metadata** - Frame ID, timestamp, source
3. **Buffers** - Stores temporarily for processing
4. **Delivers** - Passes to display pipeline

### Adding Camera Input Support

**File to modify:** `app/src/decoder.c` and `app/src/frame_buffer.c`

Example: Accept camera stream
```c
// In decoder.c, add handler for camera frames:
static bool
decode_camera_frame(struct sc_decoder *decoder, const AVPacket *packet) {
    // Decode H.264 frame from camera
    if (avcodec_send_packet(decoder->codec_ctx, packet) < 0) {
        LOGE("Failed to send camera packet");
        return false;
    }
    
    AVFrame *frame = av_frame_alloc();
    if (avcodec_receive_frame(decoder->codec_ctx, frame) == AVERROR(EAGAIN)) {
        // Frame not ready yet
        av_frame_free(&frame);
        return true;
    }
    
    // Forward to display
    bool ok = sc_frame_source_sinks_push(&decoder->frame_source, frame);
    av_frame_free(&frame);
    return ok;
}
```

### Testing Camera Input

**Create test scenario in** `app/tests/test_camera_stream.c`:
```c
#include "common.h"
#include <assert.h>

// Mock H.264 frames
static uint8_t h264_keyframe[] = {0x00, 0x00, 0x00, 0x01, 0x67, ...};
static uint8_t h264_frame[] = {0x00, 0x00, 0x00, 0x01, 0x61, ...};

static void test_camera_h264_decode(void) {
    // Create decoder context
    // Feed H.264 frames
    // Check decoded output
}
```

---

## Understanding Sensor Input

### Supported Sensor Types

| Sensor | Data Size | Update Rate | Use Case |
|--------|-----------|-------------|----------|
| **Accelerometer** | 3 floats (x,y,z) | 100+ Hz | Device motion |
| **Gyroscope** | 3 floats (x,y,z) | 100+ Hz | Rotation tracking |
| **Compass** | 3 floats (x,y,z) | 10-50 Hz | Direction/orientation |
| **GPS** | Lat,Lon,Alt | 1-10 Hz | Location |

### Test Structure

```c
// In test_io_stream.c:
struct mock_input_stream sensor_data_buffer[100];

// Simulate accelerometer
uint8_t accel_xyz[] = {0x10, 0x20, 0x30};  // x=0x10, y=0x20, z=0x30
simulate_sensor_input("accelerometer", accel_xyz, 3);

// Simulate gyroscope
uint8_t gyro_xyz[] = {0x40, 0x50, 0x60};
simulate_sensor_input("gyroscope", gyro_xyz, 3);
```

### Adding Real Sensor Input

**Architecture:**
1. **Client captures** sensor data from mouse/keyboard
2. **Encodes** to protocol buffer
3. **Sends** to Android server
4. **Server injects** into device sensors (via reflection)

Example: Modify `app/src/input_manager.c`
```c
// Add sensor data handling
struct sensor_input {
    char type[32];        // "accelerometer", "gyroscope"
    float data[3];        // x, y, z values
    uint64_t timestamp;   // microseconds
};

bool
sc_input_manager_send_sensor_data(
    struct sc_input_manager *im,
    struct sensor_input *sensor) {
    
    // Encode sensor data
    struct sc_control_msg msg = {0};
    msg.type = CONTROL_MSG_TYPE_SENSOR;
    msg.sensor_data = *sensor;
    
    // Send to device
    return sc_controller_push_msg(&im->controller, &msg);
}
```

---

## Display Output Testing

### What Gets Tested

1. **Frame delivery** - Verify frames reach display
2. **Timing** - Measure display latency
3. **Format** - Verify output format matches input
4. **Queue depth** - Ensure frames aren't bottlenecked

### Measuring Display Latency

```c
// In test:
sc_tick capture_time = sc_tick_now();  // Camera captures frame

// ... processing time ...

sc_tick display_time = sc_tick_now();  // Frame on screen

sc_tick latency = display_time - capture_time;
LOGI("Display latency: %" PRItick "µs", latency);
```

### Optimizing Display Output

**File:** `app/src/display.c`

```c
// Reduce unnecessary frame buffering:
static bool
on_new_frame(struct sc_display *display, const AVFrame *frame, void *userdata) {
    // BEFORE: Might skip to latest frame
    // AFTER: Render every frame with minimal delay
    
    // Get current time for latency tracking
    sc_tick frame_time = frame->pts != AV_NOPTS_VALUE
                       ? SC_TICK_FROM_US(frame->pts)
                       : sc_tick_now();
    
    // Display immediately
    return sc_display_render(display, frame, frame_time);
}
```

---

## End-to-End Testing

### Complete Data Flow

```
Camera/Sensor
    ↓
Capture Device Data (input_manager.c)
    ↓
Encode to Protocol (control_msg.c)
    ↓
Send to Client (socket)
    ↓
Decode (decoder.c)
    ↓
Buffer (delay_buffer.c)
    ↓
Render (display.c)
    ↓
Screen Output
```

### Testing Each Stage

**1. Capture test:**
```c
static void test_camera_capture(void) {
    // Simulate camera capture
    simulate_camera_frame(1, test_data, 4);
    assert(camera_frame_count == 1);
}
```

**2. Encoding test:**
```c
static void test_encode_frame(void) {
    // Test H.264 encoding of frame
    // Uses libavcodec
}
```

**3. Transmission test:**
```c
static void test_send_over_socket(void) {
    // Create mock socket
    // Send frame data
    // Verify checksum
}
```

**4. Decode test:**
```c
static void test_decode_frame(void) {
    // Decode H.264 frame
    // Verify output dimensions
    // Check for corruption
}
```

**5. Display test:**
```c
static void test_render_output(void) {
    render_output(1, frame_data, size, "display");
    assert(output_stream.frame_id == 1);
}
```

---

## Creating Complex Test Scenarios

### Scenario 1: High-Speed Camera Stream

```c
static void test_high_speed_camera(void) {
    // Simulate 60 fps camera
    for (int i = 0; i < 60; i++) {
        uint8_t frame_data[1024];
        // Generate/load frame data
        simulate_camera_frame(i, frame_data, 1024);
    }
    
    assert(camera_frame_count == 60);
    LOGI("60 fps camera stream processed");
}
```

### Scenario 2: Sensor + Camera Synchronization

```c
static void test_synchronized_camera_and_imu(void) {
    // Camera and IMU should be synchronized
    simulate_camera_frame(1, cam_data, 4);
    
    // IMU data captured at same time
    simulate_sensor_input("accelerometer", imu_data, 3);
    
    // Verify timestamps align
    uint32_t cam_ts = camera_frame_buffer[0].timestamp;
    uint32_t imu_ts = sensor_data_buffer[0].timestamp;
    
    // Allow 5ms sync tolerance
    assert(abs((int)cam_ts - (int)imu_ts) < 5000);
}
```

### Scenario 3: Network Dropout Recovery

```c
static void test_frame_loss_recovery(void) {
    // Send frames 1, 2, skip 3, send 4, 5
    simulate_camera_frame(1, data, 4);
    simulate_camera_frame(2, data, 4);
    // Frame 3 lost
    simulate_camera_frame(4, data, 4);
    simulate_camera_frame(5, data, 4);
    
    // System should still display frame 5 after recovery
    assert(camera_frame_count == 4);
}
```

---

## Integration with Real Hardware

### Step 1: Build for Real Device
```bash
cd scrcpy-master
meson setup builddir --buildtype=debug
meson compile -C builddir
./builddir/scrcpy -m720 2>&1 | grep -i "camera\|sensor"
```

### Step 2: Monitor Real Input/Output
```bash
# Watch for sensor/camera events
adb shell logcat | grep -i "camera\|sensor\|accelerometer"
```

### Step 3: Test with Physical Camera
1. Point camera at screen
2. Move device (triggers accelerometer)
3. Check that both inputs are captured
4. Measure round-trip latency

---

## Performance Metrics

### Measure These

| Metric | How | Target |
|--------|-----|--------|
| **Camera latency** | Time from capture to display | <100ms |
| **Sensor latency** | Time from sensor read to injection | <50ms |
| **Throughput** | Frames per second | 30-60 fps |
| **Memory usage** | Buffer size | <10MB |
| **CPU usage** | Thread overhead | <15% |

### Capture Metrics
```bash
# Start test with time
time ./run_tests.sh test_io_stream

# Monitor memory
watch -n 0.1 'ps aux | grep scrcpy'

# Check CPU
top -p $(pgrep -f 'scrcpy') -b
```

---

## Troubleshooting

### ❌ Tests Fail to Compile
**Problem:** Undefined symbols for camera structures
**Solution:** Check that camera-related source files are in meson.build dependencies

### ❌ Camera Stream Doesn't Decode
**Problem:** H.264 decoder returns NULL
**Solution:** 
- Verify H.264 codec is installed: `ffmpeg -codecs | grep h264`
- Check for libavcodec linking in meson.build

### ❌ Sensor Data Lost
**Problem:** Some sensor readings don't reach display
**Solution:**
- Check buffer size limit (100 in test)
- Add error logging in simulate_sensor_input()
- Verify timestamps are monotonic

### ❌ Latency Too High
**Problem:** End-to-end latency > 200ms
**Solution:**
- Reduce delay_buffer time
- Profile each stage separately
- Check if display rendering is bottleneck

---

## Next Steps

1. **Run I/O test** - `./run_tests.sh test_io_stream`
2. **Create camera test** - Add `test_camera_stream.c`
3. **Add sensor input** - Implement camera capture in `input_manager.c`
4. **Test with device** - Run on real Android device
5. **Measure latency** - Compare with current scrcpy performance
6. **Optimize flow** - Reduce delays in critical path

---

## References

- **Test source:** `app/tests/test_io_stream.c`
- **Camera codec:** `app/src/decoder.c`
- **Display output:** `app/src/display.c`
- **Input handling:** `app/src/input_manager.c`
- **Protocol:** See `app/src/control_msg.h` and `device_msg.h`
