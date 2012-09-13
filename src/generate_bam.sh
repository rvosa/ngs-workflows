#!/bin/bash
# do bwa sampe on paired alignments to produce a single, sorted Bam file

DATA=data/plasmodium
SAMPLEFILE_BASE=${DATA}/ERR022523
REFERENCEFILE=${DATA}/Plasmodium_falciparum_OLD.fna
RESULTS_ROOT=results
RESULTS="${RESULTS_ROOT}/"`date +%Y_%b_%d`
ALIGNMENTBAMFILE=${RESULTS}/aln.bam
ALIGNMENTBAM=${RESULTS}/aln
REFERENCEFILE=${DATA}/Plasmodium_falciparum_OLD.fna

# make the results date subdirectory
if [ ! -d $RESULTS ]; then
    mkdir -p $RESULTS
fi

SAMPLEFILES=""
ALIGNMENTSAIFILES=""
for PAIR in 1 2; do
  SAMPLEFILE="${SAMPLEFILE_BASE}_${PAIR}.fastq"
  ALIGNMENTFILE="${SAMPLEFILE_BASE}_${PAIR}.sai"

  if [ -z $ALIGNMENTSAIFILES ]; then
    ALIGNMENTSAIFILES=$ALIGNMENTFILE
  else
    ALIGNMENTSAIFILES="${ALIGNMENTSAIFILES} ${ALIGNMENTFILE}"
  fi

  if [ -z $SAMPLEFILES ]; then
    SAMPLEFILES=$SAMPLEFILE
  else
    SAMPLEFILES="${SAMPLEFILES} ${SAMPLEFILE}"
  fi

done

if [ ! -e "{$ALIGNMENTBAMFILE}" ]; then
	echo "bwa sampe ${REFERENCEFILE} ${ALIGNMENTSAIFILES} ${SAMPLEFILES} | samtools view -bS - | samtools sort - ${ALIGNMENTBAM}"
	bwa sampe $REFERENCEFILE $ALIGNMENTSAIFILES $SAMPLEFILES | samtools view -bS - | samtools sort - $ALIGNMENTBAM
fi
