def QC_procedure(maf=0.05, hwe=1e-50, geno=0.1, mind=0.1, pihat=0.25):
	#QC procedure for all genotype plink files in a single folder
	#At this point, the function follows these steps in the following order
		
	# 1.Removed founders, that is, individuals with at least one parent in the dataset, and retained only autosomal chromosomes
    # 2.Removed SNPs with missing call rates higher than "geno"
    # 3.Removed SNPs with minor allele frequencies below "maf"
    # 4.Removed SNPs with hardy-weinberg equilibrium p-values less than "hwe"
 	# 5.Removed samples with missing call rates higher than "mind"
    # 6.Removed one arbitrary individual from any pairwise comparison with a pihat >= "pihat" from an IBD estimation after LD prune
    # Remember that a pihat value of 0.125 is third degree, 0.25 is second degree, and 0.5 is first degree
    import subprocess
    import glob
    import os

    cwd = os.getcwd()
    outpath = os.path.join(cwd, "QC")
    
    if not os.path.exists(outpath):
        os.makedirs(outpath)
    
    for file in glob.glob("*.bed"):
        filename1 = file.split(".")[0]
        print("Running " + filename1 + " file...")
        subprocess.run(["plink", "--bfile", filename1, "--filter-founders", "--autosome", "--make-bed", "--out", os.path.join(outpath, "temp1")])
    	#SNP missing rate
        print("Removing SNPs with missing call rates higher than " + str(geno) + "...")
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp1"), "--geno", str(geno), "--make-bed", "--out", os.path.join(outpath,"temp2")])
    	#SNP MAF
        print("Removing SNPs with minor allele frequencies below " + str(maf) + "...")
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp2"), "--maf", str(maf), "--make-bed", "--out", os.path.join(outpath, "temp3")])
    	#SNP HWE
        print("Removing SNPs with hardy-weinberg equilibrium p-values less than " + str(hwe) + "...")
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp3"), "--hwe", str(hwe), "--make-bed", "--out", os.path.join(outpath, "temp4")])
    	#Sample missing rate
        print("Removing samples with missing call rates higher than " + str(mind) + "...")
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp4"), "--mind", str(mind), "--make-bed", "--out", os.path.join(outpath, "temp5")])
        #LD prune for IBS
        print("Removing one arbitrary individual from any pairwise comparison with a pihat higher than " + str(pihat) + "...")
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp5"), "--indep", "50", "5", "2", "--out", os.path.join(outpath, "temp6")])
    	#Print relatives
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp5"), "--exclude", os.path.join(outpath, "temp6" + ".prune.out"), "--genome", "--min", str(pihat), "--out", 
                        os.path.join(outpath, "temp7")])
    	#Remove samples in the first column
        print("Generating final plink file...")
        subprocess.run(["plink", "--bfile", os.path.join(outpath, "temp5"), "--remove", os.path.join(outpath, "temp7" + ".genome"), "--make-bed", "--out", 
                        os.path.join(outpath, filename1 + "_founders_geno01_maf_hwe_mind01_rel")])
        
    for file in glob.glob(os.path.join(outpath, "temp[0-9].[b,f]*") ):
        os.remove(file)
    
    print("Finished")
    
def Split_chr(chrs=range(1,23) ):
    #Split a binary plink file into a range of chromosomes
    
    import subprocess
    import glob
    import os
    
    cwd = os.getcwd()
       
    for file in glob.glob("*.bed"):
        filename = file.split(".")[0]
        outpath  = os.path.join(cwd, "split_" + filename)
        if not os.path.exists(outpath):
            os.makedirs(outpath)
        #Split by chromosome
        for i in chrs:
            subprocess.run(["plink", "--bfile", filename, "--chr", str(i), "--make-bed", "--out", os.path.join(outpath, filename + "_chr_" + str(i) ) ])