# location of perl, this can be modified to add include paths ( -Ipath/) etc.
PERL := perl

# sets verbosity level of the logger object
VERBOSITY := -v -v -v

# location of scripts and binaries
BIN := ../bin

# data directory for this workflow
DATA := ../data/orchids

# the serial numbers for all genbank plant (and fungi) sequence files
GBINDICES := 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 \
26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 \
52 53 54 55 56 57

# constructs local file names for the genbank files
GBFILES := $(patsubst %, $(DATA)/gbpln%.seq.gz, $(GBINDICES))

# transforms local genbank names in fasta names
FASTAFILES := $(patsubst %.seq.gz,%.fas.gz,$(GBFILES))

# concatenated FASTA file of fungal sequences
FUNGIFASTA := $(DATA)/fungi.fas

# target file produced by standalone BLAST indexing
FORMATDB := $(DATA)/formatdb.log

# short read archives
READS1 := $(DATA)/R11-002-reg1_454Reads.MID2
READS2 := $(DATA)/R10-005_454reads-reg03.GSMIDSMID4
CHUNKS := 1 2 3 4
READCHUNKS1 := $(patsubst %, $(READS1).%.fa.gz, $(CHUNKS))
READCHUNKS2 := $(patsubst %, $(READS2).%.fa.gz, $(CHUNKS))
READBLAST1 := $(patsubst %.fa.gz,%.txt, $(READCHUNKS1))
READBLAST2 := $(patsubst %.fa.gz,%.txt, $(READCHUNKS2))
CHUNKTABLE1 := $(READS1).log
CHUNKTABLE2 := $(READS2).log

.PHONY : all

all : $(FORMATDB) $(READCHUNKS1) $(READCHUNKS2) $(READBLAST1) $(READBLAST2)

# downloads the genbank files for plants and fungi
$(GBFILES) :
	cd $(DATA) && curl -O ftp://ftp.ncbi.nih.gov/genbank/$(@F)

# converts genbank format to fasta for the provided higher taxon
$(FASTAFILES) : %.fas.gz : %.seq.gz
	zcat $< | $(PERL) $(BIN)/gb2fasta.pl --keep=Fungi $(VERBOSITY) | gzip -9 > $@

# concatenates fasta files as input for local blast
$(FUNGIFASTA) : $(GBFILES) $(FASTAFILES)
	zcat $(FASTAFILES) > $@

# indexes concatenated fasta file for local blast
$(FORMATDB) : $(FUNGIFASTA)
	formatdb -i $< -p F -l $@

# convert sff to fasta in chunks
$(CHUNKTABLE1) : 
	zcat $(READS1).sff.gz | $(PERL) $(BIN)/sff2fasta.pl -n 4 -e 'fa.gz' -b $(READS1) $(VERBOSITY) 2> $@

# convert sff to fasta in chunks
$(CHUNKTABLE2) :
	zcat $(READS2).sff.gz | $(PERL) $(BIN)/sff2fasta.pl -n 4 -e 'fa.gz' -b $(READS2) $(VERBOSITY) 2> $@

# these dependency chains are necessary to ensure chunking is done in serial
$(READCHUNKS1) : $(CHUNKTABLE1)

$(READCHUNKS2) : $(CHUNKTABLE2)

$(READBLAST1) : $(READCHUNKS1)

$(READBLAST2) : $(READCHUNKS2)

# does the blasting
%.txt : %.fa.gz
	zcat $< | $(PERL) $(BIN)/taxonblast.pl -d $(FUNGIFASTA) $(VERBOSITY) > $@