#!/bin/bash

# set -uxeo pipefail

# if [[ -e telnet-clusterIPPort.err ]];then
#   rm -rf telnet-clusterIPPort.err
# fi


svcs=`kubectl get svc -A | grep ClusterIP | grep -v None`
clusterIPs=`kubectl get svc -A | grep ClusterIP | grep -v None | awk '{print $4}'`

for clusterIP in $clusterIPs; do
  svcName=`kubectl get svc -A | grep ClusterIP | grep -v None | grep $clusterIP | awk '{print $2}'`
  svcType=`kubectl get svc -A | grep ClusterIP | grep -v None | grep $clusterIP | awk '{print $3}'`
  ports=`kubectl get svc -A | grep ClusterIP | grep -v None | grep $clusterIP | awk '{print $6}' | awk 'BEGIN{FS=",";OFS="\n"}{$1=$1;print}' | awk -F "/" '{print $1}'`
 
  for port in $ports; do
    # printf "svcName--$svcName\t svcType--$svcType\t IPport--$clusterIP:$port\n"
    # echo svcName--$svcName/svcType--$svcType/IPPort--$clusterIP $port | tee -a clusterIPs.txt
    result=`echo quit | timeout --signal=9 2 telnet $clusterIP $port`
    if [[ $result =~ "Connected" ]]; then
      echo -e "\033[32m telnet $svcName $clusterIP $port--->ok \033[0m"
    else
      echo -e "\033[31m telnet $svcName $clusterIP $port--->failed \033[0m" | tee -a telnet-error.txt 
    fi
  done
done



pports=`kubectl get svc -A | grep NodePort | awk '{print $6}' | awk 'BEGIN{FS=",";OFS="\n"}{$1=$1;print}' | awk -F "/" '{print $1}' | awk -F ":" '{print $2}'`
locals=$(kubectl get node -o wide|sed '1d'|awk '{print $6}')
accept=2
refuse=4
errorFile=curl-error.txt

for local in ${locals[@]}
do
  for pport in $pports
   do
     name=`kubectl get svc -A | grep NodePort | grep $pport | awk '{print $2}'`
     result=`curl -m 1 -o /dev/null -s -w %{http_code} $local:$pport`
     if [[ $result =~ $accept ]];then
      echo -e "\033[32m curl  $name $local:$pport--->ok \033[0m"
     elif [[ $result =~ $refuse ]]; then
      echo -e "\033[31m curl  $name $local:$pport--->failed \033[0m"
      echo -e "\033[31m curl  $name $local:$pport--->failed \033[0m" >> $errorFile
     else
       echo -e "\033[31m curl  $name $local:$pport--->unknown \033[0m"
       echo -e "\033[31m curl  $name $local:$pport--->unknown \033[0m" >> $errorFile
     fi
  done
  echo "--------------------"
done
