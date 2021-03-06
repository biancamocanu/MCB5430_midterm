#!/bin/sh

# Midterm assignment
# Bianca Mocanu

#=================================================================================================================================$# Usage:
# 1. replace <username> with your BBC account username in this script
# 2. Run the script by typing "bash <script path>"


#This script will analyze ChIP seq datasets and generate QC reports for the original and preprocessed data and BAM, BED and BEDGRA$
#=================================================================================================================================$# Requirements:

# 1.fastq files in the /home/<username>/data prefix
# 2.indexed genome or genome file to be indexed with "bowtie-build <infile> <outfile_handle>"
# 3.fastqc module (check for latest version: fastqc/0.11.5/, retrieved on Sep. 28, 2017)
# 4.fastx_tools (check for availability on BBC in /share/apps/ - add to $PATH if needed!
# 5.bowtie2 (check for latest version: bowtie2/2.3.1/, retrieved on Sep. 28, 2017)
# 6.samtools (check for latest version: samtools/1.3.1/, retrieved on Oct. 19th, 2017)
# 7.bedtools (check for latest version: BedTools/2.26.0/, retrieved on Oct. 19th, 2017)

#===============================================================================================
# Required modules load here:

module load bowtie2/2.3.1/
module load fastqc/0.11.5/
module load samtools/1.3.1/
module load BedTools/2.26.0/

#===============================================================================================
# Global variables

# inPATH="/tempdata3/MCB5430/midterm/midterm/fastq/" # uncomment this for the real (very large) files
inPATH="/home/bim16102/midterm/" #used this on 1 mil reads files to test the script
hg19index="/tempdata3/MCB5430/genomes/hg19/bowtieIndex/hg19"
hg19chromInfo="/tempdata3/MCB5430/genomes/hg19/hg19_chromInfo.txt"
gencode="/tempdata3/MCB5430/annotations/hs/bed/hg19_gencode_ENSG_geneID.bed"
chr12="/tempdata3/MCB5430/genomes/hg19/fasta/chr12.fasta"
hg19="/tempdata3/MCB5430/genomes/hg19/fasta/hg19.fasta"
TSSbackground="/tempdata3/MCB5430/midterm/hg19_unique_TSSonly_bkgrnd.txt"
outPATH="/home/bim16102/data/processed_data/"
jaspar_meme="/tempdata3/MCB5430/TF_db/jaspar.meme"
adapter="GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTGAAA"
fastqfiles=$(find ${inPATH} -maxdepth 1 -type f)

#===============================================================================================

if [ -s $outPATH ]
	then
		cd ${outPATH}
		mkdir ${outPATH}logfiles
		touch ${outPATH}logfiles/log.txt
 		echo "$outPATH directory already exists"

	else
		mkdir ${outPATH}
		cd ${outPATH}
		mkdir ${outPATH}logfiles
		touch ${outPATH}logfiles/log.txt
		echo "New directory created: ${outPATH}"
fi | tee -a ${outPATH}logfiles/log.txt


echo -e "Files to be proceesed: $fastqfiles" | tee -a ${outPATH}logfiles/log.txt

for file in $fastqfiles
	do
		ext=`echo $(basename $file) | cut -d "." -f 2`
		prefix=`echo $(basename $file) | cut -d "." -f 1`  #creates a prefix for each fastq file that is analyzed

	if [ $ext == "fastq" ]
	then

	mkdir ${prefix}  #folder for the fastq file / sample
		cd $prefix

		echo -e "Starting analysis on $(basename $file) ..."


		echo "Generating QC reports of unprocessed $(basename $file)"
		mkdir ./unprocessed_data_qc/
		fastqc $file -o ./unprocessed_data_qc  2>&1

		echo "Clipping adapter sequences..."
		fastx_clipper -Q 33 -a $adapter -i $file -o ./${prefix}_clipped.fastq 2>&1


		echo "Trimming low quality bases..."
		fastq_quality_trimmer -Q33 -t 32 -l 30 -i ./${prefix}_clipped.fastq -o ./${prefix}_preprocessed.fastq 2>&1

		echo "Generating QC reports of the preprocessed $(basename $file)..."
		mkdir ./preprocessed_data_qc
		fastqc ${prefix}_preprocessed.fastq -o ./preprocessed_data_qc/ 2>&1

		echo "Aligning to Human genome (hg19) ..."
		bowtie -S -v0 -m1 -t -q $hg19index ${prefix}_preprocessed.fastq ./${prefix}.sam 2>&1
		cat ./${prefix}.sam | head -n 27  > ./${prefix}_chr12.sam # this appends the sam header to the chromosome 12 only sam file

		echo "Subsetting the data to chromosome 12 aligned reads"
		grep chr12 ./${prefix}.sam >> ./${prefix}_chr12.sam
		echo "Alignment to human genome (hg19) complete for $(basename $file)!"

		echo "Generating BAM file..."
		samtools view -S -b ${prefix}_chr12.sam > ${prefix}_chr12.bam  # sam to bam conversion

		samtools sort -l 9 -n  ${prefix}_chr12.bam -T ${prefix} -o ${prefix}_chr12.sorted.bam  #this sorts the bam file so that it occupies less space
		echo "BAM file generated!"

		echo "Generating BED file..."
		bedtools bamtobed -i ${prefix}_chr12.sorted.bam > ${prefix}_chr12.bed
		echo "BED file generated!"
		echo "Sorting BED file"
		sortBed -i ${prefix}_chr12.bed > ${prefix}_chr12_sorted.bed
		echo "Generating bedgraph file..."
		bedtools genomecov -ibam ${prefix}_chr12.sorted.bam -bg > ${prefix}.bedgraph #generates the bedgraph from bam directly
		echo "Bedgraph file generated!"

#==============================================================================================================================================================
# Comment this section if you want to keep all these files
#==============================================================================================================================================================
		echo "Cleaning up temporary files"
		rm ${prefix}_clipped.fastq # there is no point in keeping this file since it's only halfway processed
		rm ${prefix}_preprocessed.fastq #removes the preprocessed fastq file because it occupies a lot of space
		rm ${prefix}.sam
		rm ${prefix}_chr12.sam
		rm ${prefix}_chr12.bam #removes unsorted bam file
		rm ${prefix}_chr12.bed
#==============================================================================================================================================================
		echo "Preparing bedgraphs for Genome Browser..."
		if [ $prefix=="treatA_rep1_1mil" ] || [ $prefix=="treatA_rep2_1mil" ]
		then
			awk -v NAME="$prefix" 'BEGIN { print "browser position chr12:5,289,521-5,291,937"
			print "track type=bedGraph name=\""NAME"\" description=\""NAME"\" visibility=full windowingFunction=maximum color=0,0,125"}
			{print $0}' ${prefix}.bedgraph > ${prefix}_header.bedgraph
		elif [ $prefix=="treatAB_rep1_1mil" ] || [ $prefix=="treatAB_rep1_1mil" ]
		then
			awk -v NAME=$prefix 'BEGIN { print "browser position chr12:5,289,521-5,291,937"
			print "track type=bedGraph name=\""NAME"\" description=\""NAME"\" visibility=full windowingFunction=maximum color=125,0,125"}
			{print $0}' ${prefix}.bedgraph > ${prefix}_header.bedgraph
		elif [ $prefix=="Input1mil" ]
		then
			awk -v NAME=$prefix 'BEGIN { print "browser position chr12:5,289,521-5,291,937"
			print "track type=bedGraph name=\""NAME"\" description=\""NAME"\" visibility=full windowingFunction=maximum color=125,0,0"}
			{print $0}' ${prefix}.bedgraph > ${prefix}_header.bedgraph
		fi
		echo "Genome Browser bedgraphs generated!"
		cd ..
		fi
	done | tee -a ${outPATH}logfiles/log.txt


#==============================================================================================================================================================
# Unloading of required modules:

module unload bowtie2/2.3.1/
module unload fastqc/0.11.5/
module unload samtools/1.3.1/
module unload BedTools/2.26.0/
