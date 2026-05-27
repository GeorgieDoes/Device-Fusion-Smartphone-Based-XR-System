#!/bin/bash
# Benchmark Script to test Camera pipeline configurations (rpicam-vid + OpenCV + Pygame)
# Outputs real-world performance metrics to a timestamped CSV file for the thesis

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
PC_NAME=$(hostname | tr ' ' '_')
CSV_FILE="camera_latency_data_${PC_NAME}_${TIMESTAMP}.csv"

# Ask user for duration or default to 15
read -p "Enter test duration in seconds per configuration (default 15): " input_duration
TEST_DURATION=${input_duration:-15}

echo "Configuration,Resolution,Target_FPS,Actual_FPS,Inter_Frame_Delay_ms,Processing_Latency_ms,Host_CPU_Usage_%,Duration_Sec" > "$CSV_FILE"

# Create a temporary python script that runs the camera pipeline system and logs metrics internally
cat << 'PYTHON_EOF' > camera_bench_runner.py
import sys
import subprocess
import pygame
import numpy as np
import cv2
import threading
import time

WIDTH = int(sys.argv[1])
HEIGHT = int(sys.argv[2])
TARGET_FPS = int(sys.argv[3])
DURATION = int(sys.argv[4])

pygame.init()
pygame.display.set_caption(f"RPi5 Camera Benchmark - {WIDTH}x{HEIGHT}@{TARGET_FPS}fps")

# To simulate the actual workload, we set the actual mode boundaries
screen = pygame.display.set_mode((WIDTH, HEIGHT))

latest_frame = [None]
lock = threading.Lock()
running = True
frame_size = WIDTH * HEIGHT * 3 // 2  # YUV420 capacity

metrics = {
    'process_times': [],
    'inter_frame_times': []
}

def capture_thread():
    global running
    proc = subprocess.Popen(
        ['rpicam-vid', '--camera', '0', '-t', '0', '--codec', 'yuv420',
         '--width', str(WIDTH), '--height', str(HEIGHT), '--framerate', str(TARGET_FPS), '-o', '-'],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        bufsize=262144
    )
    
    try:
        while running:
            t0 = time.time()
            # Read exactly one YUV420 frame block
            frame_data = proc.stdout.read(frame_size)
            if len(frame_data) < frame_size:
                break
            
            # Simulated rendering load: Convert YUV420 to BGR using OpenCV
            yuv_frame = np.frombuffer(frame_data, np.uint8).reshape((HEIGHT + HEIGHT//2, WIDTH))
            bgr = cv2.cvtColor(yuv_frame, cv2.COLOR_YUV2BGR_I420)
            
            frame = pygame.image.frombuffer(bgr.tobytes(), (WIDTH, HEIGHT), "BGR")
            
            with lock:
                latest_frame[0] = (frame, t0)
    finally:
        proc.terminate()

t = threading.Thread(target=capture_thread, daemon=True)
t.start()

start_time = time.time()
last_flip_time = start_time

try:
    while running and (time.time() - start_time) < DURATION:
        # Pumping event loop to prevent lockups
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        frame_to_blit = None
        capture_start_t = 0
        
        with lock:
            if latest_frame[0]:
                frame_to_blit, capture_start_t = latest_frame[0]
                latest_frame[0] = None # Consume it so we don't count duplicate frame blits
        
        if frame_to_blit:
            screen.blit(frame_to_blit, (0, 0))
            pygame.display.flip()
            
            now = time.time()
            metrics['process_times'].append(now - capture_start_t)
            metrics['inter_frame_times'].append(now - last_flip_time)
            last_flip_time = now

except KeyboardInterrupt:
    pass
finally:
    running = False
    pygame.quit()

# Output thesis log data back to stdout
num_frames = len(metrics['inter_frame_times'])
if num_frames > 1:
    avg_inter_frame = sum(metrics['inter_frame_times'][1:]) / (num_frames - 1)
    actual_fps = 1.0 / avg_inter_frame if avg_inter_frame > 0 else 0
    avg_process = sum(metrics['process_times']) / num_frames
    print(f"STATS:{actual_fps:.2f}:{avg_inter_frame*1000:.2f}:{avg_process*1000:.2f}")
else:
    print("STATS:0:0:0")
PYTHON_EOF

# The permutations of configurations to run 
CONFIGS=(
    "480p_30fps:640:480:30"
    "480p_60fps:640:480:60"
    "720p_30fps:1280:720:30"
    "720p_60fps:1280:720:60"
    "1080p_30fps:1920:1080:30"
    "1080p_60fps:1920:1080:60"
)

echo "Starting Camera XR-Pipeline Hardware Benchmarks..."
echo "Data will be saved to $CSV_FILE"
echo "------------------------------------------------"

for cfg in "${CONFIGS[@]}"; do
    name=$(echo $cfg | cut -d':' -f1)
    width=$(echo $cfg | cut -d':' -f2)
    height=$(echo $cfg | cut -d':' -f3)
    fps=$(echo $cfg | cut -d':' -f4)
    res="${height}p"
    
    echo "Testing Camera Configuration: $name ($width x $height @ $fps fps)"
    
    # Run the Python testbed script in the background to simultaneously capture CPU telemetry
    python3 camera_bench_runner.py $width $height $fps $TEST_DURATION > temp_cam_log.txt 2>&1 &
    PY_PID=$!
    
    # Monitor Host CPU percentage over the span of the limit
    cpu_sum=0
    cpu_samples=0
    for (( i=0; i<$TEST_DURATION; i++ )); do
        if kill -0 $PY_PID 2>/dev/null; then
            cpu_val=$(ps -p $PY_PID -o %cpu= | awk '{print $1}')
            if [ ! -z "$cpu_val" ]; then
                cpu_sum=$(awk "BEGIN {print $cpu_sum + $cpu_val}")
                cpu_samples=$((cpu_samples + 1))
            fi
        fi
        sleep 1
    done
    wait $PY_PID 2>/dev/null
    
    # Average CPU
    if [ $cpu_samples -gt 0 ]; then
        avg_cpu=$(awk "BEGIN {printf \"%.1f\", $cpu_sum / $cpu_samples}")
    else
        avg_cpu="0.0"
    fi
    
    # Extract STATS dump payload from the temporary log buffer
    stats_line=$(grep "STATS:" temp_cam_log.txt | tail -n 1)
    if [ ! -z "$stats_line" ]; then
        actual_fps=$(echo $stats_line | cut -d':' -f2)
        inter_frame=$(echo $stats_line | cut -d':' -f3)
        proc_latency=$(echo $stats_line | cut -d':' -f4)
        
        echo "$name,$res,$fps,$actual_fps,$inter_frame,$proc_latency,$avg_cpu,$TEST_DURATION" >> "$CSV_FILE"
        echo "  -> Average FPS: $actual_fps | Inter-Frame Delay: ${inter_frame}ms | Processing Latency: ${proc_latency}ms | Pipeline CPU Usage: ${avg_cpu}%"
    else
        echo "$name,$res,$fps,0,0,0,$avg_cpu,$TEST_DURATION" >> "$CSV_FILE"
        echo "  -> Failed to gather stats or 0 FPS detected."
    fi
    
    echo "  -> Cooldown for 2 seconds to relieve thermals..."
    sleep 2
done

# Cleanup temporary scaffolding files
rm temp_cam_log.txt
rm camera_bench_runner.py

echo "------------------------------------------------"
echo "Camera pipeline benchmarking complete! Thesis CSV dataset exported to $CSV_FILE"
