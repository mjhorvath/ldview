#!/bin/sh
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX=`kde4-config --prefix` ..
