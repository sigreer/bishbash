#!/bin/bash

# Timestamped output file
OUTFILE="localonly_cpu_stresstest_$(date +"%m-%d-%H-%M").csv"

# Header for CSV
echo "timestamp,Tdie,Tccd1,Tccd2,CPU_Usage(%),RAM_Usage(%),fan1_RPM,fan2_RPM,fan3_RPM,fan5_RPM" > "$OUTFILE"

# Logging function
log_metrics() {
  while true; do
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local zenpower=$(sensors | awk '/zenpower-pci-00c3/{flag=1;next}/Adapter:/{flag=0}flag' | grep -E 'Tdie|Tccd1|Tccd2' | awk '{print $2}' | tr -d '+°C')
    local tdie=$(echo "$zenpower" | sed -n '1p')
    local tccd1=$(echo "$zenpower" | sed -n '2p')
    local tccd2=$(echo "$zenpower" | sed -n '3p')

    local cpu_usage=$(top -bn1 | grep "%Cpu" | awk '{print 100 - $8}')
    local ram_usage=$(free | awk '/Mem:/ {printf("%.2f", $3/$2 * 100)}')

    local fans=$(sensors | awk '/nct6798-isa-0290/{flag=1;next}/Adapter:/{flag=0}flag' | grep -E 'fan[1235]:' | awk '{print $2}')
    local fan1=$(echo "$fans" | sed -n '1p')
    local fan2=$(echo "$fans" | sed -n '2p')
    local fan3=$(echo "$fans" | sed -n '3p')
    local fan5=$(echo "$fans" | sed -n '4p')

    echo "$timestamp,$tdie,$tccd1,$tccd2,$cpu_usage,$ram_usage,$fan1,$fan2,$fan3,$fan5" >> "$OUTFILE"
    sleep 3
  done
}

# Duration for each stress phase
PHASE_DURATION=90

# Start logging in background
log_metrics &
LOGGER_PID=$!

# Phase 1: Moderate stress
stress-ng --cpu 16 --vm 2 --vm-bytes 75% --timeout ${PHASE_DURATION}s --metrics-brief

echo "Phase 1 complete, starting phase 2"

# Phase 2: Full stress
stress-ng --cpu 32 --vm 4 --vm-bytes 50% --timeout ${PHASE_DURATION}s --metrics-brief
# Kill logger
kill "$LOGGER_PID"

echo "=== Test Complete. Data saved to $OUTFILE ==="
