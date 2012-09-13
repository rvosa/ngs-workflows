#!/bin/bash

# where we will download the data
DATA=data/plasmodium

# location of a Plasmodium falciparum reference genome
REFERENCEFILE=Plasmodium_falciparum_OLD.fna
REFERENCEBASEURL=ftp://ftp.ncbi.nih.gov/genomes/Plasmodium_falciparum_OLD

# accession numbers in the reference genome. Each is one chromosome.
ACCESSIONS="NC_004325 NC_000910 NC_000521 NC_004318 NC_004326 NC_004327 NC_004328 NC_004329 NC_004330 NC_004314 NC_004315 NC_004316 NC_004331 NC_004317"

CURL=curl

# make the data directory if it doesn't exist
if [ ! -d $DATA ]; then
	mkdir -p $DATA
fi

# download reference FASTA sequences
if [ ! -e "${DATA}/${REFERENCEFILE}" ]; then
	cd $DATA
	COUNTER=1
	for ACCESSION in $ACCESSIONS; do
		if [ ! -e "${ACCESSION}.fna" ]; then
            # fix the chromosome entries on the reference
            echo "${CURL} ${REFERENCEBASEURL}/CHR${COUNTER}/${ACCESSION}.fna >> ${REFERENCEFILE}.wrong_headers"
			$CURL ${REFERENCEBASEURL}/CHR${COUNTER}/${ACCESSION}.fna >> ${REFERENCE}.wrong_headers
		fi
		COUNTER=$[COUNTER + 1]
	done
	cd -
fi

# this perl process changes the downloaded reference fasta file.
# it simplifies the fasta headers to just contain the chromosome,
# and nothing else this is necessary because the header value will
# end up in the sam file for each read that maps.  If you use
# the original fasta headers, it will introduce whitespace
# into the sam entry that will make parsing the entry in other
# programs impossible.
echo "perl -pi -e 's/^\>gi.*chromosome\s(\d+).*/\>chr$1/g' >> ${REFERENCEFILE}.wrong_headers > ${REFERENCEFILE}"
perl -pi -e 's/^\>gi.*chromosome\s(\d+).*/\>chr$1/g' >> ${REFERENCEFILE}.wrong_headers > ${REFERENCEFILE}
