#!/bin/sh

mkdir -p t

for g in a b c d e f g
do
	for nt in 1 2 5 10 20 50 100 200 500 1000 2000 5000
	do
		perl synthtest.pl $nt > "t/$g$nt.t"
	done
done