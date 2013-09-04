#!/bin/bash
#
#$ -S /bin/bash
#$ -l arch=linux-x64
#$ -l h_rt=0:30:0
#$ -l scratch=3G
#$ -pe smp 2
#$ -cwd
#$ -r y
#$ -o /dev/null
#$ -e /dev/null

#$ -l mem_free=2G

ulimit -c 0 #suppress core dumps

SEQPATH=$1  # SEQ is query sequence file used in search step
SEQFILE=$2
RESPATH=$3 # RES is result table file produced in search step. Need prefix and suffix for array task naming convention (see below)
RESNAME_PRE=$4 # This will include the DB name used in the search given earlier naming convention, sge_task_id = db split number
RESNAME_SUFF=$5 # This will include the search result file extension

#Vars needed to produce mysqld table file
SAMPLE_ID=$6
ALGO=$7
TRANSMETH=$8
EVALUE=$9
COVERAGE=${10}
SCORE=${11}
PROJDIR=${12}
SCRIPTS=${13}
DELETE_RAW=${14}

#use for rerunning stopped jobs
SPLIT_REPROC_STRING=${15}

if [[ $SPLIT_REPROC_STRING && ${SPLIT_REPROC_STRING-x} ]]
then
INT_TASK_ID=$(echo ${SPLIT_REPROC_STRING} | awk -v i="${SGE_TASK_ID}" '{split($0,array,",")} END{ print array[i]}')
else
INT_TASK_ID=${SGE_TASK_ID}
fi

RESFILE=${RESNAME_PRE}_${INT_TASK_ID}${RESNAME_SUFF}
LOGS=${PROJDIR}/logs

#if [ -e ${RESPATH}/${RESFILE}.mysqld ]
#then
#exit
#fi

ALL_OUT_FILE=${LOGS}/parse_results/${JOB_ID}.${INT_TASK_ID}.all
echo ${ALL_OUT_FILE}

qstat -f -j ${JOB_ID}                                > ${ALL_OUT_FILE} 2>&1
uname -a                                            >> ${ALL_OUT_FILE} 2>&1
echo "****************************"                 >> ${ALL_OUT_FILE} 2>&1
echo "RUNNING PARSE_SEARCH_RESULTS WITH $*"         >> ${ALL_OUT_FILE} 2>&1
echo "INT_TASK_ID IS ${INT_TASK_ID}"                >> ${ALL_OUT_FILE} 2>&1
date                                                >> ${ALL_OUT_FILE} 2>&1

files=$(ls /scratch/${SEQFILE}* 2> /dev/null | wc -l )   >> ${ALL_OUT_FILE} 2>&1
echo $files                                              >> ${ALL_OUT_FILE} 2>&1
if [ "$files" != "0" ]; then
    echo "Removing cache files"
    rm /scratch/${SEQFILE}*
else
    echo "No cache files..."
fi                                                       >> ${ALL_OUT_FILE} 2>&1

echo "Copying search result file to scratch"             >> ${ALL_OUT_FILE} 2>&1
cp -f ${RESPATH}/${RESFILE} /scratch/                    >> ${ALL_OUT_FILE} 2>&1
echo "Copying sequence file to scratch"                  >> ${ALL_OUT_FILE} 2>&1
cp -f ${SEQPATH}/${SEQFILE} /scratch/${SEQFILE}          >> ${ALL_OUT_FILE} 2>&1

date                                                     >> ${ALL_OUT_FILE} 2>&1
#need to properly set the run time options
echo "perl ${SCRIPTS}/parse_results.pl --results-tab=/scratch/${RESNAME} --orfs-file=/scratch/${SEQFILE} --sample-id=${SAMPLE_ID}  --algo=${ALGO} --trans-method=${TRANSMETH} --evalue=${EVALUE} --coverage=${COVERAGE} --score=${SCORE}"            >> ${ALL_OUT_FILE} 2>&1
perl ${SCRIPTS}/parse_results.pl --results-tab=/scratch/${RESFILE} --orfs-file=/scratch/${SEQFILE} --sample-id=${SAMPLE_ID} --algo=${ALGO} --trans-method=${TRANSMETH} --evalue=${EVALUE} --coverage=${COVERAGE} --score=${SCORE} >> ${ALL_OUT_FILE} 2>&1
date                                                                                   >> ${ALL_OUT_FILE} 2>&1
echo "removing input and dbfiles from scratch"   >> ${ALL_OUT_FILE} 2>&1
rm /scratch/${SEQFILE}                           >> ${ALL_OUT_FILE} 2>&1
echo "moving results to main"                    >> ${ALL_OUT_FILE} 2>&1
mv /scratch/${RESFILE}.mysqld ${RESPATH}/        >> ${ALL_OUT_FILE} 2>&1
#only delete the raw if we successfully parsed data. else, we want to be able to try reparsing....
if [ $DELETE_RAW -eq "1" ] && [ -s ${RESPATH}/${RESFILE}.mysqld ] 
then
    rm ${RESPATH}/${RESFILE}
fi
echo "moved to main"                             >> ${ALL_OUT_FILE} 2>&1
date                                             >> ${ALL_OUT_FILE} 2>&1
echo "RUN FINISHED"                              >> ${ALL_OUT_FILE} 2>&1
