#!/bin/sh -l

# We can have more than one action per repository it seems!
echo "Child!!!"

echo "Hello $1 $2 $3"
time=$(date)
echo "::set-output name=time::$time"

echo current location
pwd

echo current dir contents
ls -al
