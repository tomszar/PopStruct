#!/bin/bash

#This script will download Admixture software and run it using all plink files in the directory as input
#It will calculate admixture using ks from 2 to 12
#Usage:
#	- Place your plink binary files in the same folder as this script
#	- To run it in background and output to a log file do the following in the console:
#		$ chmod +x AdmixtureRun.sh
#		$ ./AdmixtureRun.sh > AdmixtureRun.log 2>&1 &

thisdir=$(pwd)
wget http://dalexander.github.io/admixture/binaries/admixture_linux-1.3.0.tar.gz
tar -xzf *.tar.gz
echo $thisdir

#We will request 6 cores per k per file
for file in *.bed
do
	for k in {2..12}
	do
		echo "#!/bin/bash
#PBS -l nodes=1:ppn=6
#PBS -l walltime=48:00:00
#PBS -l pmem=32gb
#PBS -A jlt22_b_g_sc_default #jlt22_b_g_sc_default or open
#PBS -j oe

cd ${thisdir}

dist/admixture_linux-1.3.0/admixture --cv -j6 ${file} ${k}" >> job_${file}_k${k}.pbs #Creating job to run admixture
	qsub job_${file}_k${k}.pbs

	done
done

#To see the CV run: 
#grep -h CV *.pbs.* > CVs.txt