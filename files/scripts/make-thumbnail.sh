#!/usr/bin/env bash

# Make a thumbnail for each PNG
for i in *.png; do

  FILENAME=$(basename -- "$i") # Full filename
  EXTENSION="${FILENAME##*.}" # Extension only
  FILENAME="${FILENAME%.*}" # Filename without extension

  convert "$i" -thumbnail 500 "$FILENAME-thumb.$EXTENSION";

done;
