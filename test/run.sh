#!/bin/bash

# bail on error
set -e

DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )

# Note: dartanalyzer needs to be run from the root directory for proper path
# canonicalization.
pushd $DIR/..
echo Analyzing library for warnings or type errors
dartanalyzer --fatal-warnings lib/*.dart lib/impl/*.dart \
  || echo -e "Ignoring analyzer errors"

for fn in `grep -l 'main[(][)]' test/*.dart`; do
	echo Analyzing $fn
	dartanalyzer --fatal-warnings lib/*.dart \
  	|| echo -e "Ignoring analyzer errors"
done

rm -rf out/*
popd

dart --enable-type-checks --enable-asserts test/run_all.dart $@
