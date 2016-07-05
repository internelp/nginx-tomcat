# nginx-tomcat
Nginx负载后端单机多实例Tomcat，做到热更新项目文件。


# tomcat部署路径
- /usr/local/tomcat7
- /usr/local/tomcat9

#Nginx三个配置文件
推荐使用淘宝的Tengine[tengine]，可以很容易的对upstream状态进行监控。
- tomcat 		正常负载均衡
- tomcat7		7070端口的tomcat存活
- tomcat9		9090端口的tomcat存活

#tomcat配置：
- 指定pid

[tengine]:http://tengine.taobao.org/