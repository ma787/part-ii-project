#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
PDIR="${CWD%/*}"

cd "$3" || exit

mkdir -p "$PDIR"/iozoneout
for i in $(seq "$2")
do
	if [ "$i" -lt 10 ]
	then
		iozone -a "$1" > "$PDIR"/iozone-00$((i)).out
	elif [ "$i" -lt 100 ]
	then
		iozone -a "$1" > "$PDIR"/iozone-0$((i)).out
	else
		iozone -a "$1" > "$PDIR"/iozone-$((i)).out
	fi
	echo "iozone run $i out of $2 completed"
done

cd "$PDIR" || exit

ls iozoneout | xargs > f.txt
cat f.txt | xargs python3 ./iozone2csv.py
rm f.txt
rm -rf iozoneout
for i in $(seq "$2")
do
	if [ $i -lt 10 ]
	then
		rm iozone-00$((i)).out
	elif [ $i -lt 100 ]
	then
		rm iozone-0$((i)).out
	else
		rm iozone-$((i)).out
	fi
done
