# EZassembly
Integrated pipeline for all in one ab initio assembly, mapping, annotation, and differential 
expression of RNAseq data when a reference transcriptome is available (reference agnostic). 

Requires SGE HPC environment and several common and easy to compile dependencies.

## What it does

Splits up the Trinity pipeline into 3 stages, each using optimal server resources 
ensuring that the job finishes quickly, and that you are not monopolosing resources. 
Based on this analysis <http://dx.doi.org/10.1145/2335755.2335842>


How to use it:

(1)	Copy this folder tree to somewhere in your $HOME or /share

(2)	Edit the "custom.cfg" file with some specific parameters in the "Custom Variables" 
	section (email, group quota, and additional params). 
	The .cfg file contains information on how to setup your email account to receive SGE 
	notifications when your job starts and finishes. 

(3)	Try a 'dry run', like so" 
	./dynomite.bash ./example/R1_list.txt ./example/R2_list.txt 1 ./trinity_out

(4)	Generate the R1.txt and R2.txt files, which contain the full paths of all fastq files 
	to be assembled (one per line). 
	
	for file in /path/to/dir_1/*_R1.fastq /path/to/dir_2/*_R1.fastq; do echo $file ; done > R1.txt
	for file in /path/to/dir_1/*_R2.fastq /path/to/dir_2/*_R2.fastq; do echo $file ; done > R2.txt

(5) 	Run a full job. Example:
	./dynomite.bash ./R1.txt ./R2.txt 	
	This will default to 8 CPU (ideal if not trimming) and output written to: 
	/share/ClusterScratch/your_username/trinity 


If your jobs did not complete, you can re-run this script without performing all of the analysis 
again as there are builtin recovery checkpoints. However, should you wonder why your jobs didn't 
complete, check your output files (TNTpre.oXXXXXX, TNTpre.eXXXXXX, TNT.o/TNT.e/tnt.o/tnt.e).

Some situations often do not produce informative error messages. 
Common hard-to-diagnose problems include: 
   -Using compressed input files (decompress them first); 
   -Going over quota for RAM (increase the number of CPUs to auto-adjust RAM). This often happens 
    during the normalization stage.
   -Going over quota for # output files (try deleting the "read_components" folder and start over). 
    This may be problematic with large and complex datasets. If it reoccurs, try using /share/Temp 
    for your output or contact the sysadmin to request a larger file # quota on ClusterScratch.


Email m.smith@garvan.org.au for help. 

N.B.  Any custom troubleshooting may require compensation in the form of fermented malt with hops. 
