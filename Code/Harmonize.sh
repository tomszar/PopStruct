#!/bin/bash

#This script will download GenotypeHarmonizer and the corresponding 1000g files used as reference,
#it will run GenotypeHarmonizer on all plink binary files (bim, bed, fam), and output them harmonized.
#Usage:
#    - Place your plink binary files in the same folder as this script
#    - To run it in background and output to a log file run the following code in the console:
#        $ chmod +x Harmonize.sh
#        $ ./Harmonize.sh > Harmonize.log 2>&1 &

#Getting the path to this folder
thisdir=$(pwd)

#Download 1000G in vcf format to scratch folder
cd ~/scratch
for chr in {1..22}
do
	if [ ! -f ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz ]; then
		wget -q ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz
	fi
	if [ ! -f ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz.tbi ]; then
		wget -q ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr${chr}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz.tbi
	fi	
done

#Move to harmonize directory
cd $thisdir

#Download and unzip genotype harmonizer
wget -q http://www.molgenis.org/downloads/GenotypeHarmonizer/GenotypeHarmonizer-1.4.20-dist.tar.gz
tar -xzf GenotypeHarmonizer-1.4.20-dist.tar.gz

#for each file, split them by chromosome and run the harmonizer
for file in *.bed 
do
	name=`echo "$file" | cut -d'.' -f1`
	mkdir $name
	mkdir $name"_temp"
	echo "Spliting file $name by chromosome"
	
	for chr in {1..22}
	do
		plink --bfile $name --chr $chr --make-bed --out ${name}_temp/${name}_chr${chr}
	done

	#Create one job for each file for each chromosome
	for i in {1..22}
	do
		echo "Writing job for $name"
		echo "#!/bin/bash
#PBS -l nodes=1:ppn=1
#PBS -l walltime=24:00:00
#PBS -l pmem=8gb
#PBS -A open #jlt22_b_g_sc_default or open
#PBS -j oe

#Moving to harmonize directory
cd ${thisdir}

java -jar GenotypeHarmonizer-1.4.20-SNAPSHOT/GenotypeHarmonizer.jar --input ${name}_temp/${name}_chr${i} \
--inputType PLINK_BED \
--ref ~/scratch/ALL.chr${i}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes \
--refType VCF \
--update-id \
--min-ld 0.3 \
--mafAlign 0.1 \
--min-variants 3 \
--variants 100 \
--update-reference-allele \
--keep \
--debug \
--output ${name}/${name}_chr${i}_harmonized" >> job_${name}_chr${i}.pbs

		echo "Submitting job_${name}_chr${i}.pbs"
		qsub job_${name}_chr${i}.pbs
		echo "Waiting 5s for next chromosome..."
		sleep 5s 

	done
	echo "Waiting 15m for next file..."
	sleep 15m

done
