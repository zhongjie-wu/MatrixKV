#!/bin/sh

# This test is based on test 2 and uses all the same arguments as the tiered-rdb configuration

value_array=1024
#test_all_size=81920000000   #8G
test_all_size=40960000000

#bench_db_path="/mnt/ssd/test"
bench_db_path="/data/mkv"
#wal_dir="/mnt/ssd/test"
wal_dir="/data/mkv"

bench_compression="none" #"snappy,none"

#bench_benchmarks="fillseq,stats,readseq,readrandom,stats" #"fillrandom,fillseq,readseq,readrandom,stats"
#bench_benchmarks="fillrandom,stats,readseq,readrandom,readrandom,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,stats,readseq,readrandom,readrandom,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readseq,readrandom,stats"
#bench_benchmarks="fillrandom,stats,sleep20s,clean_cache,stats,readseq,clean_cache,stats,readrandom,stats"
bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readseq,clean_cache,stats,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readrandom,stats"
#bench_benchmarks="fillseq,stats"

bench_num="20000000"

# Read only
#bench_readnum="10000000" # reads
#writes="0"
# Write only
#bench_readnum="0" # reads

#bench_max_open_files="1000"
max_background_jobs="3"
max_bytes_for_level_base="`expr 8 \* 1024 \* 1024 \* 1024`" 
#max_bytes_for_level_base="`expr 256 \* 1024 \* 1024`" 

threads="1"

pmem_path="/mnt/pmem1/nvm"
use_nvm="true"

#report_write_latency="true"
#report_ops_latency="true"
report_fillrandom_latency="true"
key_size="16"

histogram="true"
statistics="true"

stats_interval="5000000"

# cache_size="16106127360" #15G
cache_size="1073741824" #1G

# Added to align with the other configuration
max_background_flushes="1"
max_background_compactions="3"
write_buffer_size="134217728"
disable_wal="false"
level0_file_num_compaction_trigger="4"
max_write_buffer_number="2"
block_align="true"

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

RUN_ONE_TEST() {
    const_params="
    --db=$bench_db_path \
    --wal_dir=$wal_dir \
    --threads=$threads \
    --value_size=$bench_value \
    --benchmarks=$bench_benchmarks \
    --num=$bench_num \
    --reads=$bench_readnum \
    --key_size=$key_size \
    --compression_type=$bench_compression \
    --max_background_jobs=$max_background_jobs \
    --max_bytes_for_level_base=$max_bytes_for_level_base \
    --report_fillrandom_latency=$report_fillrandom_latency \
    --use_nvm_module=$use_nvm \
    --pmem_path=$pmem_path \
    --histogram=$histogram \
    --statistics=$statistics \
    --stats_interval=$stats_interval \
    --cache_size=$cache_size \
    --max_background_flushes=$max_background_flushes \
    --max_background_compactions=$max_background_compactions \
    --write_buffer_size=$write_buffer_size \
    --disable_wal=$disable_wal \
    --level0_file_num_compaction_trigger=$level0_file_num_compaction_trigger \
    --max_write_buffer_number=$max_write_buffer_number \
    --block_align=$block_align \
    "

    cmd="$bench_file_path $const_params >>out.out 2>&1"
    echo $cmd >out.out
    echo $cmd
    eval $cmd
}

CLEAN_CACHE() {
    if [ -n "$bench_db_path" ];then
        rm -f $bench_db_path/*
    fi
    sleep 2
    sync
    echo 3 > /proc/sys/vm/drop_caches
    sleep 2
}

COPY_OUT_FILE(){
    mkdir $bench_file_dir/result > /dev/null 2>&1
    res_dir=$bench_file_dir/result/value-$bench_value
    mkdir $res_dir > /dev/null 2>&1
    \cp -f $bench_file_dir/compaction.csv $res_dir/
    \cp -f $bench_file_dir/OP_DATA $res_dir/
    \cp -f $bench_file_dir/OP_TIME.csv $res_dir/
    \cp -f $bench_file_dir/out.out $res_dir/
    \cp -f $bench_file_dir/Latency.csv $res_dir/
    #\cp -f $bench_file_dir/NVM_LOG $res_dir/
    \cp -f $bench_db_path/OPTIONS-* $res_dir/
    #\cp -f $bench_db_path/LOG $res_dir/
}
RUN_ALL_TEST() {
    for value in 1024; do
        CLEAN_CACHE
        bench_value="$value" # value size in bytes
        bench_num="`expr $test_all_size / $bench_value`"
	bench_readnum=$bench_num
        RUN_ONE_TEST
        if [ $? -ne 0 ];then
            exit 1
        fi
        COPY_OUT_FILE
        sleep 5
    done
}

RUN_ALL_TEST