#!/bin/bash

echo "Starting duskin-bridge.pl"
export CURRDIR=`dirname $0`

# export CURRDIR=`pwd`
export FILENAME=`date +%Y%m%d-%H%M%S`
export F_STDOUT=$CURRDIR/logs/duskin-bridge-$FILENAME.stdout
export F_STDERR=$CURRDIR/logs/duskin-bridge-$FILENAME.stderr

echo Standard output: $F_STDOUT
echo Standard error: $F_STDERR

$CURRDIR/duskin-bridge.pl 1>$F_STDOUT 2>$F_STDERR &

echo [$$] Started
