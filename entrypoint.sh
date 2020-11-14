#!/bin/sh -l

echo "Hello $1 $2 $3"
time=$(date)
echo "::set-output name=time::$time"

echo current location
pwd

echo current dir contents
ls -al


echo Tool location
TOOL=/multi-repo-ci-tool-runner
ls -al ${TOOL}

echo Look for Java
java -version
