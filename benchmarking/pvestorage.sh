#!/bin/bash

localtest=true
remotetest=false
max_length=16
# Array of remote hostnames
remote_hosts=("pve1.ext4.ssd" "pve2.zfs.ssdr1" "pve3.zfs.ssdr1" "nas1.ext4.nvme")

## !!!! IMPORTANT - This script will connect to each host and write to files in the directory /testwrites/
## !!!! Create a symlink on each host that points /testwrites/ to the storage you want to test.

# Function to run read and write tests on a remote host
run_tests_on_remote_host() {
    local remote_host="$1"
    local block_size="$2"
    local count="$3"
    local test_type="$4"
    local test_file="/testwrites/storage_test_${block_size}_${count}_${test_type}.dat"

    # Generate test data file on remote host
 #   echo "Generating test data file on ${remote_host}: ${test_file}"
    ssh "${remote_host}" "dd if=/dev/urandom of=${test_file} bs=${block_size} count=${count} status=progress" 2>/dev/null

    # Run read test on remote host
#    echo "Running read test on ${remote_host} (${block_size} bs, ${count} count)"
    readdd=$(ssh "${remote_host}" "dd if=\"${test_file}\" of=/dev/null bs=${block_size} count=${count} iflag=direct 2>&1")
    read_time=$(echo "${readdd}" | awk -F, '/copied/ {print $3}')
    read_timenospaces=$(echo "${read_time}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]s$//')
    read_throughput=$(echo "$readdd" | sed ':a;N;$!ba;s/\n//g' | awk -F, '{print $4}' | sed 's/^[[:blank:]]*//;s/^*[[:blank:]]$//')
#    echo "${remote_host} | ${test_type} | ${read_timenospaces} seconds | ${read_throughput} MB/s | Read"
    printf "| %-*s | %-*s | %-*s | %-*s | %-*s | \n" "${max_length}" "${remote_host}" "${max_length}" "Read" "${max_length}" "${test_type}" "${max_length}" "${read_timenospaces}" "${max_length}" "${read_throughput}"


    # Run write test on remote host
#    echo "Running write test on ${remote_host} (${block_size} bs, ${count} count)"
    writedd=$(ssh "${remote_host}" "dd if=/dev/zero of=\"${test_file}\" bs=\"${block_size}\" count=\"${count}\" oflag=direct 2>&1")
    write_time=$(echo "${writedd}" | awk -F, '/copied/ {print $3}')
    write_timenospaces=$(echo "${write_time}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]s$//')

    write_throughput=$(echo "$writedd" | sed ':a;N;$!ba;s/\n//g' | awk -F, '{print $4}' | sed 's/^[[:blank:]]*//;s/^*[[:blank:]]$//' )
    printf "| %-*s | %-*s | %-*s | %-*s | %-*s | \n" "${max_length}" "${remote_host}" "${max_length}" "Write" "${max_length}" "${test_type}" "${max_length}" "${write_timenospaces}" "${max_length}" "${write_throughput}"
    #echo "${remote_host} | ${test_type} | ${write_timenospaces} seconds | ${write_throughput} | Write"

    # Clean up test data file on remote host
    ssh "${remote_host}" "rm ${test_file}"
}

run_tests_on_local_host() {
    local thishost=hostname
    local block_size="$2"
    local count="$3"
    local test_type="$4"
    local test_file="/testwrites/storage_test_${block_size}_${count}_${test_type}.dat"

    # Check for existence of directory
    if [[ ! -e "/testwrites/" ]]; then
        echo "/test/writes/ doesn't exist. Please create this directory and ensure that it is symlinked to the storage you want to test"
        exit 1
    fi

    # Generate test data file on localhost
    dd if=/dev/urandom of="${test_file}" bs="${block_size}" count="${count}" status=progress 2>/dev/null

    # Run read test on localhost
    readdd=$(dd if="${test_file}" of=/dev/null bs="${block_size}" count="${count}" iflag=direct 2>&1)
    read_time=$(echo "${readdd}" | awk -F, '/copied/ {print $3}')
    read_timenospaces=$(echo "${read_time}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]s$//')
    read_throughput=$(echo "$readdd" | sed ':a;N;$!ba;s/\n//g' | awk -F, '{print $4}' | sed 's/^[[:blank:]]*//;s/^*[[:blank:]]$//')
    #echo "${remote_host} | ${test_type} | ${read_timenospaces} seconds | ${read_throughput} MB/s | Read"
    printf "| %-*s | %-*s | %-*s | %-*s | %-*s | \n" "${max_length}" "${thishost}" "${max_length}" "Read" "${max_length}" "${test_type}" "${max_length}" "${read_timenospaces}" "${max_length}" "${read_throughput}"


    # Run write test on remote host
#    echo "Running write test on ${thishost} (${block_size} bs, ${count} count)"
    writedd=$(dd if=/dev/zero of="${test_file}" bs="${block_size}" count="${count}" oflag=direct 2>&1)
    write_time=$(echo "${writedd}" | awk -F, '/copied/ {print $3}')
    write_timenospaces=$(echo "${write_time}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]s$//')

    write_throughput=$(echo "$writedd" | sed ':a;N;$!ba;s/\n//g' | awk -F, '{print $4}' | sed 's/^[[:blank:]]*//;s/^*[[:blank:]]$//' )
    printf "| %-*s | %-*s | %-*s | %-*s | %-*s | \n" "${max_length}" "${thishost}" "${max_length}" "Write" "${max_length}" "${test_type}" "${max_length}" "${write_timenospaces}" "${max_length}" "${write_throughput}"

    # Clean up test data file on remote host
    rm "${test_file}"
}

# Print table header
function rowchars() {
        char="="
        num_times=96
        for ((i=0; i<num_times; i++)); do
          echo -n "$char"
        done
        echo
}
rowchars
printf "| %-*s | %-*s | %-*s | %-*s | %-*s | \n" "$max_length" "Hostname" "$max_length" "Read/Write" "$max_length" "Block Size" "$max_length" "Time Taken (s)" "$max_length" "Throughput"
rowchars

if [[ $localtest = "true" ]]; then
    run_tests_on_local_host "${thishost}" "512K" 500 "512K"
    run_tests_on_local_host "${thishost}" "1048576K" 1 "1GB"
fi

if [[ $remotetest = "true" ]]; then
    # Loop through remote hosts and run tests on each host
    for remote_host in "${remote_hosts[@]}"; do
        # Run tests with bs=1G and count=1 on remote host
        run_tests_on_remote_host "${remote_host}" "512K" 500 "512K"
        run_tests_on_remote_host "${remote_host}" "1048576K" 1 "1GB"

        # Run tests with bs=512K and count=500 on remote host
    done
fi