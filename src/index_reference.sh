#!/bin/bash

DATA=data/plasmodium
REFERENCEFILE=Plasmodium_falciparum_OLD.fna

cd $DATA

# make the data directory if it doesn't exist
if [ ! -e ${REFERENCEFILE} ]; then
	echo "${REFERENCEFILE} DOES NOT EXIST in ${DATA}!"
    exit 1
fi

# do bwa index
if [ ! -e "${REFERENCEFILE}.amb" ]; then
    echo "bwa index ${REFERENCEFILE}"
	bwa index $REFERENCEFILE
fi

cd -
