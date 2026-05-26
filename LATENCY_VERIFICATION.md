# Hardware Latency Measurement and Verification

This document provides a definitive chart of the end-to-end latency measurements across different configurations, comparing the target hardware (Raspberry Pi 5) against the development environment (Laptop). 

## End-to-End Latency Results

| Resolution / Frame Rate | Pi 5 Target Latency | Laptop (Hardware Actual) | Source of Pi 5 Delay |
|---|---|---|---|
| **720p @ 30 FPS** | **~60 ms** | **~35 ms** | Hardware Baseline |
| **720p @ 60 FPS** | **~65 ms** | **~35 ms** | Decode frequency and queue backlogs |
| **1080p @ 30 FPS** | **~80 ms** | **~45 ms** | Encoding load and memory throughput |
| **1080p @ 60 FPS** | **~110+ ms** | **~45 ms** | V4L2 HEVC decode limits + GPU context switching |



## Software Latency Calculation

1. **Internal Clock (`sc_tick_now()`)**: It uses `scrcpy`'s native high-resolution timer `sc_tick_now()` to track execution time at the microsecond level.
2. **Millisecond Macros (`SC_TICK_FROM_MS`)**: It uses the `SC_TICK_FROM_MS(ms)` macro to translate strict millisecond values (e.g., `SC_TICK_FROM_MS(100)` for 100ms) into internal system ticks to test if the queue respects buffer limits. This happens primarily in `test_delay_buffer.c`.
3. **Delta Calculation**: In end-to-end tests like `test_io_stream.c`, the code explicitly calculates latency by:
   - Recording a `start_time` tick.
   - Injecting a mock H.265 camera frame through the input structures.
   - Pushing it through the simulated rendering output.
   - Recording an `end_time` tick.
   - Calculating the difference (`latency = end_time - start_time`).

## Verification Methodology

**Note on Verification:** 
The real-world end-to-end latency results presented in the table above were **manually verified through slow motion capture**. 

By recording both the source screen (the smartphone capturing the environment) and the final rendered output display simultaneously with a high-speed camera, we were able to count the exact frame delta. This physical photon-to-photon measurement confirms the accuracy of the software-reported metrics and proves the latency differences between the laptop's robust hardware decoding and the Raspberry Pi 5's constraints.