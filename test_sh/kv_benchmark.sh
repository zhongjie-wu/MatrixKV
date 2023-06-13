#!/bin/bash

WORKSPACE="$(dirname $PWD )"
RESULTS_DIR="${WORKSPACE}/setups_results"

#real run configs
NUM_RUNS=1
LOADING_PHASE_NUM=50000000
LOADING_PHASE_THREADS=1
EXECUTION_PHASE_NUM=100000000
EXECUTION_PHASE_THREADS=8
EXECUTION_PHASE_DUR=900


#system variable configs
MEMORY=16

# workload fixed opts
KEYSIZE=16
VALUESIZE=1024
BACKGROUND_FLUSHES=1
BACKGROUND_COMPACTIONS=3
CACHE_SIZE=1073741824
STATS_INTERVAL=1
HISTOGRAM="true"
COMPRESSION_TYPE="none"
WRITE_BUFFER_SIZE=134217728
DISABLE_WAL=false
LEVEL0_FILE_NUM_COMPACTION_TRIGGER=4
MAX_WRITE_BUFFER_NUMBER=2

# New added flags
STATISTICS="true"
USE_NVM="true"
PMEM_PATH="/mnt/pmem1/nvm"
WAL_DIR="/data/mkv"
report_ops_latency="true"
report_fillrandom_latency="true"

# ??
BLOCK_ALIGN=true

# workload variable opts
DB_DIR=""
USE_EXISTING_DB=""
UNIFORM_DISTRIBUTION=""
DURATION=""
# also: threads and ops num (passed directly to db_bench)

function reset_opts {
    DB_DIR=""
    USE_EXISTING_DB=""
    UNIFORM_DISTRIBUTION=""
    DURATION=""

    BACKEND=""
}

function add_db_bench_fixed_options {
    local OPTS=""
    OPTS+=" --block_align=$BLOCK_ALIGN"
    OPTS+=" --key_size=$KEYSIZE"
    OPTS+=" --value_size=$VALUESIZE"
    OPTS+=" --max_background_flushes=$BACKGROUND_FLUSHES"
    OPTS+=" --max_background_compactions=$BACKGROUND_COMPACTIONS"
    OPTS+=" --cache_size=$CACHE_SIZE"
    OPTS+=" --stats_interval_seconds=$STATS_INTERVAL"
    OPTS+=" --histogram=$HISTOGRAM"
    OPTS+=" --compression_type=$COMPRESSION_TYPE"
    OPTS+=" --write_buffer_size=$WRITE_BUFFER_SIZE"
    OPTS+=" --disable_wal=$DISABLE_WAL"
    OPTS+=" --level0_file_num_compaction_trigger=$LEVEL0_FILE_NUM_COMPACTION_TRIGGER"
    OPTS+=" --max_write_buffer_number=$MAX_WRITE_BUFFER_NUMBER"

    # New added fixed options
    $OPTS+=" --statistics=$STATISTICS"
    $OPTS+=" --use_nvm_module=$USE_NVM"
    $OPTS+=" --pmem_path=$PMEM_PATH"
    $OPTS+=" --wal_dir=$WAL_DIR"
    $OPTS+=" --report_ops_latency=$report_ops_latency"
    $OPTS+=" --report_fillrandom_latency=$report_fillrandom_latency"
}

# $1: workload name
function add_db_bench_variable_options {
    local OPTS=""

    if [[ "$1" == *"ycsb"* && "$1" != *"fill"* ]]; then
        UNIFORM_DISTRIBUTION="true"
        OPTS+=" --YCSB_uniform_distribution=$UNIFORM_DISTRIBUTION"
    fi

    if [[ -n "$USE_EXISTING_DB" ]]; then 
        OPTS+=" --use_existing_db=$USE_EXISTING_DB"
    fi

    if [[ -n "$DURATION" ]]; then 
        OPTS+=" --duration=$DURATION"
    fi

    echo $OPTS
}

# Run the benchmark with db_bench
# --$1: Workload (ycsbwklda, ycsbfill, etc)
# --$2: Number of operations
# --$3: Number of threads
function run_db_bench {
    echo "Running db_bench"

    local ADITIONAL_FIXED_OPTS=""
    ADITIONAL_FIXED_OPTS+=" $(add_db_bench_fixed_options)" #pass the extra flags

    local ADITIONAL_VARIABLE_OPTS=""
    ADITIONAL_VARIABLE_OPTS+=" $(add_db_bench_variable_options $1)" #pass the extra flags

    echo "=> workload opts: --benchmarks=$1 --num=$(($2 / $3)) --threads=$3 --db=$DB_DIR"
    echo "=> aditional fixed opts: $ADITIONAL_FIXED_OPTS"
    echo "=> aditional variable opts: $ADITIONAL_VARIABLE_OPTS"

    SECONDS=0
    sudo -E numactl -N 0 -m 0 $PERF_CMD \
    $EXECUTABLE_DIR/db_bench --benchmarks="$1" \
                             --num=$(($2 / $3)) \
                             --threads=$3 \
                             --db=$DB_DIR \
                             $ADITIONAL_FIXED_OPTS \
                             $ADITIONAL_VARIABLE_OPTS \
    echo "=> elapsed time: ${SECONDS} s"
}

CLEAN_CACHE() {
    if [ -n "$db" ];then
        rm -f $db/*
    fi
    sleep 2
    sync
    echo 3 > /proc/sys/vm/drop_caches
    sleep 2
}

COPY_OUT_FILE(){
    mkdir $bench_file_dir/result > /dev/null 2>&1
    res_dir=$bench_file_dir/result/value-$value_size
    mkdir $res_dir > /dev/null 2>&1
    \cp -f $bench_file_dir/compaction.csv $res_dir/
    \cp -f $bench_file_dir/OP_DATA $res_dir/
    \cp -f $bench_file_dir/OP_TIME.csv $res_dir/
    \cp -f $bench_file_dir/out.out $res_dir/
    \cp -f $bench_file_dir/Latency.csv $res_dir/
    \cp -f $bench_file_dir/PerSecondLatency.csv $res_dir/
    \cp -f $db/OPTIONS-* $res_dir/

    #\cp -f $db/LOG $res_dir/
}


function setup1_loading {
    DB_DIR="/data/mkv"

    run_db_bench "ycsbfill" $LOADING_PHASE_NUM $LOADING_PHASE_THREADS >>out.out 2>&1

    reset_opts
    CLEAN_CACHE
}

function setup1_execution {
    DB_DIR="/data/mkv"

    USE_EXISTING_DB="true"
    DURATION=$EXECUTION_PHASE_DUR

    run_db_bench "ycsbwklda" $EXECUTION_PHASE_NUM $EXECUTION_PHASE_THREADS >>out.out 2>&1

    reset_opts
    CLEAN_CACHE
}

function setup1 {
    local SESSION_NAME="setup1"

    echo "Executing Setup-1"

    local WORKLOAD_RESULTS_DIR="${RESULTS_DIR}/$SESSION_NAME/$(date '+%Y-%m-%d-%H-%M-%S')"
    mkdir -p $WORKLOAD_RESULTS_DIR
    local LOADING_RESULTS_DIR="${WORKLOAD_RESULTS_DIR}/loading"
    mkdir -p $LOADING_RESULTS_DIR
    local EXECUTION_RESULTS_DIR="${WORKLOAD_RESULTS_DIR}/execution"
    mkdir -p $EXECUTION_RESULTS_DIR

    { #LOADING PHASE
        setup1_loading
    } 2>&1 | tee "${LOADING_RESULTS_DIR}/log-loading.txt"
   
   
    for ((i=1; i <= $NUM_RUNS; i++));
    do
        sleep 60
        local RUN_RESULTS_DIR="${EXECUTION_RESULTS_DIR}/run-$i"
        mkdir -p $RUN_RESULTS_DIR
        { #EXECUTION PHASE
            setup1_execution
        } 2>&1 | tee "${RUN_RESULTS_DIR}/log-execution.txt"
        
    done
}


