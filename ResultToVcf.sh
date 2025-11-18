#!/usr/bin/env bash
gt=$1
vcfPath=$2
aRes=`grep result $gt  | tr "," "\t" | awk '{ print $2;}'`
bRes=`grep result $gt  | tr "," "\t" | awk '{ print $3;}'`
sa=`echo $aRes | tr "_" "\t" | awk '{ print $2;}'`
sb=`echo $bRes | tr "_" "\t" | awk '{ print $2;}'`
ha=`echo $aRes | tr "_" "\t" | awk '{ print $3;}' | tr -d "h"`
hb=`echo $bRes | tr "_" "\t" | awk '{ print $3;}' | tr -d "h"`
if [[ $sb -eq "" ]]; then
	sb=$sa
	hb=$ha
fi
CombineVcfs.py  --hap1 $vcfPath/$sa.hap"$ha".var.vcf --hap2 $vcfPath/$sb.hap"$hb".var.vcf



