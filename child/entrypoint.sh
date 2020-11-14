#!/bin/sh -l

echo "Child!!!"

echo "Hello $1 $2 $3"
time=$(date)
echo "::set-output name=time::$time"

echo current location
pwd

echo current dir contents
ls -al
