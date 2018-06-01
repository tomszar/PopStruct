# Population structure analysis

Here is the pipeline for the population structure analysis done for the samples from Shriver's lab.
A list of the samples used can be seen [here](https://github.com/tomszar/PopStruct/blob/master/DataBases/Genotypes/01_Original/GenotypeLocations.md).

## Pipeline summary 

This analysis was done using [fineSTRUCTURE](https://people.maths.bris.ac.uk/~madjl/finestructure/).
Briefly, using a "coancestry matrix" based on haplotype similarity, fineSTRUCTURE uses a model-based approach to identify discrete populations.
The steps were as follows:

- First, we cleaned our datasets removing all SNPs and samples with missing call rates higher than 0.1, using [plink](https://www.cog-genomics.org/plink2) commands --geno and --mind.
The script is [here](https://nbviewer.jupyter.org/github/tomszar/PopStruct/blob/master/Code/2018-06-QC.ipynb).
- Because the diversity of samples and genotyping platforms, we [harmonized](https://bmcresnotes.biomedcentral.com/articles/10.1186/1756-0500-7-901) our previously cleaned samples using as reference the [1000G Phase 3](ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/) samples. 
In doing so, we solved unknown strand issues, updated variant IDs, and updated the reference alleles.
The script is [here](https://github.com/tomszar/PopStruct/blob/master/Code/2018-06-Harmonize.sh), which was uploaded to Penn State HPC infrastructure.
- After all our samples were harmonized, we merged them into three different files: a "dense", "medium", and "sparse" files.
The "dense" file was made from files with more than 500k SNPs:

    - UIUC2013
    - UIUC2014
    - TD2015
    - TD2016
    - SA
    - ADAPT
    - PSU_FEMMES
    - GHPAFF_CV

The "medium" file was made from the ones with more than 300k SNPs,that is from all of the previous ones, plus:

    - GHPAFF_Euro

The "sparse" file was made from the ones with more than 100k SNPs,that is from all of the previous ones, plus:

    - Axiom Array
    - UC_FEMMES

- Because fineSTRUCTURE uses haplotype data, the next step was to phase all genotypes.
To do that, for each of the three files we used [IMPUTE2](https://mathgen.stats.ox.ac.uk/impute/impute_v2.html#ex10), and the [1000G Phase 3 reference](https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.html). 
To ease computations, we phased the genoytpes using a sliding window of 5Mb. 
Because the "sparse" dataset might not contain enough SNPs in a 5Mb sliding window, we constrained the interval size to have at least 200 SNPs.
If there are less than 200 SNPs in the interval, the script will increase the interval in 1Mb until there are at least 200 SNPs.
