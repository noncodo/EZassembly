#!/bin/bash
####################  USAGE  ##############################
function TNT {
   echo -e "\n\e[31m            ______  ____   ____  ____   ____  ______  __ __"
   echo "           |      ||    \\ |    ||    \\ |    ||      ||  |  |"
   echo "           |      ||  D  ) |  | |  _  | |  | |      ||  |  |"
   echo "           |_|  |_||    /  |  | |  |  | |  | |_|  |_||  ~  |"
   echo "             |  |  |    \\  |  | |  |  | |  |   |  |  |___, |"
   echo "             |  |  |  .  \\ |  | |  |  | |  |   |  |  |     |"
   echo "             |__|  |__|\\_||____||__|__||____|  |__|  |____/"
   echo -e "\e[33m              -= RNA-Seq De novo Assembly Using Trinity =-\e[0m"
}
function usage {
TNT
echo -e "\n
 \e[33mUsage\e[0m:      First, edit the \e[35mcustom.cfg\e[0m file. Then,
        ./dynomite.bash R1.txt R2.txt
 R1.txt     Text file with list of 'left' read files (full paths, required)
 R2.txt     Text file with list of 'right' read files (full paths, required)
"
}
if [[ $# == 0 ]]; then usage ; exit ;  fi
if [[ ! -e $1 || ! -e $2 ]]; then echo "List of left fastq files ${1} not found"; usage ; exit; fi
if [[ ! -e `head -n 1 $1` ]]; then echo "Left read file "`head -n 1 $1`" not found";
    echo "double check file location and contents" ; exit ; fi
if [[ ! -e `head -n 1 $2`  ]]; then echo "Right read file "`head -n 1 $2`" not found";
    echo "double check file location and contents" ; exit ; fi
## Saves you from loading a module (this script isin't tested on other versions)
TRINITY_BIN=/share/ClusterShare/software/contrib/marsmi/trinityrnaseq-2.0.6/Trinity
## install dependencies ?  
module load gi/pigz/2.3 gi/samtools/1.2 gi/trimmomatic/0.32 gi/bowtie/1.1.0 gi/java/jdk1.7.0_03

LEFT_FQ=$(awk '{ printf $1","}' ${1})
RIGHT_FQ=$(awk '{ printf $1","}' ${2})
DEFAULT_OUT=/share/ClusterScratch/`whoami`/trinity
source ./custom.cfg
CPU="${CPU:-8}"
OUTPUT="${MYOUT:-$DEFAULT_OUT}"
MAX_MEM=$( echo $CPU | awk '{print $1 * 7.552}' )
MAX_MEM=$MAX_MEM"G"
####################  Pre-Processing    ####################
TNT
echo -e "\n[ \e[33mNOTE\e[0m ] Running pre-processing of reads and normalization..."
CMD_BASE=${TRINITY_BIN}" --seqType fq \
 --left ${LEFT_FQ} --right ${RIGHT_FQ} \
 --normalize_reads \
 --output ${OUTPUT} "
CMD_INIT=${CMD_BASE}" --max_memory "${MAX_MEM%.*}" --CPU "${CPU}" --no_run_inchworm --no_distributed_trinity_exec "
if [[ ! -z $ADDS ]]; then CMD_INIT=$CMD_INIT" "$ADDS; fi
if [[ ! -z $TRIMMING ]]; then CMD_INIT=$CMD_INIT" --trimmomatic --quality_trimming_params \""$TRIMMING"\" "; fi
cat > trinity_prep.sge << EOF
mailx -v -A garvan -s "sge job \$JOB_NAME no. \$JOB_ID started `date`" ${USR_EMAIL} > /dev/null 2> /dev/null
`echo $CMD_INIT`
( echo -n "Usage stats: " ; qstat -j \$JOB_ID | grep usage ; tail TNTpre.o\$JOB_ID ) | mailx -v -A garvan -s "sge job \$JOB_NAME \$JOB_ID finished `date`" ${USR_EMAIL} > /dev/null 2> /dev/null
EOF
chmod 755 trinity_prep.sge
QSUB="qsub -S /bin/bash -N TNTpre -V -cwd -pe smp ${CPU} trinity_prep.sge"
ID=$( $QSUB ) && echo -e "[ \e[33mNOTE\e[0m ] submitting pre-processing commands \n[ \e[31mCMD\e[0m ] "$QSUB
echo "...command submitted:"
echo -e "\e[36m"$CMD_INIT"\e[0m"
ID=$( echo ${ID} | cut -d " " -f 3 )
sleep 1
####################  INITIALISATION    ####################
echo -e "\n[ \e[33mNOTE\e[0m ] Running inaitilization and read clustering..."
MAX_MEM="45.312G"
CMD_INIT=${CMD_BASE}" --max_memory "${MAX_MEM}" --CPU 6 --no_distributed_trinity_exec "
if [[ ! -z $ADDS ]]; then CMD_INIT=$CMD_INIT" "$ADDS; fi
if [[ ! -z $TRIMMING ]]; then CMD_INIT=$CMD_INIT" --trimmomatic --quality_trimming_params \""$TRIMMING"\" "; fi
cat > trinity_init.sge << EOF
mailx -v -A garvan -s "sge job \$JOB_NAME no. \$JOB_ID started `date`" ${USR_EMAIL} > /dev/null 2> /dev/null
`echo $CMD_INIT`
( echo -n "Usage stats: " ; qstat -j \$JOB_ID | grep usage ; tail TNT.o\$JOB_ID ) | mailx -v -A garvan -s "sge job \$JOB_NAME \$JOB_ID finished `date`" ${USR_EMAIL} > /dev/null 2> /dev/null
EOF
chmod 755 trinity_init.sge
QSUB="qsub -S /bin/bash -N TNT -V -cwd -hold_jid "${ID}" -pe smp 6 trinity_init.sge"
ID=$( $QSUB ) && echo -e "[ \e[33mNOTE\e[0m ] submitting initial stage \n[ \e[31mCMD\e[0m ] "$QSUB
echo "...command submitted:"
echo -e "\e[36m"$CMD_INIT"\e[0m"
ID=$( echo ${ID} | cut -d " " -f 3 )
sleep 1
##################        HPC           ###################
echo -ne "\n[ \e[33mNOTE\e[0m ] Preparing HPC environment..."
# generate config files
env > ./trinity.env
cat > sge_conf.txt << EOF
grid=SGE
cmd=qsub -S /bin/bash -V -cwd -N tNT -pe smp 1 `if [[ ! -z ${GROUP_QUOTA} ]]; then echo "-P ${GROUP_QUOTA}"; fi` -j y -o all_output_merged.out
# settings below configure the Trinity job submission system, not tied to the grid itself.
# this should be 80-90% of your group quota
max_nodes=${MAX_NODES}
# number of commands that are batched into a single grid submission job.
# Smaller group quota should use more (e.g. 500)
cmds_per_node=250
EOF
echo " done"
####################     KABOOOM     ####################
echo -ne "[ \e[33mNOTE\e[0m ] Preparing isoform reconstruction stage..."
# generate command
CMD_GRID=${CMD_BASE}" --max_memory 7.552G --CPU 1 \
--grid_conf `pwd`/sge_conf.txt \
--grid_node_CPU 1 \
--grid_node_max_memory 7552M \
--bflyHeapSpaceMax 7520M"
#--group_pairs_distance 250 \
#--path_reinforcement_distance 25 "
if [[ ! -z $ADDS ]]; then CMD_GRID=$CMD_GRID" "$ADDS; fi
if [[ ! -z $TRIMMING ]]; then CMD_GRID=$CMD_GRID" --trimmomatic --quality_trimming_params \""$TRIMMING"\" "; fi
# prepare SGE script
cat > trinity_grid.sge << EOF
if [[ ! -e `echo $OUTPUT`/recursive_trinity.cmds.ok ]] ; then 
 echo -e "[\e[36m"ERROR"\e[0m] recursive commands checkpoint failed: something went wrong in the first 2 commands. Ensure enough memory is allocated and file number quotas are sufficient." 
 exit 1
fi
mailx -v -A garvan -s "sge job \$JOB_NAME no. \$JOB_ID started `date`" ${USR_EMAIL} > /dev/null 2> /dev/null
ssh gamma00 /bin/bash -l << EOIF
 #commands to run on remote host
 source ./trinity.env > /dev/null 2> /dev/null
 `echo -e $CMD_GRID`
EOIF
( echo -n "Usage stats: " ; qstat -j \$JOB_ID | grep usage ; tail tnt.o\$JOB_ID ) | mailx -v -A garvan -s "sge job \$JOB_NAME \$JOB_ID finished `date`" ${USR_EMAIL} > /dev/null 2> /dev/null
EOF
chmod 755 trinity_grid.sge sge_conf.txt
echo " done"
# make it rain jobs on the cluster
QSUB="qsub -S /bin/bash -hold_jid "$ID" -N tnt -V -cwd -pe smp 1 -l mem_requested=4G,h_vmem=4G "`if [[ ! -z ${GROUP_QUOTA} ]]; then echo "-P ${GROUP_QUOTA}"; fi`" trinity_grid.sge"
ID=$( $QSUB ) && echo -e "[ \e[33mNOTE\e[0m ] submitting HPC stage \n[ \e[31mCMD\e[0m ] "$QSUB
echo "...command submitted:"
echo -e "\e[36m"$CMD_GRID"\e[0m"
echo -e "\n[ \e[33mNOTE\e[0m ] All jobs submitted. Cross your fingers and hope the HPC gods are happy."