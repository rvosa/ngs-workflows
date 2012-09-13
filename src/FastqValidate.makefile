DATA = ../data/fastq
FASTQD = $(wildcard $(DATA)/*.fastq)
FASTQC = $(patsubst %.fastq,%.out,$(FASTQD))

.PHONY : all clean

all : $(FASTQC)

clean :
	rm $(FASTQC)

$(FASTQC) : %.out : %.fastq
	perl ../bin/fastqvalidate.pl -i $< -o $@