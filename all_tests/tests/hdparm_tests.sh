#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
PDIR="${CWD%/*}"

cd $CWD

for i in {1..100}
do
    hdparm -tT $1 > o.txt
    ./get_hdparm_throughput.sh -i ./o.txt -c "hdparm_cached.csv" -b "hdparm_buffered.csv"
done

rm ./o.txt
chmod a+rw ./hdparm_cached.csv
chmod a+rw ./hdparm_buffered.csv

cd -
