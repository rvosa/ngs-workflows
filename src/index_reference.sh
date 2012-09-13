#!/bin/bash

DATA=data/plasmodium
REFERENCEFILE=${DATA}/Plasmodium_falciparum_OLD.fna

# make the data directory if it doesn't exist
if [ ! -e $REFERENCEFILE ]; then
	echo "${REFERENCEFILE} DOES NOT EXIT!"
    exit 1
fi

# do bwa index
if [ ! -e "$DATA/${REFERENCEFILE}.amb" ]; then
    echo "bwa index ${REFERENCEFILE}"
	bwa index $REFERENCEFILE
fi
