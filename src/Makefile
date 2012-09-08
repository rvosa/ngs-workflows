# simple makefile to get prerequisites
BIN=../bin
SVN=svn
GIT=git
SAMTOOLS=$(BIN)/samtools/samtools
SAMREPO=https://samtools.svn.sourceforge.net/svnroot/samtools/trunk/samtools
BWA=$(BIN)/bwa/bwa
BWAREPO=git://github.com/lh3/bwa.git

all : samtools bwa

samtools : $(SAMTOOLS)

bwa : $(BWA)

$(SAMTOOLS) :
	cd $(BIN) && $(SVN) co $(SAMREPO) && cd samtools && make

$(BWA) :
	cd $(BIN) && $(GIT) clone $(BWAREPO) && cd bwa && make
