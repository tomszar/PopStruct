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
    infile="$(echo *chr_${chr}_phased.haps)"
    outfile="$(echo *chr_${chr}_phased.haps | cut -d'.' -f1)"
    echo "#!/bin/bash" > $cmdf 
    echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
    echo "#PBS -l walltime=24:00:00" >> $cmdf
    echo "#PBS -l pmem=8gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf #account for resource consumption (jlt22_b_g_sc_default or open)
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "#convert from imputer to chromopainter format" >> $cmdf
    echo "perl fs-2.1.3/scripts/impute2chromopainter.pl ${infile} ${outfile}" >> $cmdf
    echo "#add chromosome column to 1000G genetic map downloaded from https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.tgz" >> $cmdf
    echo "awk -v awk_chr=$chr 'NR==1{print \"chr \"\$0} NR>1{print awk_chr\" \"\$0}' ~/scratch/1000GP_Phase3/genetic_map_chr${chr}_combined_b37.txt > ~/scratch/1000GP_Phase3/genetic_map_chr${chr}_combined_b37_hapv.txt" >> $cmdf
    echo "#convert to recombfile used by fs" >> $cmdf
    echo "perl fs-2.1.3/scripts/convertrecfile.pl -M hapmap ${outfile}.phase ~/scratch/1000GP_Phase3/genetic_map_chr${chr}_combined_b37_hapv.txt recomb_chr${chr}.recombfile" >> $cmdf
done 

for chr in {1..22}
do
	qsub convert/convert_chr${chr}.pbs
done

#Create ids file
awk 'NR>2{print $2}' *chr_1_phased.sample > Merge.ids

#Now run fs, for a subset of chromosomes, to estimate parameters
infiles="$(echo *chr_{1,8,12,22}_phased.phase)"
./fs merge_fs.cp -idfile Merge.ids -phasefiles $infiles -recombfiles recomb_chr{1,8,12,22}.recombfile -hpc 1 -go
#Add ./ to the beginning of commandfile1.txt
awk '{print "./"$0}' merge_fs/commandfiles/commandfile1.txt > merge_fs/commandfiles/commandfile1.temp && mv merge_fs/commandfiles/commandfile1.temp merge_fs/commandfiles/commandfile1.txt

#Submit commandfile1.txt commands to HPC
#Divide in jobs of 85 commands per file (178 jobs)
split -d -l 85 merge_fs/commandfiles/commandfile1.txt merge_fs/commandfiles/commandfile1_split.txt -a 3

mkdir -p fsjobs
#Run the first 90 jobs.
for i in {000..090}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat merge_fs/commandfiles/commandfile1_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &
	
#Second batch
for i in {091..178}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat merge_fs/commandfiles/commandfile1_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &

#Once the jobs are done, resume the analysis with
./fs merge_fs.cp -go
#An error will appear to run the second stage and a commandfile2.txt file will be created
#Inferred values will show up, in this case
#Inferred Ne=136.7 and mu=0.000996525

#Now we will write the stage 2 with the whole sample, and the previous inferred parameters
#Setting new job
infiles="$(echo *chr_{1..22}_phased.phase)"
./fs total_fs.cp -idfile Merge.ids -phasefiles $infiles -recombfiles recomb_chr{1..22}.recombfile -hpc 1 -go

#Jumping to stage 2 with inferred parameters
./fs total_fs.cp -Neinf 136.7 -muinf 0.000996525 -makes2 -writes2 -go

#Add ./ to the beginning of commandfile2.txt
awk '{print "./"$0}' total_fs/commandfiles/commandfile2.txt > total_fs/commandfiles/commandfile2.temp && mv total_fs/commandfiles/commandfile2.temp total_fs/commandfiles/commandfile2.txt

#Submit commandfile2.txt commands to HPC
#Divide in jobs of 250 commands per file (332 jobs)
split -d -l 250 total_fs/commandfiles/commandfile2.txt total_fs/commandfiles/commandfile2_split.txt -a 3

#remove previous jobs
rm fsjobs/*

#Make sets of 95 jobs. Make sure to look for when most of the jobs end, so you can upload the next batch
#It seems that in this stage, each individual takes ~2 minutes
for i in {000..095}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat total_fs/commandfiles/commandfile2_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &

#Second batch
for i in {096..186}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat total_fs/commandfiles/commandfile2_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &

#Third batch
for i in {187..277}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat total_fs/commandfiles/commandfile2_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &

#Fourth batch, and last
for i in {278..332}
do
	cmdf="fsjobs/fsjob_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=48:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A open" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat total_fs/commandfiles/commandfile2_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &

#Once the jobs are done, merge stage2
cmdf="fsjobs/fsjob_merge2.pbs"
echo '#!/bin/bash' > $cmdf 
echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
echo "#PBS -l walltime=48:00:00" >> $cmdf
echo "#PBS -l pmem=64gb" >> $cmdf
echo "#PBS -A open" >> $cmdf
echo "#PBS -j oe" >> $cmdf
echo "" >> $cmdf
echo "#Moving to directory" >> $cmdf
echo "cd ~/work/FS" >> $cmdf
echo "" >> $cmdf
echo "./fs total_fs.cp -combines2 -go" >> $cmdf
#run the job	
qsub fsjobs/fsjob_merge2.pbs

####STAGE 3####
#There is only one command for stage 3 written, (mcmc runs in 68 hours)
cmdf="fsjobs/fsjob_stage3.pbs"
echo '#!/bin/bash' > $cmdf 
echo "#PBS -l nodes=1:ppn=2" >> $cmdf 
echo "#PBS -l walltime=500:00:00" >> $cmdf
echo "#PBS -l pmem=64gb" >> $cmdf
echo "#PBS -A jlt22_b_g_sc_default" >> $cmdf
echo "#PBS -j oe" >> $cmdf
echo "" >> $cmdf
echo "#Moving to directory" >> $cmdf
echo "cd ~/work/FS" >> $cmdf
echo "" >> $cmdf
echo "./fs total_fs.cp -s34args:'-X -Y' -makes3 -dos3 -combines3 -go" >> $cmdf
#run the job
qsub fsjobs/fsjob_stage3.pbs

#In parallel do greedy fs instead
cmdf="fsjobs/fsjob_greedyfs.pbs"
echo '#!/bin/bash' > $cmdf 
echo "#PBS -l nodes=1:ppn=2" >> $cmdf 
echo "#PBS -l walltime=48:00:00" >> $cmdf
echo "#PBS -l pmem=64gb" >> $cmdf
echo "#PBS -A open" >> $cmdf
echo "#PBS -j oe" >> $cmdf
echo "" >> $cmdf
echo "#Moving to directory" >> $cmdf
echo "cd ~/work/FS" >> $cmdf
echo "" >> $cmdf
echo "fs-2.1.3/scripts/finestructuregreedy.sh -f ~/work/FS/fs -a 'fs -X -Y' total_fs_linked.chunkcounts.out total_fs_linked.greedy_outputfile.xml" >> $cmdf

qsub fsjobs/fsjob_greedyfs.pbs

####STAGE 4####
#write commands for stage 4
#Once the jobs are done, resume the analysis with
./fs total_fs.cp -go
#Add ./ to the beginning of commandfile4.txt
awk '{print "./"$0}' total_fs/commandfiles/commandfile4.txt > total_fs/commandfiles/commandfile4.temp && mv total_fs/commandfiles/commandfile4.temp total_fs/commandfiles/commandfile4.txt
#Divide in jobs of 1 commands per file (2 jobs)
split -d -l 1 total_fs/commandfiles/commandfile4.txt total_fs/commandfiles/commandfile4_split.txt -a 1

#Now we will run the stage 4
for i in {0..1}
do
	cmdf="fsjobs/fsjob_stage4_${i}.pbs"
	echo '#!/bin/bash' > $cmdf 
	echo "#PBS -l nodes=1:ppn=1" >> $cmdf 
	echo "#PBS -l walltime=400:00:00" >> $cmdf
	echo "#PBS -l pmem=16gb" >> $cmdf
	echo "#PBS -A jlt22_b_g_sc_default" >> $cmdf
	echo "#PBS -j oe" >> $cmdf
	echo "" >> $cmdf
	echo "#Moving to directory" >> $cmdf
	echo "cd ~/work/FS" >> $cmdf
	echo "" >> $cmdf
	cat total_fs/commandfiles/commandfile4_split.txt${i} >> $cmdf
	
	qsub fsjobs/fsjob_stage4_${i}.pbs

done > fsjobs/fsjobs.log 2>&1 &

#Once you have a file with the subset of populations, generate the popidfile
./fs fs -X -Y -e popidfile total_fs_linked.chunkcounts.out total_fs/stage4/total_fs_linked_tree.xml PopID_FS.csv
#All is done!
