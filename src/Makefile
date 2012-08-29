# run with the 'make' (or 'make -j 4') command
DATA=../data
BIN=../bin
PERL=perl
PYTHON=python
R=r
SH=bash
SVN=svn
SAMTOOLS=$(BIN)/samtools

getsamtools : $(SAMTOOLS)

$(SAMTOOLS)
	cd $(BIN) && $(SVN) co https://samtools.svn.sourceforge.net/svnroot/samtools/trunk/samtools