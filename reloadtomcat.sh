#!/bin/bash
# 用于上线后重启tomcat单机多实例集群
# 配合nginx和tomcat
# 创建：高峰
# 时间：2016-06-30
# 使用前必须查看全部代码
# 以确保适用于您要放置的服务器

# 依赖包：
# 	curl
# 	netstat
#	需要先设定checkPort方法里的url地址
#	需要先设定switchConf方法里的conf文件地址
#	需要先设定restartTomcat方法里的pid路径



# 设定全局变量
# 获取当前路径为变量path
source /etc/profile
path=$(cd $(dirname $BASH_SOURCE); pwd)\/


# 定义日志路径
logFile=/dev/null
# logFile=$path"reloadTomcat_"`date +%s`.log
NGINX_CONF_HOME="/etc/nginx/conf.d"
user=gaofeng




# 定义字体颜色
logErr() {
    echo -e `date +%G/%m/%d\ %T`" [\033[31;1m错误\033[0m] \033[31;1m"$@"\033[0m"
    echo `date +%G/%m/%d\ %T`" [错误] "$@ >> $logFile
}
logNotice(){
    echo -e `date +%G/%m/%d\ %T`" [\033[36;1m信息\033[0m] \033[36;1m"$@"\033[0m"
    echo `date +%G/%m/%d\ %T`" [信息] "$@ >> $logFile
}
logSucess(){
    echo -e `date +%G/%m/%d\ %T`" [\033[32;1m正确\033[0m] \033[32;1m"$@"\033[0m"
    echo `date +%G/%m/%d\ %T`" [正确] "$@ >> $logFile
}
echoRed(){
    echo -e "\033[31;1m"$@"\033[0m"
}
echoBlue(){
    echo -e "\033[36;1m"$@"\033[0m"
}
echoGreen(){
    echo -e "\033[32;1m"$@"\033[0m"
}
echoYellow(){
    echo -e "\033[33;1m"$@"\033[0m"
}

sleepa(){
	b=''
	for ((i=100;$i>=0;i-=2))
	do
	    printf "等待中:[%-50s]\r" $b 
	    sleep 0.1
	    b==$b
	done
	echo
}

checkPort() {	#检测http端口是否正常
	# 输入一个端口，返回以该端口请求url的http状态码。
	# http_code会有3个状态：000=超时，200=正常，其他不正常
	# 返回0=超时，1=正常，2=程序错误
	url="http://127.0.0.1:"$1"/"	
	logNotice "检测HTTP端口\t->\t$url"
	http_code=`curl -Is -m 10 -w %{http_code} -o /dev/null $url`

	if [ $http_code -eq 0 ];then
		# 0=超时
		logErr	"http_code\t->\t$http_code"
		logErr 	"检测结果\t->\t请求超时或端口未打开"
		return	0
	elif [ $http_code -eq 200 ];then
		logSucess "http_code\t->\t$http_code"
		logSucess "检测结果\t->\t状态正常"
		# 1=200 ok
		return 1
	else
		# 2=程序错误，状态码非200
		logErr "http_code\t->\t$http_code"
		logErr 	"检测结果\t->\t应用程序错误"
		return 2
	fi 
}

checkTcp() {	#输入一个地址:端口，一直检测连接数，等于0的时候退出！
	if [[ -z $1 ]]; then
		logErr 您必须指定一个TCP地址和端口
		switchConf
		exit 1
	fi

	logNotice "检测TCP连接\t->\t$1"
	tcpCount=`netstat -not|grep $1|wc -l`
	logNotice "TCP连接数量\t->\t$tcpCount"

	if [ $tcpCount -eq 0 ];then
		logSucess "当前所有用户都已经断开连接！"
	fi

	# 循环检测TCP连接
	while [[ $tcpCount -gt 0 ]]; do
		logErr "当前服务仍有$tcpCount个连接，等待一会后将重新检测！"

		sleepa
		logNotice "检测TCP连接\t->\t$1"
		tcpCount=`netstat -not|grep $1|wc -l`
		logNotice "TCP连接数量\t->\t$tcpCount"
		if [ $tcpCount -eq 0 ];then
			logSucess "当前所有用户都已经断开连接！"
		fi
	done
}

switchConf() {	#切换nginx的配置文件，必须按实际的配置文件名设定。
	if [ -z $1 ];then
		logNotice 没有指定配置文件，Nginx将加载默认负载均衡配置。
		mv $NGINX_CONF_HOME/tomcat7.conf $NGINX_CONF_HOME/tomcat7 >> /dev/null 2>&1
		mv $NGINX_CONF_HOME/tomcat9.conf $NGINX_CONF_HOME/tomcat9 >> /dev/null 2>&1
		mv $NGINX_CONF_HOME/tomcat $NGINX_CONF_HOME/tomcat.conf >> /dev/null 2>&1
		service nginx reload
	elif [[ $1 -eq 7 ]]; then
		logNotice 切换到Tomcat7存活的配置
		mv $NGINX_CONF_HOME/tomcat7 $NGINX_CONF_HOME/tomcat7.conf >> /dev/null 2>&1
		mv $NGINX_CONF_HOME/tomcat9.conf $NGINX_CONF_HOME/tomcat9 >> /dev/null 2>&1
		mv $NGINX_CONF_HOME/tomcat.conf $NGINX_CONF_HOME/tomcat >> /dev/null 2>&1
		service nginx reload
	elif [[ $1 -eq 9 ]]; then
		#statements
		logNotice 切换到Tomcat9存活的配置
		mv $NGINX_CONF_HOME/tomcat7.conf $NGINX_CONF_HOME/tomcat7 >> /dev/null 2>&1
		mv $NGINX_CONF_HOME/tomcat9 $NGINX_CONF_HOME/tomcat9.conf >> /dev/null 2>&1
		mv $NGINX_CONF_HOME/tomcat.conf $NGINX_CONF_HOME/tomcat >> /dev/null 2>&1
		service nginx reload
	else
		logErr 指定了错误的配置[$1]，将退出！
		switchConf
		exit 1
	fi
}

restartTomcat () {	#根据输入的tomcat序号，重启指定的Tomcat。

	if [ -z $1 ];then
		logErr 没有指定需要重启的Tomcat，这是不允许的，将退出。
		switchConf
		exit 1
	fi
	
	tomcatn="tomcat$1"
	PID=`cat /dev/shm/$tomcatn.pid`
	logNotice "指定的TOMCAT\t->\t$tomcatn"
	psPid=(`ps -ef | grep $tomcatn | grep -v grep | awk '{print $2}'`)
	length=${#psPid[*]}
	if [[ $length -gt 1  ]]; then
		logErr "查询到了不止一个$tomcatn进程"
		logErr "ps查询的数量\t->\t$length"
		logNotice "ps查到的进程\t->\t${psPid[*]}"
		logErr "请先处理重复的Tomcat进程，程序退出！"
		switchConf
		exit 1
	fi
	
	if [[ $PID -ne $psPid ]]; then
		#statements
		logErr "PID不符，请查看原因。"
		echoYellow	"$tomcatn.pid\t->\t[$PID]"
		echoYellow	"ps查询的PID\t->\t[$psPid]"
		arrPid=($psPid $PID)
		if [[ -z $psPid ]]; then
			logNotice "ps未查询到指定的tomcat进程，将启动tomcat。"
			oo=1
		else
			oo=0
		fi

		until [[ $oo -eq 1 ]]; do
			echoYellow	"请输入正确的pid："
			read input
			if [[ $input -eq $PID ]]; then
				oo=1
			elif [[ $input -eq $psPid ]]; then
				PID=$input
				oo=1
			else
				echoYellow "您输入的pid必须是下面任意一个："
				echoBlue ${arrPid[@]}
			fi
			logNotice "您指定的PID\t->\t$PID"
		done
	fi

	# 此时已经获取了tomcatN和其pid
	# 需要先使用pid杀进程，然后根据tomcatN号启动tomcat。
	if [[ $1 -eq 7 ]]; then
		logNotice "即将重启Tomcat7，如果您在进度条完成之前改变了想法，请按Ctrl+C终止。"
		sleepa
		# 杀进程
		kill -9 $PID
		rm -rf "/dev/shm/$tomcatn.pid"
		# 启动进程
		su - $user "/usr/local/$tomcatn/bin/startup.sh"
		logSucess 重启了Tomcat7
	elif [[ $1 -eq 9 ]]; then
		logNotice "即将重启Tomcat9，如果您在进度条完成之前改变了想法，请按Ctrl+C终止。"
		sleepa
		# 杀进程
		kill -9 $PID
		rm -rf "/dev/shm/$tomcatn.pid"
		# 启动进程
		su - $user "/usr/local/$tomcatn/bin/startup.sh"
		logSucess 重启了Tomcat9
	else
		logErr 您指定了错误的Tomcat号[$1]，这是不允许的，将退出！
		switchConf
		exit 1
	fi
}


######################################################################################
# 主程序开始
if [ `id -u` -gt 0 ];then
	# 必须使用root身份，否则不能操作nginx
	logErr 	"您必须使用root身份来执行此脚本。"
	exit	1
fi


switchConf 7
checkTcp 127.0.0.1:9090
restartTomcat 9
checkPort 9090
portStat=$?
until [[ "$portStat" -eq "1" ]]; do
	logErr "http状态码不正常，稍后会再检测一次。"
	sleepa
	checkPort 9090
	portStat=$?
	if [[ "$portStat" -eq "2" ]]; then
		logErr "http出现错误，将重启tomcat尝试。"
		restartTomcat 9
	fi
done


switchConf 9
checkTcp 127.0.0.1:7070
restartTomcat 7
checkPort 7070
portStat=$?
until [[ "$portStat" -eq "1" ]]; do
	logErr "http状态码不正常，稍后会再检测一次。"
	sleepa
	checkPort 7070
	portStat=$?
	if [[ "$portStat" -eq "2" ]]; then
		logErr "http出现5xx错误，将重启tomcat尝试。"
		restartTomcat 7
	fi
done

switchConf 
# 主程序结束
######################################################################################