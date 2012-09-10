#!/bin/bash
for x in data/fastq/*fastq
do
  cat $x | perl bin/fastqvalidate.pl > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo $x
  fi
done
