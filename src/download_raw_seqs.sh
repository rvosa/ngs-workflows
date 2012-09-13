#!/bin/bash
# use curl to download the gzipped version of each PAIR
# fastq file to STDOUT, pipe it through gunzip to uncompress
# it for immediate use

DATA=data/plasmodium
SAMPLEFILE_BASE=ERR022523
SAMPLEURL_BASE=ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR022/ERR022523

# make the data directory if it doesn't exist
if [ ! -d $DATA ]; then
	mkdir -p $DATA
fi

for PAIR in 1 2; do
  SAMPLEFILE="${SAMPLEFILE_BASE}_${PAIR}.fastq"
  SAMPLEURL="${SAMPLEURL_BASE}/${SAMPLEFILE}.gz"
  if [ ! -e "${DATA}/${SAMPLEFILE}" ]; then
    echo "${CURL} ${SAMPLEURL} | gunzip > ${SAMPLEFILE}"
	cd $DATA
	curl $SAMPLEURL | gunzip > $SAMPLEFILE
	cd -
  fi
done
exit
