#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

cd "$CWD" || exit

for i in $(seq "$1") 
do
for j in 0 1 2 3
	do
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches" # clears the memory cache
		dd if=/dev/zero of="$2"/null_data bs=$((4096*2**j)) count=32K conv=fdatasync 2>o.txt
    	./get_dd_throughput.sh -i ./o.txt -o "dd_writes.csv"
    done
	echo "dd write test run $i out of $1 completed"
done

for i in $(seq "$1") 
do
	for j in 0 1 2 3
	do
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
    	dd if="$2"/null_data of=/dev/null bs=$((4096*2**j)) count=32K 2>o.txt
    	./get_dd_throughput.sh -i ./o.txt -o "dd_reads.csv"
    done
	echo "dd read test run $i out of $1 completed"
done

rm ./o.txt
rm "$2"/null_data
chmod a+rw ./dd_writes.csv
chmod a+rw ./dd_reads.csv

cd - || exit
