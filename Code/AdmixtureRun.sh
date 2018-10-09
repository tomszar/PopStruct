#!/bin/bash

#This script will download Admixture software and run it using all plink files in the directory
#It will calculate admixture using ks from 2 to 12
#Remember to have this script as well as the genotype files you want to analyze in the same folder
#To run it in background and output to a log file do the following:
#chmod +x AdmixtureRun.sh
#./AdmixtureRun.sh > AdmixtureRun.log 2>&1 &

thisdir=$(pwd)
wget http://www.genetics.ucla.edu/software/admixture/binaries/admixture_linux-1.3.0.tar.gz
tar -xzf *.tar.gz
echo $thisdir

#We will request 4 cores per k per file
for file in *.bed
do
	for k in {2..12}
	do
		echo "#!/bin/bash
#PBS -l nodes=1:ppn=4
#PBS -l walltime=48:00:00
#PBS -l pmem=16gb
#PBS -A open #jlt22_b_g_sc_default or open
#PBS -j oe

cd ${thisdir}

admixture_linux-1.3.0/admixture -j4 ${file} ${k}" >> job_${file}_k${k}.pbs #Creating job to run admixture
	qsub job_${file}_k${k}.pbs

	done
done
