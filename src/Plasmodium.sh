#!/bin/bash
# http://tldp.org/LDP/abs/html/
PATH=$PATH:../bin/bwa:../bin/samtools

# where we will download the data
DATA=../data/plasmodium

# location of a 282Mb Illumina Genome Analyzer II run, PAIRED, FASTQ
SAMPLEFILE=ERR022523_1.fastq
SAMPLEURL=ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR022/ERR022523/${SAMPLEFILE}.gz

# location of a Plasmodium falciparum reference genome
REFERENCEFILE=Plasmodium_falciparum_OLD.faa
REFERENCEBASEURL=ftp://ftp.ncbi.nih.gov/genomes/Plasmodium_falciparum_OLD

# alignment file
ALIGNMENTSAI=aln_sa.sai
ALIGNMENTSAM=aln.sam
ALIGNMENTBAM=aln.bam

# accession numbers in the reference genome. Each is one chromosome.
ACCESSIONS="NC_004325 NC_000910 NC_000521 NC_004318 NC_004326 NC_004327 NC_004328 NC_004329 NC_004330 NC_004314 NC_004315 NC_004316 NC_004331 NC_004317"

# location of the tools we will use. it is assumed they can be found on the $PATH.
BWA=bwa
SAMTOOLS=samtools
CURL=curl

# download Illumina run (Paired FASTQ) of Plasmodium falciparum
if [ ! -e "$DATA/$SAMPLEFILE" ]; then
	cd $DATA
	$CURL -O $SAMPLEURL
	gunzip "${SAMPLEFILE}.gz"
	cd -
fi

# download reference FASTA sequences
if [ ! -e "$DATA/$REFERENCEFILE" ]; then
	cd $DATA
	COUNTER=1
	for ACCESSION in $ACCESSIONS; do
		if [ ! -e "${ACCESSION}.faa" ]; then 
			$CURL -O "${REFERENCEBASEURL}/CHR${COUNTER}/${ACCESSION}.faa"	
		fi
		cat "${ACCESSION}.faa" >> $REFERENCEFILE
		COUNTER=$[COUNTER + 1]
	done
	cd -
fi

# do bwa aln
if [ ! -e "$DATA/$ALIGNMENTSAI" ]; then
	cd $DATA
	$BWA aln $REFERENCEFILE $SAMPLEFILE > $ALIGNMENTSAI
	cd -
fi

# do bwa samse
if [ ! -e "$DATA/$ALIGNMENTSAM" ]; then
	cd $DATA
	$BWA samse $REFERENCEFILE $ALIGNMENTSAI $SAMPLEFILE > $ALIGNMENTSAM
	cd -
fi

# make bam file
if [ ! -e "$DATA/$ALIGNMENTBAM" ]; then
	cd $DATA
	$SAMTOOLS view -b -h $ALIGNMENTSAM > $ALIGNMENTBAM
	cd -
fi