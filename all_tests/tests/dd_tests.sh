#!/bin/bash

for i in {1..100}
do
	for i in 7 8 9 10
	do
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
		dd if=/dev/zero of=/mnt/speetest bs=$((2**i*1024)) count=1024 conv=fdatasync 2>o.txt
    	/home/mohamed/Project/all_tests/tests/get_dd_throughput.sh -i ./o.txt -o "dd_writes.csv"
    done
done

for i in {1..100}
do
	for i in 7 8 9 10
	do
    	sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
    	dd if=/mnt/speetest of=/dev/null bs=$((2**i*1024)) count=1024 2>o.txt
    	/home/mohamed/Project/all_tests/tests/get_dd_throughput.sh -i ./o.txt -o "dd_reads.csv"
    done
done

rm ./o.txt
rm /mnt/speetest
chmod a+rw ./dd_writes.csv
chmod a+rw ./dd_reads.csv
