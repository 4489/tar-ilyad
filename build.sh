#!/usr/bin/env bash

#------------------------------------------------------------------------------
#  description  :  build (and run)
#
#  created      :  Sun Feb 05, 2017  01:21:59 PM
#  modified     :  Thu Oct 12, 2017  12:30:50 PM
#------------------------------------------------------------------------------

set -e

# data
convert pang.jpg -resize 192x192! -blur 1x1 -type palette -depth 4 -compress none tile.tif
cp      pang.pal tile.pal

# code
vasmm68k_mot -m68000 -Fbin -nosym -spaces -o demo.bin demo.asm

# run
# -- removed --
