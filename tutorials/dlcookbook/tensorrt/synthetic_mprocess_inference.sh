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
rm -rf ./logs/synthetic_mprocess/8
mkdir -p ./logs/synthetic_mprocess/8

gpus="0,1,2,3,4,5,6,7";
cores="0-3,4-7,8-11,12-15,18-21,22-25,26-29,30-33"
cores=(${cores//,/ });
gpus=(${gpus//,/ });
for i in "${!gpus[@]}"
do
    gpu=${gpus[$i]}
    core=${cores[$i]}

    #taskset -c $core \
    numactl --localalloc --physcpubind=$core \
    python $dlbs run \
           --log-level=$loglevel\
           -Pruntime.launcher='"TENSORRT_USE_PINNED_MEMORY=1 TENSORRT_DO_NOT_OVERLAP_COPY_COMPUTE=0 TENSORRT_INFERENCE_IMPL_VER=0"'\
           -Pexp.dtype='"float32"'\
           -Pexp.gpus=\"$gpu\"\
           -Vexp.model='["alexnet_owt"]'\
           -Pexp.replica_batch=512\
           -Pexp.num_warmup_batches=50\
           -Pexp.num_batches=500\
           -Ptensorrt.inference_queue_size=4\
           -Pexp.log_file='"${BENCH_ROOT}/logs/synthetic_mprocess/8/${exp.model}_${exp.gpus}.log"'\
           -Pexp.phase='"inference"'\
           -Pexp.docker=true\
           -Pexp.docker_image='"hpe/tensorrt:cuda9-cudnn7"'\
           -Pexp.framework='"tensorrt"' &
done
wait

params="exp.status,exp.framework_title,exp.effective_batch,results.time,results.throughput,exp.model_title"
python $parser ./logs/synthetic_mprocess/8/*.log --output_params ${params}
