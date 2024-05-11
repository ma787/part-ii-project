#!/bin/bash

mkdir -p ../all_results/"$(date +%d-%m-%y)"/"$3"

mountpoint=$(df --output=target /dev/sda1 | tail -1)
echo "running tests for device $1 mounted at $mountpoint"

TIMEFORMAT="Total time spent running tests: %R"
time {
./tests/dd_tests.sh "$2" "$mountpoint"
./tests/hdparm_tests.sh "$1" "$2"
./tests/iozone_tests.sh "$1" "$2" "$mountpoint"
}

mv ./tests/dd_reads.csv ../all_results/"$(date +%d-%m-%y)"/"$3"
mv ./tests/dd_writes.csv ../all_results/"$(date +%d-%m-%y)"/"$3"
mv ./tests/hdparm_buffered.csv ../all_results/"$(date +%d-%m-%y)"/"$3"
mv ./tests/hdparm_cached.csv ../all_results/"$(date +%d-%m-%y)"/"$3"
mv iozone.csv ../all_results/"$(date +%d-%m-%y)"/"$3"
