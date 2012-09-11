VERSION := Plasmodium Makefile Version 0.002
DATE := $(shell date +%a_%b_%d_%Y_%T)

BIN := bin
BWA := $(BIN)/bwa/bwa
SAMTOOLS := $(BIN)/samtools/samtools
FILTERSAM := src/filter_sam.pl

DATA := data/plasmodium
REFERENCE := $(DATA)/Plasmodium_falciparum_OLD.fna
INDEXED_REFERENCE := $(DATA)/Plasmodium_falciparum_OLD.fna.amb
PAIR1 := $(DATA)/ERR022523_1.fastq
PAIR1_SAI := $(DATA)/ERR022523_1.sai
PAIR2 := $(DATA)/ERR022523_2.fastq
PAIR2_SAI := $(DATA)/ERR022523_2.sai

RESULTS := results
RESULTSDIR := $(RESULTS)/$(DATE)
BAMFILE = aln.bam
ALIGNEDBAMFILE := aligned.bam
UNALIGNEDBAMFILE := unaligned.bam

all : build_resultsdir $(INDEXED_REFERENCE) $(PAIR1_SAI) $(PAIR2_SAI) $(BAMFILE) $(ALIGNEDBAMFILE) $(UNALIGNEDBAMFILE) clean

build_resultsdir :
	echo $(VERSION)
	md5sum Makefile
	mkdir -p $(RESULTSDIR)
	md5sum $(BWA)
	md5sum $(SAMTOOLS)

$(INDEXED_REFERENCE) :
	md5sum $(REFERENCE)
	$(BWA) index $(REFERENCE)
	md5sum $(REFERENCE)
	md5sum $(INDEXED_REFERENCE)

$(PAIR1_SAI) : $(INDEXED_REFERENCE)
	md5sum $(PAIR1)
	$(BWA) aln $(REFERENCE) $(PAIR1) > $(PAIR1_SAI)
	md5sum $(PAIR1)
	md5sum $(PAIR1_SAI)

$(PAIR2_SAI) : $(INDEXED_REFERENCE)
	md5sum $(PAIR2)
	$(BWA) aln $(REFERENCE) $(PAIR2) > $(PAIR2_SAI)
	md5sum $(PAIR2)
	md5sum $(PAIR2_SAI)

$(BAMFILE) : $(PAIR1_SAI) $(PAIR2_SAI) build_resultsdir
	md5sum $(PAIR1)
	md5sum $(PAIR1_SAI)
	md5sum $(PAIR2)
	md5sum $(PAIR2_SAI)
	$(BWA) sampe $(REFERENCE) $(PAIR1_SAI) $(PAIR2_SAI) $(PAIR1) $(PAIR2) | $(SAMTOOLS) view -bS - | $(SAMTOOLS) sort - $(RESULTSDIR)/aln
	md5sum $(PAIR1)
	md5sum $(PAIR1_SAI)
	rm $(PAIR1_SAI)
	md5sum $(PAIR2)
	md5sum $(PAIR2_SAI)
	rm $(PAIR2_SAI)
	md5sum $(RESULTSDIR)/aln.bam

$(ALIGNEDBAMFILE) : $(BAMFILE) build_resultsdir
	md5sum $(RESULTSDIR)/aln.bam
	$(SAMTOOLS) view -h $(RESULTSDIR)/$(BAMFILE) | $(FILTERSAM) -a | $(SAMTOOLS) view -bS - | $(SAMTOOLS) sort - $(RESULTSDIR)/aligned
	md5sum $(RESULTSDIR)/aln.bam
	md5sum $(RESULTSDIR)/aligned.bam

$(UNALIGNEDBAMFILE) : $(BAMFILE)
	md5sum $(RESULTSDIR)/aln.bam
	$(SAMTOOLS) view -h $(RESULTSDIR)/$(BAMFILE) | $(FILTERSAM) -u | $(SAMTOOLS) view -bS - | $(SAMTOOLS) sort - $(RESULTSDIR)/unaligned
	md5sum $(RESULTSDIR)/aln.bam
	md5sum $(RESULTSDIR)/unaligned.bam

clean :
	rm $(RESULTSDIR)/$(BAMFILE)
	git add $(RESULTSDIR)
	git commit -m "NEW RESULTS ADDED"
