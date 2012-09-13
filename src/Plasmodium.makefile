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
	mkdir -p $(RESULTSDIR)

$(INDEXED_REFERENCE) :
	$(BWA) index $(REFERENCE)

$(PAIR1_SAI) : $(INDEXED_REFERENCE)
	$(BWA) aln $(REFERENCE) $(PAIR1) > $(PAIR1_SAI)

$(PAIR2_SAI) : $(INDEXED_REFERENCE)
	$(BWA) aln $(REFERENCE) $(PAIR2) > $(PAIR2_SAI)

$(BAMFILE) : $(PAIR1_SAI) $(PAIR2_SAI) build_resultsdir
	$(BWA) sampe $(REFERENCE) $(PAIR1_SAI) $(PAIR2_SAI) $(PAIR1) $(PAIR2) | $(SAMTOOLS) view -bS - | $(SAMTOOLS) sort - $(RESULTSDIR)/aln

$(ALIGNEDBAMFILE) : $(BAMFILE) build_resultsdir
	$(SAMTOOLS) view -h $(RESULTSDIR)/$(BAMFILE) | $(FILTERSAM) -a | $(SAMTOOLS) view -bS - | $(SAMTOOLS) sort - $(RESULTSDIR)/aligned

$(UNALIGNEDBAMFILE) : $(BAMFILE)
	$(SAMTOOLS) view -h $(RESULTSDIR)/$(BAMFILE) | $(FILTERSAM) -u | $(SAMTOOLS) view -bS - | $(SAMTOOLS) sort - $(RESULTSDIR)/unaligned

clean :
	rm $(RESULTSDIR)/$(BAMFILE)
