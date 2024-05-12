#!/bin/bash

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
PDIR="${CWD%/*}"

cd "$3" || exit

mkdir -p "$PDIR"/iozoneout
for i in $(seq "$2")
do
	if [ "$i" -lt 10 ]
	then
		iozone -a "$1" > "$PDIR"/iozoneout/iozone-00$((i)).out
	elif [ "$i" -lt 100 ]
	then
		iozone -a "$1" > "$PDIR"/iozoneout/iozone-0$((i)).out
	else
		iozone -a "$1" > "$PDIR"/iozoneout/iozone-$((i)).out
	fi
	echo "iozone run $i out of $2 completed"
done

cd "$PDIR"/iozoneout || exit

ls | xargs > f.txt
cp "$PDIR"/iozone2csv.py $PWD
cat f.txt | xargs python3 "$PWD"/iozone2csv.py

cd "$PDIR" || exit

rm -rf iozoneout
