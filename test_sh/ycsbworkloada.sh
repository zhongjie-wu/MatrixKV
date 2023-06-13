#! /bin/sh

db="/data/mkv"
#bench_level0_file_path="/pmem/ceshi"
#level0_file_path=""
value_size="1024"
compression_type="none" #"snappy,none"

#bench_benchmarks="fillseq,stats,readseq,readrandom,stats" #"fillrandom,fillseq,readseq,readrandom,stats"
#bench_benchmarks="fillrandom,stats,readseq,readrandom,readrandom,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,stats,readseq,readrandom,readrandom,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readseq,readrandom,readrandom,readrandom,stats"
#benchmarks="fillrandom,stats"
benchmarks="ycsbwklda,stats"
num="40000000"

max_background_jobs="3"
#max_bytes_for_level_base="`expr 8 \* 1024 \* 1024 \* 1024`"   #8G
max_bytes_for_level_base="`expr 256 \* 1024 \* 1024`" 

#perf_level="1"

#stats_interval="100"
#stats_interval_seconds="10"
histogram="true"

threads="3"

benchmark_write_rate_limit="`expr 20000 \* \( $value_size + 16 \)`"  #20K iops, key: 16 bytes

report_ops_latency="true"
report_fillrandom_latency="true"


YCSB_uniform_distribution="true"
ycsb_workloada_num=13333333

stats_interval="10000000"
cache_size="1073741824" #1G
max_background_flushes="1"
max_background_compactions="3"
write_buffer_size="134217728"
disable_wal="false"
level0_file_num_compaction_trigger="4"
max_write_buffer_number="2"
block_align="true"
statistics="true"
pmem_path="/mnt/pmem1/nvm"
use_nvm="true"

const_params=""

FILL_PATAMS() {
    if [ -n "$db" ];then
        const_params=$const_params"--db=$db "
    fi

    # if [ -n "$level0_file_path" ];then
    #     const_params=$const_params"--level0_file_path=$level0_file_path "
    # fi

    if [ -n "$value_size" ];then
        const_params=$const_params"--value_size=$value_size "
    fi

    if [ -n "$compression_type" ];then
        const_params=$const_params"--compression_type=$compression_type "
    fi

    if [ -n "$benchmarks" ];then
        const_params=$const_params"--benchmarks=$benchmarks "
    fi

    if [ -n "$num" ];then
        const_params=$const_params"--num=$num "
    fi

    if [ -n "$reads" ];then
        const_params=$const_params"--reads=$reads "
    fi

    if [ -n "$max_background_jobs" ];then
        const_params=$const_params"--max_background_jobs=$max_background_jobs "
    fi

    if [ -n "$max_bytes_for_level_base" ];then
        const_params=$const_params"--max_bytes_for_level_base=$max_bytes_for_level_base "
    fi

    if [ -n "$perf_level" ];then
        const_params=$const_params"--perf_level=$perf_level "
    fi

    if [ -n "$threads" ];then
        const_params=$const_params"--threads=$threads "
    fi

    if [ -n "$stats_interval" ];then
        const_params=$const_params"--stats_interval=$stats_interval "
    fi

    # if [ -n "$stats_interval_seconds" ];then
    #     const_params=$const_params"--stats_interval_seconds=$stats_interval_seconds "
    # fi

    if [ -n "$histogram" ];then
        const_params=$const_params"--histogram=$histogram "
    fi

    # if [ -n "$benchmark_write_rate_limit" ];then
    #     const_params=$const_params"--benchmark_write_rate_limit=$benchmark_write_rate_limit "
    # fi

    # if [ -n "$request_rate_limit" ];then
    #     const_params=$const_params"--request_rate_limit=$request_rate_limit "
    # fi

    if [ -n "$report_ops_latency" ];then
        const_params=$const_params"--report_ops_latency=$report_ops_latency "
    fi

    if [ -n "$YCSB_uniform_distribution" ];then
        const_params=$const_params"--YCSB_uniform_distribution=$YCSB_uniform_distribution "
    fi

    if [ -n "$ycsb_workloada_num" ];then
        const_params=$const_params"--ycsb_workloada_num=$ycsb_workloada_num "
    fi

    if [ -n "$report_fillrandom_latency" ];then
        const_params=$const_params"--report_fillrandom_latency=$report_fillrandom_latency "
    fi

    ## Added to align tests

    if [ -n "$cache_size" ];then
       const_params=$const_params"--cache_size=$cache_size "
    fi

    if [ -n "$max_background_flushes" ];then
       const_params=$const_params"--max_background_flushes=$max_background_flushes "
    fi

    if [ -n "$max_background_compactions" ];then
       const_params=$const_params"--max_background_compactions=$max_background_compactions "
    fi

    if [ -n "$write_buffer_size" ];then
       const_params=$const_params"--write_buffer_size=$write_buffer_size "
    fi

    if [ -n "$disable_wal" ];then
       const_params=$const_params"--disable_wal=$disable_wal "
    fi

    if [ -n "$level0_file_num_compaction_trigger" ];then
       const_params=$const_params"--level0_file_num_compaction_trigger=$level0_file_num_compaction_trigger "
    fi

    if [ -n "$max_write_buffer_number" ];then
       const_params=$const_params"--max_write_buffer_number=$max_write_buffer_number "
    fi

    if [ -n "$block_align" ];then
       const_params=$const_params"--block_align=$block_align "
    fi

    if [ -n "$statistics" ];then
       const_params=$const_params"--statistics=$statistics "
    fi

    if [ -n "$use_nvm" ];then
       const_params=$const_params"--use_nvm_module=$use_nvm "
    fi

    if [ -n "$pmem_path" ];then
       const_params=$const_params"--pmem_path=$pmem_path "
    fi

    const_params=$const_params"--wal_dir=/data/mkv "
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


bench_file_path="$(dirname $PWD )/db_bench"
bench_file_dir="$(dirname $PWD )"

if [ ! -f "${bench_file_path}" ];then
bench_file_path="$PWD/db_bench"
bench_file_dir="$PWD"
fi

if [ ! -f "${bench_file_path}" ];then
echo "Error:${bench_file_path} or $(dirname $PWD )/db_bench not find!"
exit 1
fi

FILL_PATAMS 
CLEAN_CACHE

cmd="$bench_file_path $const_params >>out.out 2>&1"

echo $cmd >out.out
echo $cmd
eval $cmd

if [ $? -ne 0 ];then
    exit 1
fi
COPY_OUT_FILE