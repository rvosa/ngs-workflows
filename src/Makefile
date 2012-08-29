# run with the 'make' (or 'make -j 4') command
DATA=../data
BIN=../bin
PERL=perl
PYTHON=python
R=r
SH=bash
SVN=svn
SAMTOOLS=$(BIN)/samtools/samtools
SAMREPO=https://samtools.svn.sourceforge.net/svnroot/samtools/trunk/samtools

samtools : $(SAMTOOLS)

$(SAMTOOLS) :
	cd $(BIN) && $(SVN) co $(SAMREPO) && cd samtools && make