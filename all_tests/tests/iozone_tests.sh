#!/bin/bash

mkdir -p iozoneout
for i in {1..100}
do
	if [ $i -lt 10 ]
	then
		iozone -a /dev/sda1 > iozone-00$((i)).out
		cp iozone-00$((i)).out iozoneout
	elif [ $i -lt 100 ]
	then
		iozone -a /dev/sda1 > iozone-0$((i)).out
		cp iozone-0$((i)).out iozoneout
	else
		iozone -a /dev/sda1 > iozone-$((i)).out
		cp iozone-$((i)).out iozoneout
	fi
done
ls iozoneout | xargs > f.txt
cat f.txt | xargs python3 /home/mohamed/Project/all_tests/iozone2csv.py
rm f.txt
rm -rf iozoneout
for i in {1..100}
do
	if [ $i -lt 10 ]
	then
		rm iozone-00$((i)).out
	elif [ $i -lt 10 ]
	then
		rm iozone-0$((i)).out
	else
		rm iozone-$((i)).out
	fi
done
