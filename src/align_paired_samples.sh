#!/bin/bash

DATA=data/plasmodium
SAMPLEFILE_BASE=${DATA}/ERR022523
REFERENCEFILE=${DATA}/Plasmodium_falciparum_OLD.fna

# do bwa aln on each PAIR separately
for SAMPLEFILE in ${SAMPLEFILE_BASE}/*fastq; do
  ALIGNMENTSAI=`echo $SAMPLEFILE | sed 's/fastq/sai/'`
  if [ ! -e "$ALIGNMENTSAI" ]; then
	echo "bwa aln ${REFERENCEFILE} ${SAMPLEFILE} > ${ALIGNMENTSAI}"
	bwa aln $REFERENCEFILE $SAMPLEFILE > $ALIGNMENTSAI
  fi
done
