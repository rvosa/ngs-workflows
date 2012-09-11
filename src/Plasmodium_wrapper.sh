#!/bin/bash

log_dir='log/'`date | perl -pe 'chomp; s/\s+/\_/g'`
mkdir -p ${log_dir}
./src/Plasmodium.sh > ${log_dir}/Plasmodium.sh.$$.log 2>&1

git add ${log_dir}
git add ${log_dir}/Plasmodium.sh.$$.log
git commit -m "Run ${log_dir} $$"

#Uncomment below to commit with the log as the commit message
#git commit -F ${log_dir}/Plasmodium.sh.$$.log
exit
