#!/bin/bash
#
#$ -S /bin/bash
##$ -l arch=lx24-amd64
#$ -l arch=linux-x64
#$ -l h_rt=336:00:0
#$ -l scratch=0.5G
#$ -cwd
#$ -o /dev/null
#$ -e /dev/null

#for big memory, add this
# #$ -l xe5520=true
#$ -l mem_free=0.5G

#rather than set -t here, set it at the command line so that the range can vary across samples (different samples will have different number of splits)

# Arguments to the script: seven command-line arguments
INPATH=$1
INBASENAME=$2
OUTPATH=$3
OUTBASENAME=$4
SCRIPTS=$5
LOGS=$6
SPLITOUTPATH=$7
FILTERLENGTH=$8

INPUT=${INPATH}/${INBASENAME}${SGE_TASK_ID}.fa
OUTPUT=${OUTPATH}/${OUTBASENAME}${SGE_TASK_ID}.fa

#let's see if the results already exist....
if [ -e ${OUTPATH}/${OUTPUT} ]
then
    echo "[Skipping]: Since results ALREADY EXIST at ${OUTPATH}/${OUTPUT}, we are not re-running this script."
    exit
fi
## JOB_ID and TASK_ID are both *magic* environment variables that are set automatically by the job scheduler! This is some kind of cluster magic.

ALL_OUT_FILE=$LOGS/transeq/${JOB_ID}.${SGE_TASK_ID}.all

qstat -f -j ${JOB_ID}                           > ${ALL_OUT_FILE} 2>&1
# Note that the '>' above is just ONE caret, to CREATE the file, and all the subequent ones APPEND to the file ('>>')
uname -a                                       >> ${ALL_OUT_FILE} 2>&1
echo "****************************"            >> ${ALL_OUT_FILE} 2>&1
echo "RUNNING TRANSEQ WITH $*"                 >> ${ALL_OUT_FILE} 2>&1
date                                           >> ${ALL_OUT_FILE} 2>&1
echo  "transeq -trim -frame=6 -sformat1 pearson -osformat2 pearson $INPUT $OUTPUT"         >> ${ALL_OUT_FILE} 2>&1
transeq -trim -frame=6 -sformat1 pearson -osformat2 pearson $INPUT $OUTPUT                 >> ${ALL_OUT_FILE} 2>&1
if[ -d $SPLITOUTPATH ]{
	SPLITOUTPUT=${SPLITOUTPATH}/${OUTBASENAME}${SGE_TASK_ID}.fa              >> ${ALL_OUT_FILE} 2>&1
	echo "perl ${SCRIPTS}/split_orf_on_stops.pl -i $OUTPUT -o $SPLITOUTPUT -l $FILTERLENGTH"  >> ${ALL_OUT_FILE} 2>&1
	perl ${SCRIPTS}/split_orf_on_stops.pl -i $OUTPUT -o $SPLITOUTPUT -l $FILTERLENGTH         >> ${ALL_OUT_FILE} 2>&1
	date                                                                     >> ${ALL_OUT_FILE} 2>&1
	echo "RUN FINISHED"                                                      >> ${ALL_OUT_FILE} 2>&1
} else {
	date                                              >> ${ALL_OUT_FILE} 2>&1
	echo "RUN FINISHED"                               >> ${ALL_OUT_FILE} 2>&1
} fi

echo "****************************"            >> ${ALL_OUT_FILE} 2>&1
