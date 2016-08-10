#!/bin/bash

source custom.cfg
TRINITYFASTA="./Trinity.fasta" # $MYOUT
NUMSAMPLES=$(wc -l R1.txt)
CPU="4"

#get strand info
if [[ -n $STRAND ]]; then 
	if [[ $STRAND == "FR" ]]; then 
		KSTRAND="--fr-stranded"
	else
		KSTRAND="--rf-stranded"
	fi
else
	echo -e "Assuming single-end reads"
	KSTRAND="--single"
fi

#kallisto required. 
KALLISTOBIN=$( which kallisto )
if [[ -z $KALLISTOBIN ]]; then 
	echo "Kallisto not found in $PATH." 
	echo "Install and link kallisto from here: https://github.com/pachterlab/kallisto" 
fi

#samtools recommended for bam pseudoalignments
SAMTOOLSBIN=$( which samtools )
if [[ -z $SAMTOOLSBIN ]]; then 
	echo "Samtools not found in $PATH." 
	echo "Install and link samtools from here: https://github.com/samtools/samtools" 
fi

if [[ -d kallisto ]]; then cd kallisto
else mkdir kallisto && cd kallisto
fi

## Index trinity fasta for kallisto
if [[ ! -e kallisto_trinity.index ]]; then
	## no SGE
	#$KALLISTOBIN index -i kallisto_trinity.index ../$TRINITYFASTA

	## with SGE
	CMD="qsub -cwd -S /bin/bash -N K_index -terse -l mem_requested=128G,h_vmem=132G"
	CMD=$CMD" -b y -o ./out.sge -V -j y ${KALLISTOBIN} index -i kallisto_trinity.index ../${TRINITYFASTA} "
	JID=$( $CMD )
	echo "[ SGE ] launched job: "$JID
	echo "[ SGE ] "$CMD
fi

#### Run kallisto on all samples
## No SGE
# for f in { 1..${NUMSAMPLES} } ; do
# 	CMD=" $KALLISTOBIN quant -t ${CPU} ${KSTRAND} -b 50 --bias -i kallisto_trinity.index "
# 	CMD=$CMD" -o ${file%_*}  $( sed $i'q;d' ../R1.txt ) $( sed $i'q;d' ../R2.txt) "
# 	$CMD && echo $CMD
# done
## With  SGE
cat >  kallisto_quant.sge << EOF
 f1=\$( sed \${SGE_TASK_ID}'q;d' ../R1.txt )
 f2=\$( sed \${SGE_TASK_ID}'q;d' ../R2.txt )
 outdir=\${f1##*/}
 cmd="${KALLISTOBIN} quant  -i kallisto_trinity.index -t ${CPU} ${KSTRAND} -b 100 --bias -o \${outdir%_*} \${f1} \${f2}"
 \$cmd && echo \$cmd
EOF
chmod 755 kallisto_quant.sge
if [[ ! -z $GROUP_QUOTA ]]; then
    ACCOUNT=" -P ${GROUP_QUOTA} "
fi
if [[ ! -z $JID ]]; then
    HOLD=" -hold_jid ${JID} "
fi
CMD="qsub -cwd ${HOLD} ${ACCOUNT} -S /bin/bash -N Klsto_Q -S /bin/bash -j y -b y -V -pe smp 6"
CMD=$CMD" -l h_vmem=4G,mem_requested=4G -t 1:$( wc -l ../R1.txt | awk '{print $1}' ) ./kallisto_quant.sge"
echo "[ SGE ] "$CMD && JID=$( $CMD ) 



