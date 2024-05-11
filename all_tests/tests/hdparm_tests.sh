#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
PDIR="${CWD%/*}"

cd $CWD

for i in $(seq "$2") 
do
    hdparm -tT $1 > o.txt
    ./get_hdparm_throughput.sh -i ./o.txt -c "hdparm_cached.csv" -b "hdparm_buffered.csv"
    echo "hdparm run $i out of $2 completed"
done

rm ./o.txt
chmod a+rw ./hdparm_cached.csv
chmod a+rw ./hdparm_buffered.csv

cd -
