#!/bin/bash
export BENCH_ROOT=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
export CUDA_CACHE_PATH=/dev/shm/cuda_cache
#------------------------------------------------------------------------------#
. ${BENCH_ROOT}/../../../scripts/environment.sh
dlbs=$DLBS_ROOT/python/dlbs/experimenter.py
parser=$DLBS_ROOT/python/dlbs/logparser.py
loglevel=warning
#------------------------------------------------------------------------------#
# Run multi-GPU inference with synthetic data.
#------------------------------------------------------------------------------#
# Change #GPUs in 4 places!
rm -rf ./logs/real
mkdir -p ./logs/real

gpus="0,1,2,3,4,5,6,7";
cores="0-3,4-7,8-11,12-15,18-21,22-25,26-29,30-33"
cores=(${cores//,/ });
gpus=(${gpus//,/ });
for i in "${!gpus[@]}"
do
    gpu=${gpus[$i]}
    core=${cores[$i]}
    rank=$gpu

    #taskset -c $core \
    numactl --localalloc --physcpubind=$core \
    python $dlbs run \
           --log-level=$loglevel\
           -Pruntime.launcher='"TENSORRT_SYNCH_BENCHMARKS=${tensorrt.rank},8,dlbs_ipc "'\
           -Pexp.docker_args='"--rm --ipc=host"'\
           -Ptensorrt.num_prefetchers=3\
           -Pexp.data_dir='"/lvol/serebrya/datasets/tensorrt227/uchar/${exp.gpus}"'\
           -Ptensorrt.data_name='"tensors1"'\
           -Pexp.dtype='"float16"'\
           -Pexp.gpus=\"$gpu\"\
           -Vexp.model='["resnet50"]'\
           -Pexp.replica_batch=128\
           -Pexp.num_warmup_batches=20\
           -Pexp.num_batches=200\
           -Ptensorrt.inference_queue_size=6\
           -Ptensorrt.rank=$rank\
           -Pexp.log_file='"${BENCH_ROOT}/logs/real/${exp.model}_${exp.gpus}.log"'\
           -Pexp.phase='"inference"'\
           -Pexp.docker=true\
           -Pexp.docker_image='"hpe/tensorrt:cuda9-cudnn7"'\
           -Pexp.framework='"tensorrt"' &
done
wait

params="exp.status,exp.framework_title,exp.effective_batch,results.time,results.throughput,exp.model_title,exp.gpus,results.mgpu_effective_throughput"
python $parser ./logs/real/*.log --output_params ${params}