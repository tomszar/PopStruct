# Population structure analysis

Here is the pipeline for the population structure analysis done for the samples from Shriver's lab.
A list of the samples used can be seen [here](https://github.com/tomszar/PopStruct/blob/master/DataBases/Genotypes/01_Original/GenotypeLocations.md).

## Pipeline summary 

We first ran a QC procedure for each dataset.
After harmonizing them, we merged all datasets, and finally merge them with the reference samples from 1000 Genomes (1000G) and the Human Diversity Project (HGDP). 
The pipeline for merging those two reference samples can be found [here](https://tomszar.github.io/HGDP_1000G_Merge/)

We applied an LD prune to generate appropriates files to run on [Admixture](http://www.genetics.ucla.edu/software/admixture/index.html), and [PCA](https://www.cog-genomics.org/plink2/strat).

## QC procedure

Our QC procedure was done using [plink 1.9](https://www.cog-genomics.org/plink2) for each dataset, both before and after merging across platforms, in the following order:

1. Remove founders, that is, individuals with at least one parent in the dataset, and retained only autosomal chromosomes
2. Remove SNPs with missing call rates higher than 0.1
3. Remove SNPs with minor allele frequencies below 0.05
4. Remove SNPs with hardy-weinberg equilibrium p-values less than 1e-50
5. Remove samples with missing call rates higher than 0.1
6. Remove one arbitrary individual from any pairwise comparison with a pihat >= 0.25 from an IBD estimation after LD prune

After merging platforms, the QC procedure was repeated from steps 2 to 5.

## Merging platforms

Because our datasets were genotyped using different platforms, and to increase the chances of a successful merge, before attempting to merge them we [harmonized](https://bmcresnotes.biomedcentral.com/articles/10.1186/1756-0500-7-901) our datasets using the [1000 Genomes Phase 3 (1000G)](ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/) as reference sample.
In doing so, we solved unknown strand issues, updated variant IDs, and updated the reference alleles.
We kept all SNPs from each dataset, and we removed problematic SNPs during the merging steps.

## Pipeline scripts

1. [Initial dataset split and QC](https://nbviewer.jupyter.org/github/tomszar/PopStruct/blob/master/Code/2018-06-QC.ipynb)
2. [Harmonize genotypes](https://github.com/tomszar/PopStruct/blob/master/Code/2018-06-Harmonize.sh), was uploaded to Penn State HPC infrastructure
3. [Merging datasets and QC](https://nbviewer.jupyter.org/github/tomszar/PopStruct/blob/master/Code/2018-06-Merge.ipynb)