#!/bin/bash

# Duration for stress test
DURATION=300  # 5 minutes

echo "=== CPU & Memory Test Starting (Duration: ${DURATION}s) ==="

# Check sensor info at the start
echo "--- Initial Sensor Readings ---"
sensors

# Start logging sensor output in background
echo "--- Logging sensors every 10s to sensor_log.txt ---"
sensors_loop() {
  while true; do
    echo "--- $(date) ---" >> sensor_log.txt
    sensors >> sensor_log.txt
    sleep 10
  done
}
sensors_loop &
SENSOR_PID=$!

# Run CPU + memory stress test
echo "--- Running stress-ng ---"
stress-ng --cpu 8 --vm 2 --vm-bytes 75% --timeout ${DURATION}s --metrics-brief

# Kill background sensor logging
kill "$SENSOR_PID"

echo "--- Final Sensor Readings ---"
sensors

echo "=== Test Complete. See sensor_log.txt for temperature/fan history. ==="
