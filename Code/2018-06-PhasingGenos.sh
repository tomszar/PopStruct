#!/bin/bash

#This script will phase genotypes using SHAPEIT and the 1000G phase 3 as reference samples.
#Note that this script should be used in the Penn State cluster
#Remember to have your unphased genotypes in the ~/work/phasing directory, divided by chromosome in plink format
#Finally, run the following script as follows:
#cd ~/work/phasing
#chmod +x 2018-06-PhasingGenos.sh
#./2018-06-PhasingGenos.sh > 2018-06-PhasingGenos.log 2>&1 &

#Download Genetic map and reference samples for hg 19 coordinates in scratch 
cd ~/scratch
if [ ! -f 1000GP_Phase3.tgz ]; then
	wget -q https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.tgz
	tar -zxvf 1000GP_Phase3.tgz
	#No need to gunzip hap and legend files
fi

#Move to work/phasing directory
cd ~/work/phasing
mkdir Phased

#Download SHAPEIT static version
wget -q https://mathgen.stats.ox.ac.uk/genetics_software/shapeit/shapeit.v2.r904.glibcv2.12.linux.tar.gz
tar -zxvf shapeit.v2.r904.glibcv2.12.linux.tar.gz
mv shapeit.v2.904.2.6.32-696.18.7.el6.x86_64/bin/shapeit ~/work/phasing/shapeit

#For chr 1 to 22 create the pbs script and submit it to the cluster
for i in {1..22}
do
	echo "Starting chr${i}..."
	echo "Creating pbs file..."
	file="$(echo *chr_${i}.bed | cut -d'.' -f1)"
	echo "#!/bin/bash
#PBS -l nodes=1:ppn=8
#PBS -l walltime=24:00:00
#PBS -l pmem=8gb
#PBS -A jlt22_b_g_sc_default
#PBS -j oe

#Moving to phasing directory
cd ~/work/phasing

#Phasing command
./shapeit -B ${file} \
-M ~/scratch/1000GP_Phase3/genetic_map_chr${i}_combined_b37.txt \
--input-ref ~/scratch/1000GP_Phase3/1000GP_Phase3_chr${i}.hap.gz ~/scratch/1000GP_Phase3/1000GP_Phase3_chr${i}.legend.gz ~/scratch/1000GP_Phase3/1000GP_Phase3.sample \
-O Phased/${file}_phased \
--force \
-T 8" >> Phased/phasing_chr${i}.pbs

	echo "Submitting job..."
	qsub Phased/phasing_chr${i}.pbs

	echo "Waiting 1h for next chromosome...\n"
	sleep 1h
done
