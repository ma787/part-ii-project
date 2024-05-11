#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

cd "$CWD" || exit

for i in $(seq "$1") 
do
for j in 7 8 9 10
	do
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches" # clears the memory cache
		dd if=/dev/zero of="$2"/null_data bs=1M count=$(2**j) conv=fdatasync 2>o.txt
		echo "dd write test run $i out of $1 completed"
    	./get_dd_throughput.sh -i ./o.txt -o "dd_writes.csv"
    done
done

for i in $(seq "$1") 
do
	for j in 7 8 9 10
	do
    	sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
    	dd if="$2"/null_data of=/dev/null bs=1M count=$(2**j) 2>o.txt
    	echo "dd write test run $i out of $1 completed"
    	./get_dd_throughput.sh -i ./o.txt -o "dd_reads.csv"
    done
done

rm ./o.txt
rm "$2"/null_data
chmod a+rw ./dd_writes.csv
chmod a+rw ./dd_reads.csv

cd - || exit
