#!/bin/bash

echo "Starting duskin.pl"

export CURRDIR=`pwd`
export FILENAME=`date +%Y%m%d-%H%M%S`
export F_STDOUT=$CURRDIR/logs/duskin-$FILENAME.stdout
export F_STDERR=$CURRDIR/logs/duskin-$FILENAME.stderr

echo Standard output: $F_STDOUT
echo Standard error: $F_STDERR

$CURRDIR/duskin.pl 1>$F_STDOUT 2>$F_STDERR &

echo [$$] Started
