# Population structure analysis

Here is the pipeline for the population structure analysis done for the samples from Shriver's lab.
A list of the samples used can be seen [here](https://github.com/tomszar/PopStruct/blob/master/DataBases/Genotypes/01_Original/GenotypeLocations.md).

## Pipeline summary 

Due to computational resources requirements we used the following approach to estimate population structure in our samples.
Our main analysis was done using [fineSTRUCTURE](https://people.maths.bris.ac.uk/~madjl/finestructure/).
Briefly, using a "coancestry matrix" based on haplotype similarity, fineSTRUCTURE uses a model-based approach to identify discrete populations.
Due to the high computational requirements, we used fineSTRUCTURE only in a subset of our samples.
We used the subset of samples for each dataset with 3D facial morphology information (the _pheno files).
With this subset we ran a QC assessment for each dataset.
Finally, we had two files, one "dense", trying to retain ~400k SNPs in a subset of samples, and another "sparse", capturing most of the samples with less SNPs (~20k).

The second group of samples were not constrained by retaining any phenotypic information, and only were reduced due to the QC assessment.
Due to the larger sample size we used a different clustering approach.
In this second case, we ran an Identity-by-Descent estimation ([refinedIBD](http://faculty.washington.edu/browning/refined-ibd.html)) as a measure of genetic distance.
We then ran an MDS on the similarity matrix and used [mclust](https://cran.r-project.org/web/packages/mclust/vignettes/mclust.html) for clustering.
This second approach performs way faster than the previous one.
Similar to the previous approach, we generated a "dense" and a "sparse" file.

Finally, both set of samples were LD pruned to generate appropriates files to run on [Admixture](http://www.genetics.ucla.edu/software/admixture/index.html).
To generate more meaningful results and help on the interpretation we merged our pruned samples with the 1000 Genomes and HGDP datasets. 
The pipeline for merging those two reference samples can be found [here](https://tomszar.github.io/HGDP_1000G_Merge/)

## QC assessment

Our QC assessment was done in [plink 1.9](https://www.cog-genomics.org/plink2) in each dataset, both before and after merging across platforms, in the following order:

1. Remove founders, that is, individuals with at least one parent in the dataset, and retained only autosomal chromosomes
2. Remove SNPs with missing call rates higher than 0.1
3. Remove SNPs with minor allele frequencies below 0.05
4. Remove SNPs with hardy-weinberg equilibrium p-values less than 0.001
5. Remove samples with missing call rates higher than 0.1
6. Remove one arbitrary individual from any pairwise comparison with a pihat >= 0.125 from an IBD estimation after LD prune

After merging platforms, the QC assessment comprised steps 2 to 5.

## Merging platforms

Because our datasets were genotyped using different platforms, in both datasets we created two merged files, a "dense", trying to retain ~400k SNPs, and a "sparse" file with ~20k SNPs.
From both datasets we also created an LD pruned one, using the "pruned" suffix.
To increase the chances of a successful merge, before attempting to merge the datasets we [harmonized](https://bmcresnotes.biomedcentral.com/articles/10.1186/1756-0500-7-901) our datasets using the [1000 Genomes Phase 3 (1000G)](ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/) as reference sample.
In doing so, we solved unknown strand issues, updated variant IDs, and updated the reference alleles.
We kept all SNPs from each dataset, and we removed problematic SNPs during the merging steps.

List of samples:
- Dense:
    + ADAPT
    + SA
    + UIUC2013
    + CV
    + TD2016
    + TD2015
    + PSU_FEMMES

- Sparse: 
    + GHPAFF_Euro
    + Axiom Array (CHP)
    + UC_FEMMES

## Phasing

Because fineSTRUCTURE and RefinedIBD use haplotype data, we phased each dataset using [SHAPEIT](http://mathgen.stats.ox.ac.uk/genetics_software/shapeit/shapeit.html#home), and the [1000G](https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.html) as reference.
Before the proper phasing, we check the alignment between our samples and the reference samples.
With this check we produced a file with a list of problematic SNPs, that is, SNPs that were not found in the reference samples and SNPs with strand differences.
In the proper phasing procedure, we remove those problematic SNPs.

## Pipeline scripts

1. [Initial dataset split and QC](https://nbviewer.jupyter.org/github/tomszar/PopStruct/blob/master/Code/2018-06-QC.ipynb)
2. [Harmonize genotypes](https://github.com/tomszar/PopStruct/blob/master/Code/2018-06-Harmonize.sh), was uploaded to Penn State HPC infrastructure
3. [Merging datasets and QC](https://nbviewer.jupyter.org/github/tomszar/PopStruct/blob/master/Code/2018-06-Merge.ipynb)
4. [Phasing genotypes](https://github.com/tomszar/PopStruct/blob/master/Code/2018-06-PhasingGenos.sh), was uploaded to Penn State HPC infrastructure
5. [FineStructure analysis](https://github.com/tomszar/PopStruct/blob/master/Code/2018-06-FineStructure.sh), was done using Penn state HPC infrastructure