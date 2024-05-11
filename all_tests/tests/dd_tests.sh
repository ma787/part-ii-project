#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

cd "$CWD" || exit

for i in $(seq "$1") 
do
for j in 7 8 9 10
	do
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
		dd if=/dev/zero of="$2"/null_data bs=$((2**j*1024)) count=1024 conv=fdatasync 2>o.txt
		echo "dd write test run $i out of $1 completed"
    	./get_dd_throughput.sh -i ./o.txt -o "dd_writes.csv"
    done
    i=$((i+1))
done

for i in $(seq "$1") 
do
	for j in 7 8 9 10
	do
    	sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
    	dd if="$2"/null_data of=/dev/null bs=$((2**j*1024)) count=1024 2>o.txt
    	echo "dd write test run $i out of $1 completed"
    	./get_dd_throughput.sh -i ./o.txt -o "dd_reads.csv"
    done
    i=$((i+1))
done

rm ./o.txt
rm "$2"/null_data
chmod a+rw ./dd_writes.csv
chmod a+rw ./dd_reads.csv

cd - || exit
