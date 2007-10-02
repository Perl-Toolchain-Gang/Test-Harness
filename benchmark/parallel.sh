#!/bin/sh
for set in pt/fast pt/fickle pt/greedy pt/gross pt/lazy pt
do
    for args in '' '-j9' '-j4' '-j32' '-j9 --fork' '-j4 --fork' '-j32 --fork'
    do
        echo "Running prove -rQ $args $set"
        prove -rQ $args $set
    done
	echo ----------------------------------------
done
