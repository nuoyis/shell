# !/bin/sh
# 诺依阁-初始化脚本

#变量定义区域
#手动变量定义区域
auth="nuoyis"
CIDR="10.104.43"
gateway="10.104.0.1"
dns="223.5.5.5"
auth-init-shell="init.nuoyis.net"

#自动获取变量区域
whois=$(whoami)
nuo_setnetwork_shell=$(ifconfig -a | grep -o '^\w*' | grep -v 'lo')
if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d/" ]; then
	PM="yum"
elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
	PM="apt-get"
fi

# 函数类

# 系统项启动
nuoyis_systemctl_manger(){
	if [ -n $1 ] && [ -n $2 ];then
		if [ $1 = "start" ];then
			systemctl enable --now $2
		fi
	fi
}

# 源安装/更新()
nuoyis_install_manger(){
	case $1 in
		0)
			yes | $PM remove $2 -y
			;;
		1)
			yes | $PM install ${@:2} -y
			;;
		2)
			if [ $PM = "yum" ];then
				yes | $PM update
			fi
			yes | $PM upgrade
			;;
		3)
			$PM clean all
			;;
		4)
			$PM makecache
			;;
		5)
			if [ $PM = "yum" ];then
				yes | $PM $2 install ${@:3} -y
			fi
			;;
		*)
			echo "错误指令"
			exit 1
	esac
	# if [ $1 -eq 0 ];then
	# 	yes | $PM remove $2 -y
	# elif [ $1 -eq 1 ];then
	# 	yes | $PM install $2 -y
	# elif [ $1 -eq 2 ];then
	# 	if [ $PM = "yum" ];then
	# 		yes | $PM update
	# 	fi
	# 	yes | $PM upgrade
	# elif [ $1 -eq 3 ];then
	# 	$PM clean all
	
	# fi
}

# 写入文件
nuoyis_write_manger(){
	if [ $1 -eq 0 ];then
		$3 > $2
	elif [ $1 -eq 1 ];then
		$3 >> $2
	# elif [ $1 -eq 2 ];then
	fi
}

# 安装宝塔类
nuoyis_bt_install(){
# 阻止btpython SSL冲突
touch /root/.pip/pip.conf
cat > /root/.pip/pip.conf << EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple

[install]
trusted-host = mirrors.aliyun.com
EOF
	for service in nginx httpd mysqld pure-ftpd tomcat redis memcached mongodb pgsql tomcat tomcat7 tomcat8 tomcat9 php-fpm-52 php-fpm-53 php-fpm-54 php-fpm-55 php-fpm-56 php-fpm-70 php-fpm-71 php-fpm-72 php-fpm-73
		do
			if [ -f "/etc/init.d/${service}" ]; then
				/etc/init.d/${service} stop
				if [ -f "/usr/sbin/chkconfig" ];then
					chkconfig  --del ${service}
				elif [ -f "/usr/sbin/update-rc.d" ];then
					update-rc.d -f ${service} remove
				fi

				if [ "${service}" = "mysqld" ]; then
					rm -rf ${servicePath}/mysql
					rm -f /etc/my.cnf
				elif [ "${service}" = "httpd" ]; then
					rm -rf ${servicePath}/apache
				elif [ "${service}" = "memcached" ]; then
					rm -rf /usr/local/memcached
				elif [ -d "${servicePath}/${service}" ]; then
					rm -rf ${servicePath}/${service}
				fi 
				rm -f /etc/init.d/${service}
				echo -e ${service} "\033[32mclean\033[0m"
			fi
		done
	if [ -f /usr/bin/curl ];then
		curl -sSO https://download.bt.cn/install/install_panel.sh;
	else 
		wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh;
	fi;
	yes | bash ./install_panel.sh ed8484bec
}

echo "诺依阁服务器运维脚本"
echo 当前脚本pid为$$,如果卡死请执行kill -9 $$
read -p "是否继续执行(y/n):" nuoyis_go
if [ $nuoyis_go == "n" ];then
        echo "正在退出脚本"
        exit 0
fi

echo "检测是否是root用户"
if [ $whois != "root" ];then
	echo "非root用户，无法满足初始化需求"
	exit 1
fi

echo "创建诺依阁文件夹"
mkdir -p /$auth-web/{qinglong,kuandai,iptables,frp}

echo "检测hostname是否设置"
HOSTNAME_CHECK=$(cat /etc/hostname)
if [ -z $HOSTNAME_CHECK ];then
	echo "当前主机名hostname为空，设置默认hostname"
	hostnamectl set-hostname $auth-init-shell
fi

# echo "网卡(校园网)静态配置"
# for i in {3..254};
# do
# ip=$CIDR.$i
# ping -c 2 $ip > /dev/null 2>&1
# if [ $? -eq 1 ]; then
#     nuoautoip=$ip
#     break
# fi
# done
# nmcli connection modify $nuo_setnetwork_shell ipv4.method man ipv4.addresses ${nuoautoip}/24 ipv4.gateway ${gateway} ipv4.dns ${dns}
# nmcli connection up $nuo_setnetwork_shell
# nmcli connection reload
# systemctl stop NetworkManager
# systemctl start NetworkManager

echo "安装源更新"
reponum=`$PM list | wc -l`

# if [ $reponum -lt 1000 ];then
	if [ $PM = "yum" ];then
		mkdir /etc/yum.repos.d/bak
		mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
		cat > /etc/yum.repos.d/$auth.repo << EOF
[${auth}-BaseOS]
name=${auth} - BaseOS
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/BaseOS/\$basearch/os/
gpgcheck=0

[${auth}-baseos-debuginfo]
name=${auth} - BaseOS - Debug
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=BaseOS-\$releasever-debug\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/BaseOS/\$basearch/debug/tree/
gpgcheck=0

[${auth}-baseos-source]
name=${auth} - BaseOS - Source
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=BaseOS-\$releasever-source\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/BaseOS/source/tree/
gpgcheck=0

[${auth}-appstream]
name=${auth} - AppStream
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=AppStream-\$releasever\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/AppStream/\$basearch/os/
gpgcheck=0

[${auth}-appstream-debuginfo]
name=${auth} - AppStream - Debug
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=AppStream-\$releasever-debug\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/AppStream/\$basearch/debug/tree/
gpgcheck=0

[${auth}-appstream-source]
name=${auth} - AppStream - Source
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=AppStream-\$releasever-source\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/AppStream/source/tree/
gpgcheck=0

[${auth}-crb]
name=${auth} - CRB
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=CRB-\$releasever\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/CRB/\$basearch/os/
gpgcheck=0

[${auth}-crb-debuginfo]
name=${auth} - CRB - Debug
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=CRB-\$releasever-debug\$rltype
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/CRB/\$basearch/debug/tree/
gpgcheck=0

[${auth}-crb-source]
name=${auth} - CRB - Source
baseurl=https://mirrors.cernet.edu.cn/rocky/\$releasever/CRB/source/tree/
gpgcheck=0

[${auth}-epel]
name=${auth} - epel
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=https://mirrors.cernet.edu.cn/epel/\$releasever/Everything/\$basearch/
#metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-\$releasever&arch=\$basearch&infra=\$infra&content=\$contentdir
gpgcheck=0

[${auth}-epel-debuginfo]
name=${auth} - epel - Debug
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=https://mirrors.cernet.edu.cn/epel/\$releasever/Everything/\$basearch/debug/
#metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-\$releasever&arch=\$basearch&infra=\$infra&content=\$contentdir
gpgcheck=0

[${auth}-epel-source]
name=${auth} - epel - Source
baseurl=https://mirrors.cernet.edu.cn/epel/\$releasever/Everything/source/tree/
#metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-source-\$releasever&arch=\$basearch&infra=\$infra&content=\$contentdir
gpgcheck=0
EOF
	echo "正在更新dnf源"
	nuoyis_install_manger 3
	nuoyis_install_manger 2
	nuoyis_install_manger 4
	else
		sudo sed -i -r 's#http://(archive|security).ubuntu.com#https://mirrors.aliyun.com#g' /etc/apt/sources.list && sudo apt-get update
	fi
# fi

echo "配置基础系统文件"
yum config-manager --set-enabled crb
nuoyis_install_manger 1 bash* vim net-tools epel-release epel-next-release 
nuoyis_install_manger 2
nuoyis_install_manger 1 https://rpms.remirepo.net/enterprise/remi-release-9.rpm
# 来自https://www.rockylinux.cn


echo "更新内核至最新版"
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
nuoyis_install_manger 1 https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm

sed -i 's/mirrorlist=/#mirrorlist=/g' /etc/yum.repos.d/elrepo.repo
sed -i 's#elrepo.org/linux#mirrors.cernet.edu.cn/elrepo#g' /etc/yum.repos.d/elrepo.repo

yum makecache
nuoyis_install_manger 5 --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml.x86_64
nuoyis_install_manger 0 kernel-tools-libs.x86_64 kernel-tools.x86_64
nuoyis_install_manger 5 --disablerepo=\* --enablerepo=elrepo-kernel install kernel-ml-tools.x86_64
# kernel-Version=yum info kernel-ml-tools | grep Version | awk '{print $3}'

#安装宝塔
# nuoyis_bt_install

echo "安装Docker"
if [ $PM = "yum" ];then
nuoyis_install_manger 1 yum-utils device-mapper-persistent-data lvm2
yum config-manager --add-repo https://chinanet.mirrors.ustc.edu.cn/docker-ce/linux/centos/docker-ce.repo
fi
sed -i 's+download.docker.com+chinanet.mirrors.ustc.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo
nuoyis_install_manger 4
nuoyis_install_manger 1 docker-ce
mkdir -p /etc/docker
touch /etc/docker/daemon.json
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker66ccff.lovablewyh.eu.org"
  ],
  "bip": "192.168.100.1/24",
  "default-address-pools": [
    {
      "base": "192.168.100.0/16",
      "size": 24
    }
  ]
}
EOF
nuoyis_systemctl_manger start docker
#
#echo "自启动firewalld"
## 安装并启用firewalld
#sudo yum install -y firewalld
#sudo systemctl enable --now firewalld
#
#echo "网卡转发配置"
## 启用IP转发
#sudo sysctl -w net.ipv4.ip_forward=1
#echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
#
## 配置转发和屏蔽规则
#sudo firewall-cmd --permanent --add-masquerade
## sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" forward destination address="172.17.1.2" reject'
## sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" forward source address="172.17.1.2" reject'
#
## 重新加载firewalld规则
#sudo firewall-cmd --reload
echo "安装完毕，向前出发吧"
