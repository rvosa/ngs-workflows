#!/bin/bash

VERSION=0.002

echo "${0} version: ${VERSION}"
if [ $1 = '-v' ]; then
  exit
fi

# capture start time
echo "STARTING "`date`
echo "SELF HASHSUM: "`md5sum $0`

#This script is intended to demonstrate how bash shell scripting can be used to
#chain UNIX commands together. The workflow downloads the FASTQ file pairs of an
#Illumina Genome Analyser II PAIRED end run from EBI and aligns it against
#a reference genome of Plasmodium falciparum, the deadliest malaria parasite. The
#script depends on samtools and bwa, which can be downloaded and installed
#by running 'make' in this directory.

# where we will download the data
DATA=data/plasmodium
RESULTS_ROOT=results
RESULTS="${RESULTS_ROOT}/"`date | perl -pe 'chomp; s/\s+/\_/g'`

# location of a 282Mb Illumina Genome Analyzer II run, PAIRED, FASTQ
SAMPLEFILE_BASE=ERR022523
SAMPLEURL_BASE=ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR022/ERR022523
SAMPLEFILES=""

# location of a Plasmodium falciparum reference genome
REFERENCEFILE=Plasmodium_falciparum_OLD.fna
REFERENCEBASEURL=ftp://ftp.ncbi.nih.gov/genomes/Plasmodium_falciparum_OLD

# alignment file
ALIGNMENTSAIFILES=""
ALIGNMENTBAMFILE="${RESULTS}/aln.bam"
ALIGNMENTBAM="../../${RESULTS}/aln"
ALIGNEDBAMFILE="${RESULTS}/aligned.bam"
ALIGNEDBAM="${RESULTS}/aligned"
UNALIGNEDBAMFILE="${RESULTS}/unaligned.bam"
UNALIGNEDBAM="${RESULTS}/unaligned"

# accession numbers in the reference genome. Each is one chromosome.
ACCESSIONS="NC_004325 NC_000910 NC_000521 NC_004318 NC_004326 NC_004327 NC_004328 NC_004329 NC_004330 NC_004314 NC_004315 NC_004316 NC_004331 NC_004317"

# location of the tools we will use. it is assumed they can be found on the $PATH.
BWA=`pwd`/bin/bwa/bwa

# capture versions and hashsums of external scripts/programs
$BWA
md5sum $BWA

SAMTOOLS=`pwd`/bin/samtools/samtools
$SAMTOOLS
md5sum $SAMTOOLS

CURL=curl
$CURL --version
md5sum `which $CURL`

FILTERSAM=`pwd`/src/filter_sam.pl
$FILTERSAM -v

# make the data directory if it doesn't exist
if [ ! -d $DATA ]; then
	mkdir -p $DATA
fi

# make the results date subdirectory
if [ ! -d $RESULTS ]; then
    mkdir -p $RESULTS
fi

# download Illumina run (Paired FASTQ) of Plasmodium falciparum
for PAIR in 1 2; do
  SAMPLEFILE="${SAMPLEFILE_BASE}_${PAIR}.fastq"
  ALIGNMENTFILE="${SAMPLEFILE_BASE}_${PAIR}.sai"
  SAMPLEURL="${SAMPLEURL_BASE}/${SAMPLEFILE}.gz"
  if [ ! -e "${DATA}/${SAMPLEFILE}" ]; then
    echo "${CURL} ${SAMPLEURL} | gunzip > ${SAMPLEFILE}"
	cd $DATA
	$CURL $SAMPLEURL | gunzip > $SAMPLEFILE
    md5sum $SAMPLEFILE
	cd -
  fi

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

# download reference FASTA sequences
if [ ! -e "${DATA}/${REFERENCEFILE}" ]; then
	cd $DATA
	COUNTER=1
	for ACCESSION in $ACCESSIONS; do
		if [ ! -e "${ACCESSION}.fna" ]; then
            # fix the chromosome entries on the reference
            echo "${CURL} ${REFERENCEBASEURL}/CHR${COUNTER}/${ACCESSION}.fna | perl -pi -e 's/^\>gi.*chromosome\s(\d+).*/\>chr$1/g' >> ${REFERENCEFILE}"
			$CURL ${REFERENCEBASEURL}/CHR${COUNTER}/${ACCESSION}.fna | perl -pi -e 's/^\>gi.*chromosome\s(\d+).*/\>chr$1/g' >> ${REFERENCEFILE}
		fi
		COUNTER=$[COUNTER + 1]
	done
     md5sum $REFERENCEFILE
	cd -
fi

# do bwa index
if [ ! -e "$DATA/${REFERENCEFILE}.amb" ]; then
    echo "${BWA} index ${REFERENCEFILE}"
	cd $DATA
	$BWA index $REFERENCEFILE
    md5sum $REFERENCEFILE
	cd -
fi

# do bwa aln on each PAIR separately
for SAMPLEFILE in $SAMPLEFILES; do
  ALIGNMENTSAI=`echo $SAMPLEFILE | sed 's/fastq/sai/'`
  if [ ! -e "$DATA/$ALIGNMENTSAI" ]; then
	echo "${BWA} aln ${REFERENCEFILE} ${SAMPLEFILE} > ${ALIGNMENTSAI}"
	cd $DATA
    md5sum $SAMPLEFILE
	$BWA aln $REFERENCEFILE $SAMPLEFILE > $ALIGNMENTSAI
    md5sum $SAMPLEFILE $ALIGNMENTSAI
	cd -
  fi
done

# do bwa sampe on paired alignments to produce a single, sorted Bam file
if [ ! -e "{$ALIGNMENTBAMFILE}" ]; then
	echo "${BWA} sampe ${REFERENCEFILE} ${ALIGNMENTSAIFILES} ${SAMPLEFILES} | ${SAMTOOLS} view -bS - | ${SAMTOOLS} sort - ${ALIGNMENTBAM}"
	cd $DATA
    md5sum $REFERENCEFILE $ALIGNMENTSAIFILES $SAMPLEFILES
	$BWA sampe $REFERENCEFILE $ALIGNMENTSAIFILES $SAMPLEFILES | ${SAMTOOLS} view -bS - | $SAMTOOLS sort - $ALIGNMENTBAM
    md5sum $REFERENCEFILE $ALIGNMENTSAIFILES $SAMPLEFILES ${ALIGNMENTBAM}.bam
    echo "REMOVING INTERMEDIATE ${ALIGNMENTSAIFILES}"
    rm $ALIGNMENTSAIFILES
	cd -
fi

# split bam into aligned and unaligned sorted bam files using filter_sam.pl
if [ ! -e "${ALIGNEDBAMFILE}" ] || [ ! -e "${UNALIGNEDBAMFILE}" ]; then
  if [ ! -e "${ALIGNEDBAMFILE}" ]; then
    echo "${SAMTOOLS} view -h ${ALIGNMENTBAMFILE} | ${FILTERSAM} -a | ${SAMTOOLS} view -bS - | $SAMTOOLS sort - $ALIGNEDBAM"
    md5sum $ALIGNMENTBAMFILE
    ${SAMTOOLS} view -h $ALIGNMENTBAMFILE | $FILTERSAM -a | $SAMTOOLS view -bS - | $SAMTOOLS sort - $ALIGNEDBAM
    md5sum $ALIGNMENTBAMFILE $ALIGNEDBAMFILE
  fi
  if [ ! -e "${UNALIGNEDBAMFILE}" ]; then
    echo "${SAMTOOLS} view -h ${ALIGNMENTBAMFILE} | ${FILTERSAM} -u | ${SAMTOOLS} view -bS - | $SAMTOOLS sort - $UNALIGNEDBAM"
    md5sum $ALIGNMENTBAMFILE
    ${SAMTOOLS} view -h $ALIGNMENTBAMFILE | $FILTERSAM -u | $SAMTOOLS view -bS - | $SAMTOOLS sort - $UNALIGNEDBAM
    md5sum $ALIGNMENTBAMFILE $UNALIGNEDBAMFILE
  fi
  md5sum $ALIGNMENTBAMFILE
  echo "REMOVING INTERMEDIATE ${ALIGNMENTBAMFILE}"
  rm $ALIGNMENTBAMFILE
fi

#add the result bam files to the repository
git add $ALIGNEDBAMFILE $UNALIGNEDBAMFILE

# capture start time
echo "COMPLETED "`date`
exit