#!/bin/bash

mkdir -p results

./tests/dd_tests.sh
./tests/hdparm_tests.sh $1
./tests/iozone_tests.sh $1

mv ./tests/dd_reads.csv results
mv ./tests/dd_writes.csv results
mv ./tests/hdparm_buffered.csv results
mv ./tests/hdparm_cached.csv results
mv iozone.csv results
