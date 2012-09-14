.PHONY: all

all: t5 t4 t1
	@echo Making $@

t1: t3 t2
	touch $@

t2: t3
	cp t3 $@

t3:
	sleep 3 && touch $@

t4:
	touch $@

t5:
	touch $@