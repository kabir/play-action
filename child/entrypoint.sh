#!/bin/sh -l

echo "Child!!!"

echo "Hello $1 $2 $3"
time=$(date)
echo "::set-output name=time::$time"

echo current location
pwd

echo current dir contents
ls -al

echo ---------
echo ENV
env
echo --------

echo Tool location
TOOL=/multi-repo-ci-tool-runner
ls -al ${TOOL}

#echo Look for Java
#java -version

echo root folder
ls -al /

echo root folder
ls -al /opt
