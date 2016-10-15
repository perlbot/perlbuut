#!/bin/bash

mkdir -p jail
mkdir -p jail/perl5
mkdir -p jail/lib
mkdir -p jail/usr/lib
mkdir -p jail/dev
mknod jail/dev/urandom c 1 9
