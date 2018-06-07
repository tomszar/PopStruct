#!/bin/bash
#This script was interactively ran in the HPC PSU infrastructure so to adjust the number of jobs submitted

#Download Genetic map and reference samples for hg 19 coordinates in scratch 
cd ~/scratch
if [ ! -f 1000GP_Phase3.tgz ]; then
	wget -q https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.tgz
	tar -zxvf 1000GP_Phase3.tgz
	#No need to gunzip hap and legend files
fi

#Move to directory. Remember to transfer the phased haps files to this folder
cd ~/work/FS

#Load modules
module load gcc/5.3.1
module load parallel/20170522

#Download fs and extract it
wget https://people.maths.bris.ac.uk/~madjl/finestructure/fs-2.1.3.tar.gz
tar -xzvf fs-2.1.3.tar.gz
fs-2.1.3/configure
make

######Send job to convert from impute to chromopainter
#We will ask for 1 processor per chromosome with 8 gb
mkdir -p convert
for chr in {1..22}
do 
    cmdf="convert/convert_chr${chr}.pbs" 
    echo "#!/bin/bash" > $cmdf 
    echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
    echo "#PBS -l walltime=24:00:00" >> $cmdf
    echo "#PBS -l pmem=8gb" >> $cmdf
	echo "#PBS -A jlt22_b_g_sc_default" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "#convert from imputer to chromopainter format" >> $cmdf
    echo "perl fs-2.1.3/scripts/impute2chromopainter.pl Merge_500k_3612pp_geno01_mind01_founders_unique_chr_${chr}_phased.haps Merge_500k_3612pp_geno01_mind01_founders_unique_chr_${chr}_phased" >> $cmdf
    echo "#add chromosome column to 1000G genetic map downloaded from https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.tgz" >> $cmdf
    echo "awk -v awk_chr=$chr 'NR==1{print \"chr \"\$0} NR>1{print awk_chr\" \"\$0}' ~/scratch/1000GP_Phase3/genetic_map_chr${chr}_combined_b37.txt > ~/scratch/1000GP_Phase3/genetic_map_chr${chr}_combined_b37_hapv.txt" >> $cmdf
    echo "#convert to recombfile used by fs" >> $cmdf
    echo "perl fs-2.1.3/scripts/convertrecfile.pl -M hapmap Merge_500k_3612pp_geno01_mind01_founders_unique_chr_${chr}_phased.phase ~/scratch/1000GP_Phase3/genetic_map_chr${chr}_combined_b37_hapv.txt recomb_chr${chr}.recombfile" >> $cmdf
done 

for chr in {1..22}
do
	qsub convert/convert_chr${chr}.pbs
done

#Create ids file
awk 'NR>2{print $2}' Merge_500k_3612pp_geno01_mind01_founders_unique_chr_1_phased.sample > Merge_500k_3612pp_geno01_mind01_founders_unique.ids

#Now run fs, for all chromosomes, it seems that fs will know how to deal with those
./fs merge500k_fs.cp -idfile Merge_500k_3612pp_geno01_mind01_founders_unique.ids -phasefiles Merge_500k_3612pp_geno01_mind01_founders_unique_chr_{1..22}_phased.phase -recombfiles recomb_chr{1..22}.recombfile -hpc 1 -go
#Add ./ to the beginning of commandfile1.txt
awk '{print "./"$0}' merge500k_fs/commandfiles/commandfile1.txt > merge500k_fs/commandfiles/commandfile1.temp && mv merge500k_fs/commandfiles/commandfile1.temp merge500k_fs/commandfiles/commandfile1.txt

#Submit commandfile1.txt commands to HPC
#Divide in jobs of 100 commands per file (759 jobs)
split -d -l 100 merge500k_fs/commandfiles/commandfile1.txt merge500k_fs/commandfiles/commandfile1_split.txt -a 3

##Test speed per ind in relation to memory
mkdir -p fsjobs
mem=2
for i in {1..6}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=${mem}gb" >> $cmdf
	echo "#PBS -A jlt22_b_g_sc_default" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	sed "${i}q;d" merge500k_fs/commandfiles/commandfile1.txt >> $cmdf
	mem=$(( $mem * 2 ))

	qsub fsjobs/fsjob_${i}.pbs
done


mkdir -p fsjobs
for i in {000..759}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=32gb" >> $cmdf
	echo "#PBS -A jlt22_b_g_sc_default" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat merge500k_fs/commandfiles/commandfile1_split.txt${i} >> $cmdf

	qsub fsjobs/fsjob_${i}.pbs
	sleep 30m
done > fsjobs/fsjobs.log 2>&1 &

i=000
cmdf="fsjobs/fsjob_${i}.pbs"
echo '#!/bin/bash' > $cmdf 
echo "#PBS -l nodes=1:ppn=4" >> $cmdf 
echo "#PBS -l walltime=24:00:00" >> $cmdf
echo "#PBS -l pmem=8gb" >> $cmdf
echo "#PBS -A jlt22_b_g_sc_default" >> $cmdf
echo "#PBS -j oe" >> $cmdf
echo "" >> $cmdf
echo "#Moving to directory" >> $cmdf
echo "cd ~/work/FS" >> $cmdf
echo "" >> $cmdf
cat merge500k_fs/commandfiles/commandfile1_split.txt${i} >> $cmdf

qsub fsjobs/fsjob_${i}.pbs

#fs-2.1.3/scripts/qsub_run.sh -f merge500k_fs/commandfiles/commandfile1.txt -n 8 -m 42 -w 48 -P -v

#Once the jobs are done, resume the analysis with
./fs merge500k_fs.cp -go
