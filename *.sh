#!/usr/bin/bash

Ansible_commond=/usr/bin/ansible
Ansible_group="$1"
Ansible_Hosts_Name="hosts.txt"
soft_dir=/data/backup
trans_file=$2
Port=$3

str=hostname

#端口检测时间
num=6
second=10


#判断输入参数是否存在
[ -z $Ansible_group ] && echo -e "\033[31m请根据提示输入对应的参数(温馨提示:此脚本只针对于Java业务编写) \n脚本使用方法示例: sh $0 infofeed JOB_NAME Port\033[0m" && exit 1
[ -z $2 ] && echo -e "\033[31m请输入要传输的文件名字（无需输入后缀）\033[0m" && exit 1
[ -z $3 ] && echo -e "\033[31m请输入服务的端口号，用于部署检测\033[0m" && exit 1

#输出ansible主机组列表确认
echo -e "\033[31m $1组主机列表\033[0m" && $Ansible_commond $Ansible_group --list | grep -v hosts

#将主机组的列表名称输入到文件中
$Ansible_commond $Ansible_group --list | grep -v hosts > $Ansible_Hosts_Name


#循环ansible列表中的主机名字部署服务
while read line
do
	$Ansible_commond $line -mcopy -a"src=$soft_dir/$2/ dest=/data/$2/" >/dev/null
	[ $? != 0 ] && echo -e "\033[34m向目标服务器传输文件错误\033[0m" && exit 1
	$Ansible_commond $line -mshell -a"cp  /data/$2/$2.ini  /etc/supervisord.d/" >/dev/null
	[ $? != 0 ] && echo -e "\033[34m目标服务器supervisor启动文件copy错误\033[0m" && exit 1
	$Ansible_commond $line -mshell -a"supervisorctl update && supervisorctl restart $2:" >/dev/null
	#$Ansible_commond $line -mshell -a"$str"
	if [ $? == 0 ];then
		echo -e "\033[34m$line 部署完成\033[0m"
		for (( i=1; i<=$num;i++))
		do
			echo -e "\033[33m端口第 $i 次检测中\033[0m"
			$Ansible_commond $line -mshell -a"netstat -tnlp |grep $Port" >> /dev/null
			if [ $? == 0 ];then
				echo -e "\033[31m$line端口启动完成\033[0m"
				break
			elif [ $i == $num ];then
				echo -e "\033[33m$line 服务器$3 端口未启动,本次部署失败\033[0m" && exit 1
			else
				sleep $second
			fi
		done
	else
		echo -e "\033[34m目标服务器服务重启失败\033[0m" && exit 1 > /dev/null
	fi
done < $Ansible_Hosts_Name

