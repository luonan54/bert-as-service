#!/bin/sh
#
# English BERT models are
#
# cased_L-12_H-768_A-12  
# uncased_L-24_H-1024_A-16
# cased_L-12_H-768_A-12
# cased_L-24_H-1024_A-16

export MODEL=cased_L-12_H-768_A-12
wget https://storage.googleapis.com/bert_models/2018_10_18/$MODEL.zip
unzip $MODEL.zip
bert-serving-start -model_dir ./$MODEL -num_worker=4 -http_port 8125
