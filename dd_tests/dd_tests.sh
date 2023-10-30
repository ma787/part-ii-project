#!/bin/bash
for i in {1..100}
do
    dd if=/dev/sda1 of=speetest bs=512k count=3200 conv=fdatasync 2>o.txt
    ./get_dd_throughput.sh -i ./o.txt -o "dd_writes.csv"
done

for i in {1..100}
do
    dd if=speetest of=/dev/sda1 bs=512k count=400 conv=fdatasync 2>o.txt
    ./get_dd_throughput.sh -i ./o.txt -o "dd_reads.csv"
done

rm ./o.txt
rm speetest
chmod a+rw ./dd_writes.csv
chmod a+rw ./dd_reads.csv
