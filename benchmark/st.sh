#!/bin/sh

if [ ! -d tmixed ] ; then
	# Mixed tests
	echo Making mixed tests
	mkdir -p tmixed
	for g in a b c d e f g ; do
		for nt in 1 2 5 10 20 50 100 200 500 1000 2000 5000 ; do
			perl synthtest.pl $nt > "tmixed/$g$nt.t"
		done
	done
fi

if [ ! -d tmany ] ; then
	# Lots of small tests
	echo Making lots of small tests
	mkdir -p tmany
	for i in 0 1 2 3 4 5 6 7 8 9 ; do
		for j in 0 1 2 3 4 5 6 7 8 9 ; do
			for k in 0 1 2 3 4 5 6 7 8 9 ; do
				perl synthtest.pl 1 > "tmany/$i$j$k.t"
			done
		done
	done
fi

if [ ! -d tmassive ] ; then
	# One huge test
	echo Making one huge test
	mkdir -p tmassive
	perl synthtest.pl 100000 > tmassive/huge.t
fi

for d in tmixed tmany tmassive ; do
	echo "Testing against $d"
	echo '-----------------------------'
	for tool in prove runtests ; do
		echo "Testing $tool against $d"
		time $tool $d > /dev/null
		echo
	done
	echo '-----------------------------'; echo
done
