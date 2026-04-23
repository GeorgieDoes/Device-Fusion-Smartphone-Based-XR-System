# Code Optimization Examples for Scrcpy Delay Buffer

This file contains specific code changes you can make to test delay optimization.

---

## Optimization 1: Reduce Buffering Delay (Most Impactful)

### Current Code Location
File: `app/src/delay_buffer.c`, Function: `run_buffering()`

### Current Implementation (Lines ~60-75)
```c
sc_tick max_deadline = sc_tick_now() + db->delay;
// PTS (written by the server) are expressed in microseconds
sc_tick pts = SC_TICK_FROM_US(dframe.frame->pts);

bool timed_out = false;
while (!db->stopped && !timed_out) {
    sc_tick deadline = sc_clock_to_system_time(&db->clock, pts)
                     + db->delay;
    if (deadline > max_deadline) {
        deadline = max_deadline;
    }

    timed_out =
        !sc_cond_timedwait(&db->wait_cond, &db->mutex, deadline);
}
```

### Optimization: Aggressive Rendering (20% faster)
```c
// CHANGE:
// Instead of using full delay, use 80% of requested delay
// This trades buffer smoothness for lower latency

sc_tick max_deadline = sc_tick_now() + db->delay;
sc_tick pts = SC_TICK_FROM_US(dframe.frame->pts);

// Apply aggressive rendering multiplier
#define AGGRESSIVE_FACTOR 80  // Use 80% of delay, render 20% earlier
sc_tick adjusted_delay = (db->delay * AGGRESSIVE_FACTOR) / 100;

bool timed_out = false;
while (!db->stopped && !timed_out) {
    sc_tick deadline = sc_clock_to_system_time(&db->clock, pts)
                     + adjusted_delay;  // USE ADJUSTED
    if (deadline > max_deadline) {
        deadline = max_deadline;
    }

    timed_out =
        !sc_cond_timedwait(&db->wait_cond, &db->mutex, deadline);
}
```

### Test This Change
```bash
# 1. Edit app/src/delay_buffer.c, change AGGRESSIVE_FACTOR
# 2. Recompile
meson compile -C builddir

# 3. Run test
./run_tests.sh test_delay_buffer

# 4. Expected: Latency measurement shows ~20% reduction
# BEFORE: latency: 100000µs
# AFTER: latency:  80000µs
```

### Measure on Real Device
```bash
# Run with -b (video buffer) to control delay
scrcpy -b50  # 50ms buffer
# Should feel more responsive but might have occasional glitches
```

---

## Optimization 2: Reduce Lock Contention (Medium Impact)

### Current Code Location
File: `app/src/delay_buffer.c`, Lines ~30-50

### Current Implementation
```c
// PROBLEM: Holds mutex while waiting (locks display pipeline)
sc_mutex_lock(&db->mutex);

while (!db->stopped && !timed_out) {
    sc_tick deadline = sc_clock_to_system_time(&db->clock, pts)
                     + db->delay;
    // MUTEX HELD DURING ENTIRE WAIT
    timed_out =
        !sc_cond_timedwait(&db->wait_cond, &db->mutex, deadline);
}

bool stopped = db->stopped;
sc_mutex_unlock(&db->mutex);
```

### Optimization: Double-Check Locking
```c
// IMPROVEMENT: Minimize lock hold time
sc_tick deadline;
{
    // Lock only to read shared state
    sc_mutex_lock(&db->mutex);
    
    if (db->stopped) {
        sc_mutex_unlock(&db->mutex);
        goto stopped;
    }
    
    // Calculate deadline inside lock (fast path)
    sc_tick pts_sync = SC_TICK_FROM_US(dframe.frame->pts);
    deadline = sc_clock_to_system_time(&db->clock, pts_sync)
             + db->delay;
    
    sc_mutex_unlock(&db->mutex);  // RELEASE EARLY
}

// Wait without holding mutex
bool timed_out = false;
while (!timed_out) {
    // Check stop condition periodically
    sc_mutex_lock(&db->mutex);
    bool stopped = db->stopped;
    sc_mutex_unlock(&db->mutex);
    
    if (stopped) {
        goto stopped;
    }
    
    // Sleep without mutex (other threads can proceed)
    sc_tick now = sc_tick_now();
    if (now >= deadline) {
        break;  // Time to render
    }
    
    // Wait for small interval
    sc_tick wait_time = deadline - now;
    if (wait_time > SC_TICK_FROM_MS(5)) {
        wait_time = SC_TICK_FROM_MS(5);  // Wait max 5ms
    }
    sc_cond_timedwait(&db->wait_cond, NULL, wait_time);
}
```

### Note
⚠️ This is more complex! Only try after mastering Optimization 1.

---

## Optimization 3: Skip Frames When Behind (Advanced)

### Current Code Location
File: `app/src/delay_buffer.c`, Lines ~80-95

### Current Implementation
```c
// Problem: Renders every frame, even if late
// Result: Plays catch-up but latency stays high

bool ok = sc_frame_source_sinks_push(&db->frame_source, dframe.frame);
```

### Optimization: Drop Late Frames
```c
// IMPROVEMENT: Skip frames that are already late
// Instead of rendering late frames, drop them and move to next

sc_tick now = sc_tick_now();
sc_tick frame_deadline = sc_clock_to_system_time(&db->clock, pts)
                       + db->delay;

if (now > frame_deadline + SC_TICK_FROM_MS(10)) {
    // Frame is >10ms late - skip it
    LOGD("Skipping late frame (%" PRItick "µs behind)",
         now - frame_deadline);
    
    sc_delayed_frame_destroy(&dframe);
    // Continue to next frame in queue
    continue;
}

// Render on-time frame
bool ok = sc_frame_source_sinks_push(&db->frame_source, dframe.frame);
```

### Test This Change
```bash
# 1. Edit delay_buffer.c
# 2. Recompile and test
./run_tests.sh test_delay_buffer

# 3. Run on device with high load
# scrcpy -m720 &
# stress-ng --cpu 4 --timeout 30s  # Heavy load
# Video should stay responsive!
```

---

## Optimization 4: Make Clock More Aggressive (Medium-High Risk)

### Current Code Location
File: `app/src/clock.c`, Function: `sc_clock_to_system_time()`

### Current Implementation
```c
// Conservative timing
sc_tick sc_clock_to_system_time(struct sc_clock *clock, sc_tick pts) {
    // Full compensation for drift
    sc_tick now = sc_tick_now();
    return now + (pts - clock->last_pts);
}
```

### Optimization: Predictive Rendering
```c
// More aggressive: Don't wait for full sync
sc_tick sc_clock_to_system_time(struct sc_clock *clock, sc_tick pts) {
    sc_tick now = sc_tick_now();
    
    // Estimate time but bias toward earlier rendering
    sc_tick predictor = now + (pts - clock->last_pts);
    
    // Apply 15% aggressive bias (render a bit early)
    sc_tick bias = (predictor - now) / 7;  // 1/7 ≈ 14%
    
    return predictor - bias;
}
```

### ⚠️ WARNING
This can cause:
- Audio/video sync issues
- Jittery video
- Needs extensive testing

---

## Optimization 5: Tunable Delay (Recommended for Testing)

### Add to `app/src/delay_buffer.h`
```c
// Add this struct member to sc_delay_buffer:
struct sc_delay_buffer {
    // ... existing fields ...
    
    // Optimization: configurable delay scaling
    int delay_scale_percent;  // 100 = normal, 80 = 20% faster
};
```

### Add to `app/src/delay_buffer.c`
```c
// In initialization:
void sc_delay_buffer_init(struct sc_delay_buffer *db, sc_tick delay,
                          bool first_frame_asap) {
    // ... existing code ...
    
    db->delay_scale_percent = 100;  // Default: no scaling
}

// In run_buffering(), use:
sc_tick adjusted_delay = (db->delay * db->delay_scale_percent) / 100;
```

### Usage (How to Test Different Delays)
```bash
# After compiling, create test wrapper
# that modifies delay_scale_percent before starting thread

// In test:
sc_delay_buffer_init(&db, SC_TICK_FROM_MS(100), false);

// Test at 100% (original)
db.delay_scale_percent = 100;
// ... measure performance

// Test at 80% (20% faster)
db.delay_scale_percent = 80;
// ... measure performance

// Test at 60% (40% faster)
db.delay_scale_percent = 60;
// ... measure performance
```

### Test Command
```bash
./run_tests.sh test_delay_buffer
# Output will show measurements at each scale level
```

---

## Optimization 6: Profile-Based Dynamic Adjustment

### Add Debug Logging to Measure Current Performance

File: `app/src/delay_buffer.c`, Uncomment debug line:
```c
// At top of file, uncomment this:
#define SC_BUFFERING_DEBUG

// This enables logging like:
// Buffering: 1000000;999999;1000001  (pts;push_date;now)
```

### Parse Debug Output
```bash
# Run tests and capture output
./run_tests.sh test_delay_buffer 2>&1 | tee output.log

# Extract timing numbers
grep "Buffering:" output.log | awk -F';' '{
    pts=$1; push=$2; now=$3;
    latency=now-push;
    print latency
}' | sort -n | tail -n 10
```

---

## Quick Testing Checklist

Before you make ANY change:

- [ ] Read the code you're modifying
- [ ] Understand what it does currently
- [ ] Write down what you expect to change
- [ ] Make only ONE change
- [ ] Compile: `meson compile -C builddir`
- [ ] Test: `./run_tests.sh test_delay_buffer`
- [ ] Check for errors/warnings
- [ ] If it breaks, revert immediately
- [ ] Document what you changed

---

## Reverting Changes

If optimization makes things worse:

```bash
# Undo last edit
git checkout app/src/delay_buffer.c

# Or restore all
git checkout scrcpy-master/app/src/

# Recompile
meson compile -C builddir

# Test again
./run_tests.sh test_delay_buffer
```

---

## Measuring Success

### Before/After Comparison

```bash
# Baseline
./run_tests.sh test_delay_buffer > before.txt

# Edit code, make change

# After optimization
./run_tests.sh test_delay_buffer > after.txt

# Compare
diff before.txt after.txt
```

### Look for:
- ✅ Faster "Latency measurement test"
- ✅ Same buffer operation count
- ❌ No new errors or warnings
- ❌ No "skipped frame" warnings
- ❌ No "buffer underrun" messages

---

## Real Device Testing After Unit Tests Pass

```bash
# 1. Connect Android device
adb devices

# 2. Build debug version
meson compile -C builddir

# 3. Run and observe
./builddir/scrcpy -m1024 --show-touches

# 4. Look for:
# - Touch response lag
# - Video smoothness
# - Audio sync

# 5. Measure latency with phone clock in view
# (capture with high-speed camera if available)
```

---

## Next Steps

1. **Start with Optimization 1** - Reduce AGGRESSIVE_FACTOR step-by-step
   - Try 95%, then 90%, then 80%
   - Find the minimum that works

2. **Test incrementally:**
   - Change 1 value
   - Run test
   - Check output
   - Measure one metric

3. **Document your findings:**
   - Record delay values tested
   - Record improvements achieved
   - Note any issues found

4. **Then move to real device:**
   - Build for device
   - Test with real Android
   - Measure actual latency

---

## Gotchas to Avoid

❌ **DON'T** change multiple things at once
❌ **DON'T** skip testing after each change
❌ **DON'T** modify clock code without understanding sync
❌ **DON'T** reduce delay below 20-30ms (risk of underrun)
❌ **DON'T** forget to recompile after editing

✅ **DO** make small incremental changes
✅ **DO** test after every change
✅ **DO** measure with actual metrics
✅ **DO** back up working version
✅ **DO** document your experiments

---

## References

- Main buffer code: `app/src/delay_buffer.c` (lines 1-200)
- Clock code: `app/src/clock.c`
- Test file: `app/tests/test_delay_buffer.c`
- Build config: `app/meson.build`

**Test to verify changes work:**
```bash
./run_tests.sh test_delay_buffer
```
