#!/bin/bash

mkdir -p results

./tests/dd_tests.sh
./tests/hdparm_tests.sh
./tests/iozone_tests.sh

mv dd_reads.csv results
mv dd_writes.csv results
mv hdparm_buffered.csv results
mv hdparm_cached.csv results
mv iozone.csv results
