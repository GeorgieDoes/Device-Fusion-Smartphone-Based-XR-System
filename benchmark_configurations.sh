#!/bin/bash
# Benchmark Script to test hardware configurations and generate a robust CSV
# Outputs real-world performance metrics to a timestamped CSV file

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
CSV_FILE="raw_latency_data_${TIMESTAMP}.csv"
SCRCPY_BIN="./scrcpy-master/builddir/app/scrcpy"
SERVER_PATH="$(pwd)/scrcpy-master/scrcpy-server-v3.3.4"

# Ask user for duration or default to 30
read -p "Enter test duration in seconds per configuration (default 30): " input_duration
TEST_DURATION=${input_duration:-30}

if [ ! -f "$SCRCPY_BIN" ]; then
    echo "Error: scrcpy binary not found at $SCRCPY_BIN. Please build it first."
    exit 1
fi

adb wait-for-device
# Wake up phone just in case
adb shell input keyevent 224

echo "Configuration,Resolution,Target_FPS,Actual_FPS,Inter_Frame_Delay_ms,Codec,Bitrate_Usb,Host_GPU_CPU_Usage_%,Duration_Sec" > "$CSV_FILE"

CONFIG_NAMES=()
declare -A configs

# Generate all variations of resolutions, FPS, and bitrates
for res_pair in "720:1280" "1080:1920"; do
    res_name="${res_pair%%:*}"
    width="${res_pair#*:}"
    for fps in 30 60; do
        for bitrate in 2 4 8 12 16 24 32; do
            name="${res_name}p_${fps}fps_${bitrate}M"
            CONFIG_NAMES+=("$name")
            configs["$name"]="-m $width --max-fps=$fps -b ${bitrate}M"
        done
    done
done

echo "Starting Hardware Benchmarks..."
echo "Data will be saved to $CSV_FILE"
echo "------------------------------------------------"

# 1. Force the phone to open a high-motion test video/website to ensure screen paints new frames constantly
echo "-> Opening test website on device (TestUFO)..."
adb shell am start -a android.intent.action.VIEW -d "https://testufo.com/" > /dev/null 2>&1
echo "-> Waiting 3 seconds for it to load before starting first test..."
sleep 3 

for name in "${CONFIG_NAMES[@]}"; do
    args=${configs[$name]}
    res=$(echo $name | cut -d'_' -f1)
    target_fps=$(echo $name | cut -d'_' -f2 | sed 's/fps//')
    bitrate=$(echo "$args" | grep -oP "(?<=-b )\w+")
    codec="h265"
    
    echo "Testing Configuration: $name ($args)"
    
    # 2. Run scrcpy and capture FPS outputs (background)
    timeout $TEST_DURATION env SCRCPY_SERVER_PATH="$SERVER_PATH" $SCRCPY_BIN --video-codec=$codec $args --print-fps > temp_log.txt 2>&1 &
    SCRCPY_PID=$!
    
    # 3. Monitor Host CPU during the limit
    cpu_sum=0
    cpu_samples=0
    for (( i=0; i<$TEST_DURATION; i++ )); do
        if kill -0 $SCRCPY_PID 2>/dev/null; then
            cpu_val=$(ps -p $SCRCPY_PID -o %cpu= | awk '{print $1}')
            if [ ! -z "$cpu_val" ]; then
                cpu_sum=$(awk "BEGIN {print $cpu_sum + $cpu_val}")
                cpu_samples=$((cpu_samples + 1))
            fi
        fi
        sleep 1
    done
    wait $SCRCPY_PID 2>/dev/null
    
    # Average CPU
    if [ $cpu_samples -gt 0 ]; then
        avg_cpu=$(awk "BEGIN {printf \"%.1f\", $cpu_sum / $cpu_samples}")
    else
        avg_cpu="0.0"
    fi
    
    # Parse the FPS data from the log
    fps_measurements=$(grep -oP "\d+(?= fps)" temp_log.txt)
    
    # Write each FPS measurement to CSV mapping to the configuration
    if [ -z "$fps_measurements" ]; then
        echo "$name,$res,$target_fps,0,0,$codec,$bitrate,$avg_cpu,$TEST_DURATION" >> "$CSV_FILE"
        echo "  -> Failed or 0 FPS"
    else
        for fps in $fps_measurements; do
            if [ "$fps" -gt 0 ]; then
                # Frame Delay (ms) = 1000 / FPS
                delay_ms=$(awk "BEGIN {printf \"%.2f\", 1000 / $fps}")
            else
                delay_ms="0"
            fi
            echo "$name,$res,$target_fps,$fps,$delay_ms,$codec,$bitrate,$avg_cpu,$TEST_DURATION" >> "$CSV_FILE"
        done
        avg=$(echo "$fps_measurements" | awk '{s+=$1; c++} END {if (c>0) print s/c; else print 0}')
        echo "  -> Average FPS: $avg | Inter-Frame Delay: $(awk "BEGIN {if($avg>0) printf\"%.2f\", 1000/$avg; else print 0}")ms | Host GPU/CPU Usage: ${avg_cpu}%"
    fi
    
    echo "  -> Cooldown for 3 seconds..."
    sleep 3
done

# Return to Home screen to stop the high-motion rendering
echo "-> Returning to Home screen..."
adb shell input keyevent 3 > /dev/null 2>&1

rm temp_log.txt
echo "------------------------------------------------"
echo "Testing complete! Raw data exported to $CSV_FILE"
