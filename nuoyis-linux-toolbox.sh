#!/bin/bash
# Script Name    : nuoyis toolbox
# Description    : Linux quick initialization and installation
# Create Date    : 2025-04-23
# auth           : nuoyis
# Webside        : blog.nuoyis.net
# debug          : bash nuoyis-toolbox -host aliyun -r edu -ln docker -doa -na -mp test666 -ku -tu
#########################
#### 手动变量定义区域 ####
#########################
shopt -s nullglob
# 环境变量设置
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# 语言设置
LANG=en_US.UTF-8
gpgkey=""
prefix=""
mirror_update=0
options_install=0
options_yum=0
options_lnmp=0
options_tuning=0
options_kernel_update=0
options_swap=0
options_docker=0
options_docker_app=0
options_nas=0
options_ollama=0
options_bt=0
options_k8s=0
options_k8s_version=""
options_k8s_master=""
options_k8s_node=""
options_k8s_keepalived=""
options_k8s_mask=""
options_k8s_password=""
options_k8s_device=""
options_k3s=0
options_k8s_mastersip=()
options_k8s_nodesip=()
# ---------- 菜单集合 ----------
show::help(){
	IFS=$'\n' read -r -d '' -a help_lines <<'EOF'
  -install            install nuoyis toolbox and autoupdate
  -remove             remove nuoyis toolbox and autoupdate
  -ln, -lnmp          install nuoyis version lnmp. Options: gcc docker yum
  -do, -dockerinstall install docker
  -doa, -dockerapp    install docker app (qinglong and openlist ...)
  -na, -nas           install vsftpd nginx and nfs
  -oll, -ollama       install ollama
  -bt, -btpanel       install bt panel
  -k8s, -kubernetes   install kubernetes cluster (require sub options below)
  --kv,-k8sversion    set k8s version (default latest)
  --km,-k8smaster     set k8s master ip list (comma separated)
  --kn,-k8snode       set k8s node ip list (comma separated)
  --kk,-k8skeepalived set k8s keepalived vip:port
  --ksk,-k8smask      set k8s subnet mask
  --kp,-k8spassword   set k8s ssh password
  --kd,-k8sdevice     set k8s device type (master/node)
  -k3s                install k3s light kubernetes
  -ku, -kernelupdate  install use elrepo to update kernel
  -n, -name           config yum name and folder name
  -host,-hostname     config default is options_toolbox_init,so you have use this options before install
  -r,  -mirror        config yum mirrors update,if you not used, it will not be executed. Options: edu aliyun original other
  -tu, -tuning	       config linux system tuning
  -sw, -swap          config Swap allocation, when your memory is less than 1G, it is forced to be allocated, when it is greater than 1G, it can be allocated by yourself
  -mp, -mariadbpassword config lnmp-mariadb password set  
  -h,  -help          show shell help
  -sha, -sha256sum    show shell's sha256sum
  exam1:           nuoyis-toolbox -initname nuoyis -host nuoyis-shanghai-1 -r aliyun -ln docker -tu -mp 123456 -na
  exam2(overseas): nuoyis-toolbox -initname nuoyis -host nuoyis-us-1 -r original -ln docker -tu -mp 123456 -na
  exam3(btpanel):  nuoyis-toolbox -initname nuoyis -host nuoyis-us-1 -r aliyun -bt
  exam4(k8s multi): nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.35,192.168.20.36,192.168.20.37 --kn 192.168.20.38 --kk 192.168.20.40:16443 --ksk 24 --kp 1 --kd master --kv 1.32.2
  exam5(k8s single):nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.36 --kn 192.168.20.37 --kp 1 --kd master --kv 1.23.1
  exam6(k3s light): nuoyis-toolbox -k3s
EOF

echo "welcome to use nuoyis's toolbox"
echo "Blog: https://blog.nuoyis.net"
echo "use: $0 [command]..."
echo
echo "command:"
# 遍历并输出
for line in "${help_lines[@]}"; do
    echo "$line"
done
exit 0
}
[ "$#" == "0" ] && show::help

while [[ $# -gt 0 ]]; do
    case "$1" in
	    -install)
			options_install=1
		    shift
		    ;;
		-remove)
			rm -rf /usr/bin/nuoyis-toolbox
			crontab -l 2>/dev/null | sed '/nuoyis-toolbox/d' | crontab -
			exit 0
			;;
        -n|-name|-initname)
            prefix=$2
            shift 2
            ;;
        -host|-hostname)
            hostnamectl set-hostname $2
            shift 2
            ;;
        -r|-mirror)
            if [[ "$2" != "aliyun" && "$2" != "edu" && "$2" != "original" && "$2" != "other" ]]; then
                echo "unknown volume: $2"
                show::help
                exit 1
            fi
            options_yum_install=$2
            options_yum=1
            # conf::reposource
            shift 2
            ;;
		-ru|-mirrorupdate)
			mirror_update=1
			shift
			;;
        -ln|-lnmp)
            if [[ "$2" != "gcc" && "$2" != "docker" && "$2" != "yum" ]]; then
                echo "unknown volume: $2"
                show::help
                exit 1
            elif [ "$2" == "docker" ];then
				options_docker=1
			fi
			options_lnmp_value=$2
            options_lnmp=1
            # install::lnmp
            shift 2
            ;;
		-tu|-tuning)
			options_tuning=1
			shift
			;;
		-ku|-kernelupdate)
			options_kernel_update=1
			shift
			;;
        -sw|-swap)
            options_swap_value=$2
            options_swap=1
            shift 2
            ;;
        -mp|-mysqlpassword)
            options_mariadb_value=$2
            shift 2
            ;;
        -do|-dockerinstall)
            # install::docker
            options_docker=1
            shift
            ;;
		-xyl|-xuanyuanlogin)
			options_docker_xuanyuanpro_username=$2
			options_docker_xuanyuanpro_password=$3
			shift 3
			;;
		-xyu|-xuanyuanurl)
			if [[ "$2" != https://* ]]; then
    			options_docker_xuanyuanpro_url="https://$2"
			else
				options_docker_xuanyuanpro_url=$2
			fi
			shift 2
			;;
        -doa|-dockerapp)
            # install::docker
            options_docker_app=1
            shift
            ;;
        -na|-nas)
            # install::nas
            options_nas=1
			if [ -z $options_lnmp ];then
				options_lnmp=1
				options_lnmp_value=gcc
			fi
            shift
            ;;
        -oll|-ollama)
            options_ollama=1
            shift
            ;;
        -bt|-btpanelenable)
            options_bt=1
            shift
            ;;
		-up|-update)
			nuoyis_install_mirrors=$2
			update::version
			exit 0
			;;
		-sha|-sha256sum)
			show::version
			echo "shell latest version sha256sum: $REMOTE_HASH"
			echo "shell local version sha256sum: $LOCAL_HASH"
			exit 0
			;;
        -h|-help)
            show::help
            ;;
		-k8s|-kubernetes)
			options_k3s=0
			options_k8s=1
			shift
			;;
		--kv|-k8sversion)
			options_k8s_version=$2
			shift 2
			;;
		--km|-k8smaster)
			options_k8s_master=$2
			IFS=',' read -ra options_k8s_mastersip <<< "$2"
			shift 2
			;;
		--kn|-k8snode)
			options_k8s_node=$2
			IFS=',' read -ra options_k8s_nodesip <<< "$2"
			shift 2
			;;
		--kk|-k8skeepalived)
			options_k8s_keepalived=$2
			shift 2
			;;
		--ksk|-k8smask)
			options_k8s_mask=$2
			shift 2
			;;
		--kp|-k8spassword)
			options_k8s_password=$2
			shift 2
			;;
		--kd|-k8sdevice)
			options_k8s_device=$2
			shift 2
			;;
		-k3s)
			options_k8s=0
			options_k3s=1
			shift
			;;
        -*)
            echo "unknown command: $1"
            show::help
            ;;
        *)
            echo "unknown Options: $1"
            show::help
            ;;
    esac
done

prefixmirror=${prefix:+$prefix - }
prefixpath=${prefix:+$prefix-}

##########################
###  自动变量初始化区域  ###
##########################
# 脚本执行时间统计
startTime=`date +%Y%m%d-%H:%M:%S`
startTime_s=`date +%s`
# 登陆用户判断
whois=$(whoami)
# nuo_setnetwork_shell=$(ip a | grep -E '^[0-9]+: ' | grep -v lo | awk '{print $2}' | sed 's/://')
# 网卡获取
nuo_setnetwork_shell=$(ip a | grep -oE "inet ([0-9]{1,3}.){3}[0-9]{1,3}" | awk 'NR==2 {print $2}')
# 系统名称类型获取
system_name=`head -n 1 /etc/os-release | grep -oP '(?<=NAME=").*(?=")' | awk '{print$1}'`
system_version=`cat /etc/os-release | grep -oP '(?<=VERSION_ID=").*(?=")'`
system_version=${system_version%.*}
# 脚本初始化锁
if [[ ! -f /root/.toolbox-install-init.lock ]]; then
	installlock=0
else
	installlock=1
fi
# 脚本使用代理站源判断
if ping -c1 -W1 google.com >/dev/null 2>&1; then
    server_location="overseas"
elif ping -c1 -W1 www.baidu.com >/dev/null 2>&1; then
	server_location="cn"
else
	server_location="overseas"
fi
# vsftpd配置
if [ $system_name == "Debian" ] || [ $system_name == "Ubuntu" ];then
	vsftpdfile="/etc/vsftpd.conf"
else
	vsftpdfile="/etc/vsftpd/vsftpd.conf"
fi
# ---------- 镜像源 ----------
case "$options_yum_install" in
    edu)
		mirror_url="mirrors.cernet.edu.cn"
		;;
    aliyun)
		mirror_url="mirrors.aliyun.com"
		;;
    original)
		[ $options_lnmp_value == "Rocky" ] && mirror_url="dl.rockylinux.org"
		;;
    *)
		mirror_url="mirrors.aliyun.com"
		;;
esac
# ---------- 检测包管理器 ----------
if command -v yum >/dev/null 2>&1 && [ -d /etc/yum.repos.d ]; then
    # ---------- 新旧包管理器判断 ----------
    if (( system_version < 8 )); then
        PM="yum"
        PMpath="/etc/yum.conf"
    else
        PM="dnf"
        PMpath="/etc/dnf/dnf.conf"
    fi

    osname="$system_name"
    osversion="\$releasever"
    # ---------- 系统逻辑 ----------
    case "$system_name" in
        CentOS)
            case "$system_version" in
                [0-7])
					osname="centos-vault";
					osversion="7.9.2009"
					gpgcheck=0
					gpgkey="https://${mirror_url}/centos-vault/RPM-GPG-KEY-CentOS-7"
					repos=(
						"baseOS os/\$basearch/"
        			    "updates updates/\$basearch/"
        			    "extras extras/\$basearch/"
        			    "centosplus centosplus/\$basearch/"
        			    "cr cr/\$basearch/"
        			)
					;;
                8)
					osname="centos-vault";
					system_pretty_name=`cat /etc/os-release | grep -oP '(?<=PRETTY_NAME=").*(?=")'`
					if [ "$system_pretty_name" == "CentOS Stream 8" ];then
						osversion="8-stream"
					else
						osversion="8.5.2111"
					fi
					gpgcheck=0
					gpgkey="https://${mirror_url}/centos/RPM-GPG-KEY-CentOS-Official"
					repos=(
						"baseOS BaseOS/\$basearch/os/"
						"appstream AppStream/\$basearch/os/"
        			    "HighAvailability HighAvailability/\$basearch/os/"
        			    "extras extras/\$basearch/os/"
        			    "PowerTools PowerTools/\$basearch/os/"
        			    "centosplus centosplus/\$basearch/os/"
        			)
					;;
                *)
					osname="centos-stream";
					osversion="\$releasever-stream"
					gpgcheck=0
					gpgkey="https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official-SHA256"
        			repos=(
						"baseos BaseOS/\$basearch/os/"
        			    "baseos-debug BaseOS/\$basearch/debug/tree/"
        			    "baseos-source BaseOS/source/tree/"
						"appstream AppStream/\$basearch/os/"
        			    "appstream-debug AppStream/\$basearch/debug/tree/"
        			    "appstream-source AppStream/source/tree/"
        			    "crb CRB/\$basearch/os/"
        			    "crb-debug CRB/\$basearch/debug/tree/"
        			    "crb-source CRB/source/tree/"
        			)
					;;
            esac
            ;;
        openEuler)
			eval $(grep -oP '(?<=PRETTY_NAME=").*(?=")' /etc/os-release | awk '{gsub(/[()]/,""); split($3,a,"-"); printf("ver=%s type=%s sp=%s\n",$2,a[1],a[2])}'); osname="openeuler-${ver}${type:+-$type}${sp:+-$sp}"
			osname="openeuler"
			osversion="openEuler-${ver}${type:+-$type}${sp:+-$sp}"
			gpgcheck=0
			gpgkey="https://${mirror_url}/${osversion}/OS/\$basearch/RPM-GPG-KEY-openEuler"
        	repos=(
				"OS OS/\$basearch/"
				"everything everything/\$basearch/"
				"EPOL EPOL/main/\$basearch/"
				"debuginfo debuginfo/\$basearch/"
				"source source/"
				"update update/\$basearch/"
				"update-source update/source/"
        	)
			;;
		Rocky)
			case "$options_yum_install" in
            	edu)      osname="rocky" ;;
            	aliyun)   osname="rockylinux" ;;
            	original) osname="pub/rocky" ;;
        	esac
			gpgcheck=1
        	gpgkey="https://${mirror_url}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever"
        	repos=(
				"baseos BaseOS/\$basearch/os/"
        	    "baseos-debug BaseOS/\$basearch/debug/tree/"
        	    "baseos-source BaseOS/source/tree/"
				"appstream AppStream/\$basearch/os/"
        	    "appstream-debug AppStream/\$basearch/debug/tree/"
        	    "appstream-source AppStream/source/tree/"
        	    "crb CRB/\$basearch/os/"
        	    "crb-debug CRB/\$basearch/debug/tree/"
        	    "crb-source CRB/source/tree/"
        	)
			;;
    esac

    # ---------- SELinux ----------
    if [[ -f /etc/redhat-release ]]; then
        setenforce 0 &>/dev/null
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    fi
# ---------- Debian / Ubuntu ----------
elif command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
    PM="apt"
    export DEBIAN_FRONTEND=noninteractive
    export UCF_FORCE_CONFFNEW=1
    export NEEDRESTART_MODE=a
    export APT_LISTCHANGES_FRONTEND=none

    if (( installlock == 0 )) && [[ -f /etc/needrestart/needrestart.conf ]]; then
        sed -i 's|#\$nrconf{restart} = .*|$nrconf{restart} = "a";|' \
            /etc/needrestart/needrestart.conf
    fi

fi
# 时间同步配置文件位置判断
if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
	chronyconf=/etc/chrony.conf
else
	chronyconf=/etc/chrony/chrony.conf
fi

# root判断
echo "检测是否是root用户"
if [ $whois != "root" ];then
	echo "非root用户，无法满足初始化需求"
	exit 1
fi

#################
#### 函数区域 ####
#################

# 用户终止脚本判断
exit::backoff() {
    case $exit_type in
        SIGINT)
            echo "用户执行Ctrl+C"
            ;;
        SIGTERM)
            echo "进程被杀死"
            ;;
        SIGHUP)
            echo "终端连接异常"
            ;;
        *)
            echo "未知信号"
            ;;
    esac
	echo "正在清理残余文件并退出脚本"
	rm -rf /server/install
	rm -rf /root/.toolbox-install-init.lock
	exit 1
}

trap 'exit_type=SIGINT; exit::backoff' SIGINT
trap 'exit_type=SIGTERM; exit::backoff' SIGTERM
trap 'exit_type=SIGHUP; exit::backoff' SIGHUP

manager::nuoyis::download(){
	host="shell.nuoyis.net"
	cdncnameurl="shell.nuoyis.net.eo.dnse2.com"
	urlfile="$1"
	output="$2"
	downloadurl="https://$host/$urlfile"

	if [ -z "$output" ]; then
        output="$(pwd)/$(basename "$urlfile")"
    fi

	echo "cf节点 尝试下载"
	curl -Lk --connect-timeout 10 -o "$output" "$downloadurl"
	if [ $? -ne 0 ]; then
		echo "cf 节点下载失败，正在使用eo节点"
		# 解析 cname IP
        cname_ip=$(getent ahostsv4 "$cdncnameurl" | awk '{print $1}' | head -n1)
		if [ -z "$cname_ip" ]; then
            echo "eo节点 CNAME 解析失败"
            return 1
        fi
		curl --connect-to $host:443:$cname_ip:443 -o "$output" $downloadurl
		if [ $? -ne 0 ]; then
            echo "eo节点 下载失败"
            return 1
		fi
	fi
}

manager::download(){
	if [ -f /usr/bin/wget ];then
		wget $1;
	else
		curl -sSOLk $1;
	fi
}

manager::systemctl(){
	if [ -n $1 ] && [ -n $2 ];then
		case $1 in
			"start")
			for app_start in ${@:2}
			do
				systemctl enable --now $app_start
			done
				;;
			"stop")
				systemctl stop $2
				;;
			"reload")
				systemctl reload $2
				;;
			"poweroff")
				systemctl poweroff
				;;
			"reboot")
				systemctl reboot
				;;
			*)
				# 无效参数处理
				echo "错误指令"
				exit 1
		esac
	fi    
}

manager::repositories(){
    case $1 in
		"remove")
			# 移除指定的软件包
			yes | $PM autoremove $2 -y
			;;
		"install")
			# 安装多个指定的软件包
			for options_repo_install in ${@:2}
			do
				yes | $PM install $options_repo_install -y
			done
			;;
		"update")
			# 更新所有软件包
			if [ "$PM" = "apt" ]; then
				yes | $PM update -y
			fi
			yes | $PM upgrade -y
			;;
		"clean")
			# 清理缓存
			$PM clean all
			;;
		"makecache")
			# 生成缓存
			$PM makecache -y
			;;
		"installfull")
			# 在Yum中使用特定选项安装软件包
			if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
				yes | $PM $2 install ${@:3} -y
			fi
			;;
		"updatefull")
			# 在Yum中使用特定选项更新软件包
			if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
				yes | $PM $2 update ${@:3} -y
			fi
			;;		
		"installcheck") 
			# 检查指定的软件包是否安装
			$PM list installed | egrep $2 &>/dev/null
			;;
		"repoadd")
			# repo添加
			if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
				if [ $system_version -lt 8 ];then
					$PM-config-manager --add-repo $2
				else
					$PM config-manager --add-repo $2
				fi
			fi
			;;
		*)
			# 无效参数处理
			echo "错误指令"
			exit 1
	esac
}

manager::filewrite(){
	if [ $1 -eq 0 ];then
		$3 > $2
	elif [ $1 -eq 1 ];then
		$3 >> $2
	# elif [ $1 -eq 2 ];then
	fi
}

manager::swap(){
# 检查是否已有 swap 文件存在
swap_file=$(swapon --show=NAME | grep -E '/toolbox-swap')

if [ -n "$swap_file" ];then
	echo "虚拟内存已存在"
else
    memory=`free -m | awk '/^Mem:/ {print $2}'`
    if [ $memory -lt 1024 ] || [ $options_swap -eq 1 ];then
        echo "设置虚拟内存"
        if [ -z $options_swap_value ];then
            swapsize=$[1024*2];
        else
            swapsize=$options_swap_value
        fi
        cat > /etc/sysctl.conf << EOF
$(egrep -v '^vm.swappiness' /etc/sysctl.conf)
EOF
        echo "vm.swappiness=60" >> /etc/sysctl.conf
        dd if=/dev/zero of=/toolbox-swap bs=1M count=$swapsize
        chmod 0600 /toolbox-swap
        mkswap -f /toolbox-swap
        swapon /toolbox-swap
        echo "/toolbox-swap    swap    swap    defaults    0 0" >> /etc/fstab
        mount -a
        sysctl -p
    fi
fi
install::main
}

install::bt(){
# 阻止btpython SSL冲突
touch /root/.pip/pip.conf
cat > /root/.pip/pip.conf << EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple

[install]
trusted-host = mirrors.aliyun.com
EOF

# 原有宝塔则卸载
	if [ -f "/etc/init.d/bt" ] || [ -d "/www/server/panel" ]; then
		echo -e "此服务器安装过宝塔，正在删除"
		manager::download https://download.bt.cn/install/bt-uninstall.sh;
		echo yes | source bt-uninstall.sh -y
		rm -rf ./bt-uninstall.sh
	fi

# 原有环境判断并卸载
    manager::repositories remove nginx* php* mariadb* mysql*
    systemctl disable nginx php-fpm mysqld
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
	manager::download https://download.bt.cn/install/install_panel.sh
	# 安装宝塔
	echo yes | source install_panel.sh -y

	# 修复宝塔php8.3 无--enable-mbstring问题
	manager::download https://gitee.com/nuoyis/shell/raw/main/btpanel_bug_update/php.sh
	mv -f ./php.sh /www/server/panel/install/php.sh 2>/dev/null
	
	# 删除残留脚本
	rm -rf ./install_panel.sh
}

install::nas(){
	manager::repositories install vsftpd samba
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    useradd nas
    mkdir -p /${prefixpath}server/sharefile
    chown root:nas /${prefixpath}server/sharefile
    chmod -R 775 /${prefixpath}server/sharefile
    chmod g+s /${prefixpath}server/sharefile
	sed -i '/root/d' /etc/vsftpd/user_list
	sed -i '/root/d' /etc/vsftpd/ftpusers

	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
    	firewall-cmd --permanent --add-service=samba
    	firewall-cmd --permanent --add-service=ftp
    	firewall-cmd --reload
	else
		ufw allow samba
		ufw allow ftp
	fi
    cat > $vsftpdfile << EOF
# 不以独立模式运行
listen=YES
# 支持 IPV6，如不开启 IPV4 也无法登录
# listen_ipv6=NO

# 匿名用户登录
anonymous_enable=NO
#anonymous_enable=YES
#no_anon_password=YES
# 允许匿名用户上传文件
#anon_upload_enable=YES
# 允许匿名用户新建文件夹
#anon_mkdir_write_enable=YES
# 匿名用户删除文件和重命名文件
#anon_other_write_enable=YES
# 匿名用户的掩码（022 的实际权限为 666-022=644）
# anon_umask=022
# anon_root=/${prefixpath}server/sharefile

# 系统用户登录
local_enable=YES
local_umask=022
local_root=/${prefixpath}server/sharefile
chroot_local_user=YES
allow_writeable_chroot=YES
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd/chroot_list
# 对文件具有写权限，否则无法上传
write_enable=YES
chown_uploads=YES
chown_username=nas

max_clients=0
max_per_ip=0

# 使用主机时间
use_localtime=YES
pam_service_name=vsftpd
EOF

cat >> /etc/samba/smb.conf <<EOF

[share]
        comment = share
        path = /${prefixpath}server/sharefile
		browsable = yes
		writable = yes
		#guest ok = yes
		force user = nas
		force group = nas
		create mask = 0775
		directory mask = 0775
        public = yes
EOF

# cat >> /etc/profile << EOF
# echo "################################"
# echo "#  Welcome  to  visit  NAS     #"
# echo "################################"
# EOF

if [[  $options_lnmp_value == "yum" ]];then
	cat > /${prefixpath}server/web/nginx/conf/nas.conf << EOF
server {
	listen 80;
    listen [::]:80;
	# listen 443 ssl;
	server_name _;
	#charset koi8-r;
	charset utf-8;
	location /nuoyisnb {
        alias /${prefixpath}server/sharefile;
        autoindex on;                         # 启用自动首页功能
        autoindex_format html;                # 首页格式为HTML
        autoindex_exact_size off;             # 文件大小自动换算
        autoindex_localtime on;               # 按照服务器时间显示文件时间
    
        default_type application/octet-stream;# 将当前目录中所有文件的默认MIME类型设置为
                                        # application/octet-stream
        if (\$request_filename ~* ^.*?\.(txt|doc|pdf|rar|gz|zip|docx|exe|xlsx|ppt|pptx)$) {
        # 当文件格式为上述格式时，将头字段属性Content-Disposition的值设置为"attachment"
        add_header Content-Disposition: 'attachment;'; 
        }
        sendfile on;                          # 开启零复制文件传输功能
        sendfile_max_chunk 1m;                # 每个sendfile调用的最大传输量为1MB
        tcp_nopush on;                        # 启用最小传输限制功能
        
        #aio on;                               # 启用异步传输
        directio 5m;                          # 当文件大于5MB时以直接读取磁盘的方式读取文件
        directio_alignment 4096;              # 与磁盘的文件系统对齐
        output_buffers 4 32k;                 # 文件输出的缓冲区大小为128KB
        
        #limit_rate 1m;                        # 限制下载速度为1MB
        #limit_rate_after 2m;                  # 当客户端下载速度达到2MB时进入限速模式
        max_ranges 4096;                      # 客户端执行范围读取的最大值是4096B
        send_timeout 20s;                     # 客户端引发传输超时时间为20s
        postpone_output 2048;                 # 当缓冲区的数据达到2048B时再向客户端发送
	}
	location /{
		rewrite ^/(.*) https://blog.nuoyis.net permanent;
	}
}
EOF
	rm -rf /${prefixpath}server/web/nginx/conf/default.conf
	systemctl reload nginx
elif [[ $options_lnmp_value == "gcc" ]] || [[ $options_lnmp_value == "docker" ]];then
	cat > /${prefixpath}server/web/nginx/conf/default.conf.init << EOF
# 默认页面的 自定义设置(禁止编写server，否则报错)

# 301 配置
# return 301 https://你的网站名\$request_uri;

# SSL 配置
ssl_certificate /web/nginx/server/conf/ssl/default.pem;
ssl_certificate_key /web/nginx/server/conf/ssl/default.key;
        
location /nuoyisnb {
    alias /web/sharefile;
    autoindex on;                         # 启用自动首页功能
    autoindex_format html;                # 首页格式为HTML
    autoindex_exact_size off;             # 文件大小自动换算
    autoindex_localtime on;               # 按照服务器时间显示文件时间

    default_type application/octet-stream;# 将当前目录中所有文件的默认MIME类型设置为
                                    # application/octet-stream
    if (\$request_filename ~* ^.*?\.(txt|doc|pdf|rar|gz|zip|docx|exe|xlsx|ppt|pptx)$) {
    	# 当文件格式为上述格式时，将头字段属性Content-Disposition的值设置为"attachment"
    	add_header Content-Disposition: 'attachment;';
    }
    sendfile on;                          # 开启零复制文件传输功能
    sendfile_max_chunk 1m;                # 每个sendfile调用的最大传输量为1MB
    tcp_nopush on;                        # 启用最小传输限制功能

    #aio on;                               # 启用异步传输
    directio 5m;                          # 当文件大于5MB时以直接读取磁盘的方式读取文件
    directio_alignment 4096;              # 与磁盘的文件系统对齐
    output_buffers 4 32k;                 # 文件输出的缓冲区大小为128KB

    #limit_rate 1m;                        # 限制下载速度为1MB
    #limit_rate_after 2m;                  # 当客户端下载速度达到2MB时进入限速模式
    max_ranges 4096;                      # 客户端执行范围读取的最大值是4096B
    send_timeout 20s;                     # 客户端引发传输超时时间为20s
    postpone_output 2048;                 # 当缓冲区的数据达到2048B时再向客户端发送
}
location /{
    rewrite ^/(.*) https://blog.nuoyis.net permanent;
}

# 错误页面配置
error_page 404 /404.html;
error_page 500 502 503 504 /50x.html;
EOF
	if [[ $options_lnmp_value == "gcc" ]];then
		sed -i "s#/web#/${prefixpath}server/web#g" /${prefixpath}server/web/nginx/conf/default.conf.init
		sed -i "s#alias /${prefixpath}server/web/sharefile#alias /${prefixpath}server/sharefile#g" /${prefixpath}server/web/nginx/conf/default.conf.init
		systemctl reload nginx
	else
		docker restart lnmp-np
	fi
fi

if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
	manager::systemctl start vsftpd smb nmb
else
	manager::systemctl start vsftpd smbd nmbd
fi

echo "You can visit the page http(s)://url/nuoyisnb"
echo "If you bring other parameters, You have 10 seconds to visit message."
sleep 10
}

install::docker(){
	echo "安装Docker"
	mkdir -p /${prefixpath}server/docker-yaml/
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
		manager::repositories install yum-utils device-mapper-persistent-data lvm2
		if [[ "$server_location" == "cn" ]];then
			manager::repositories repoadd https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
		else
			manager::repositories repoadd https://download.docker.com/linux/rhel/docker-ce.repo
		fi
		sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
		if [ $system_name == "openEuler" ];then
			sed -i 's+$releasever+8+'  /etc/yum.repos.d/docker-ce.repo
		fi
		manager::repositories makecache
	else
		install -m 0755 -d /etc/apt/keyrings
		if [[ "$server_location" == "cn" ]];then
			curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/${system_name,,}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.cernet.edu.cn/docker-ce/linux/${system_name,,} $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
		else
			curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${system_name,,} $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
		fi
		chmod a+r /etc/apt/keyrings/docker.gpg
		manager::repositories update
	fi
	manager::repositories install docker-ce docker-ce-cli containerd.io docker-compose-plugin
	mkdir -p /etc/docker
	touch /etc/docker/daemon.json
	mirrors=()
	if [[ "$server_location" == "cn" ]]; then
    	[ -n "$options_docker_xuanyuanpro_password" ] && mirrors+=("https://docker.xuanyuan.run") && docker login -u $options_docker_xuanyuanpro_username -p $options_docker_xuanyuanpro_password docker.xuanyuan.run
    	[ -n "$options_docker_xuanyuanpro_url" ] && mirrors+=("$options_docker_xuanyuanpro_url")
    	mirrors+=("https://docker.xuanyuan.me")
    	mirrors+=("https://docker.m.daocloud.io")
    	mirrors+=("https://docker66ccff.lovablewyh.eu.org")
		json=$(jq -n \
	    	--arg bip "192.168.100.1/24" \
	    	--argjson mirrors "$(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .)" \
	    	'{
	    	    "bip": $bip,
	    	    "default-address-pools": [
	    	        { "base": "192.168.100.0/16", "size": 24 }
	    	    ],
	    	    "registry-mirrors": $mirrors
	    	}'
		)
	else
		json=$(jq -n \
	    	--arg bip "192.168.100.1/24" \
	    	--argjson mirrors "$(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .)" \
	    	'{
	    	    "bip": $bip,
	    	    "default-address-pools": [
	    	        { "base": "192.168.100.0/16", "size": 24 }
	    	    ]
	    	}'
		)
	fi
	echo "$json" > /etc/docker/daemon.json
	manager::systemctl start docker
	if [ -f "/usr/bin/docker-compose" ];then
		echo "docker-compose 二进制文件已存在"
	else
		manager::nuoyis::download scriptresources/download/docker-compose/v2.33.0/docker-compose-linux-"$(uname -m)" /usr/bin/docker-compose
		chmod +x /usr/bin/docker-compose
	fi
}

install::dockerapp(){
	manager::nuoyis::download scriptresources/config/docker-compose/app.yaml.txt /${prefixpath}server/docker-yaml/app.yaml
	sed -i "s/\/server/\/${prefixpath}server/g" /${prefixpath}server/docker-yaml/app.yaml
	docker-compose -f /${prefixpath}server/docker-yaml/app.yaml up -d
}

install::ollama(){
    manager::download https://ollama.com/install.sh
	source install_panel.sh
}

install::lnmp::quick(){
	# 快速安装
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
		yes | dnf module reset php
		yes | dnf module install php:remi-8.4 -y
		manager::repositories install nginx* php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-redis mariadb-server
	else
		manager::repositories install nginx php8.4 php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-mbstring php8.4-curl mariadb-server
	fi
	manager::nuoyis::download scriptresources/config/nginx/nginx.conf.txt /etc/nginx/nginx.conf
	manager::nuoyis::download scriptresources/config/nginx/default.conf.txt /${prefixpath}server/web/nginx/conf/default.conf
	sed -i "s#/server#/${prefixpath}server#g" /etc/nginx/nginx.conf
	sed -i "s#/server#/${prefixpath}server#g"/${prefixpath}server/web/nginx/conf/default.conf
	cat > /${prefixpath}server/web/nginx/webside/default/index.html << EOF
welcome to nuoyis's server
EOF
	curl -k -L -o /${prefixpath}server/web/nginx/server/conf/ssl/default.pem https://lnmp.nuoyis.net/config/ssl/default.pem
	curl -k -L -o /${prefixpath}server/web/nginx/server/conf/ssl/default.key https://lnmp.nuoyis.net/config/ssl/default.key
	manager::systemctl start nginx php-fpm mariadb
}

install::lnmp::gcc(){
	# 编译安装
	echo "安装必要依赖项"
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
		manager::repositories install autoconf bison re2c make procps-ng gcc gcc-c++ iputils pkgconfig pcre pcre-devel zlib-devel openssl openssl-devel libxslt-devel libpng-devel libjpeg-devel freetype-devel libxml2-devel sqlite-devel bzip2-devel libcurl-devel libXpm-devel libzip-devel oniguruma-devel gd-devel geoip-devel
	else
		manager::repositories install autoconf bison re2c make procps gcc g++ iputils-ping pkg-config libpcre3 libpcre3-dev zlib1g-dev openssl libssl-dev libxslt1-dev libpng-dev libjpeg-dev libfreetype6-dev libxml2-dev libsqlite3-dev libbz2-dev libcurl4-openssl-dev libxpm-dev libzip-dev libonig-dev libgd-dev libgeoip-dev
	fi
	cd /server/install
	manager::nuoyis::download scriptresources/download/nginx/nginx-1.29.1.tar.gz
	manager::nuoyis::download scriptresources/download/php/php-8.4.20.tar.gz
	tar -xzvf nginx-1.29.1.tar.gz
	tar -xzvf php-8.4.20.tar.gz
	cd nginx-1.29.1
	sed -i 's/#define NGINX_VERSION\s\+".*"/#define NGINX_VERSION      "1.29.1"/g' ./src/core/nginx.h
    sed -i 's/"nginx\/" NGINX_VERSION/"nuoyis server"/g' ./src/core/nginx.h
    sed -i 's/Server: nginx/Server: nuoyis server/g' ./src/http/ngx_http_header_filter_module.c
    sed -i 's/"Server: " NGINX_VER CRLF/"Server: nuoyis server" CRLF/g' ./src/http/ngx_http_header_filter_module.c
    sed -i 's/"Server: " NGINX_VER_BUILD CRLF/"Server: nuoyis server" CRLF/g' ./src/http/ngx_http_header_filter_module.c
    ./configure --prefix=/${prefixpath}server/web/nginx/server \
        --user=web \
		--group=web \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module; \
	make -j$(nproc) && make install
	chmod +x /${prefixpath}server/nginx/server/sbin/nginx
	cd ../php-8.4.20
	./configure --prefix=/${prefixpath}server/web/php \
        --disable-shared \
        --with-config-file-path=/${prefixpath}server/web/php/etc/ \
        --with-curl \
        --with-freetype \
        --enable-gd \
        --with-jpeg \
        --with-gettext \
        --with-libdir=lib64 \
        --with-libxml \
        --with-mysqli \
        --with-openssl \
        --with-pdo-mysql \
        --with-pdo-sqlite \
        --with-pear \
        --enable-sockets \
        --with-mhash \
        --with-ldap-sasl \
        --with-xsl \
        --with-zlib \
        --with-zip \
        --with-bz2 \
        --with-iconv \
        --enable-fpm \
        --enable-pdo \
        --enable-bcmath \
        --enable-mbregex \
        --enable-mbstring \
        --enable-opcache \
        --enable-pcntl \
        --enable-shmop \
        --enable-soap \
        --enable-ftp \
        --with-xpm \
        --enable-xml \
        --enable-sysvsem \
        --enable-cli \
        --enable-intl \
        --enable-calendar \
        --enable-ctype \
        --enable-mysqlnd \
        --enable-session
    make -j$(nproc) && make install

# 文件下载
curl -k -L -o /${prefixpath}server/web/nginx/server/conf/head.conf https://lnmp.nuoyis.net/config/head.conf.txt
curl -k -L -o /${prefixpath}server/web/nginx/server/conf/nginx.conf https://lnmp.nuoyis.net/config/nginx.conf.txt
curl -k -L -o /${prefixpath}server/web/nginx/webside/default/index.html https://lnmp.nuoyis.net/config/index.html
curl -k -L -o /${prefixpath}server/web/nginx/server/conf/ssl/default.pem https://lnmp.nuoyis.net/config/ssl/default.pem
curl -k -L -o /${prefixpath}server/web/nginx/server/conf/ssl/default.key https://lnmp.nuoyis.net/config/ssl/default.key
curl -k -L -o /${prefixpath}server/web/nginx/server/conf/start-php.conf https://lnmp.nuoyis.net/config/start-php-latest.conf.txt
curl -k -L -o /${prefixpath}server/web/nginx/server/conf/path.conf https://lnmp.nuoyis.net/config/path.conf.txt
curl -k -L -o /${prefixpath}server/web/php/etc/php.ini https://lnmp.nuoyis.net/config/latest-php.ini.txt
curl -k -L -o /${prefixpath}server/web/php/etc/php-fpm.d/fpm.conf https://lnmp.nuoyis.net/config/fpm-latest.conf.txt
curl -k -L -o /${prefixpath}server/web/nginx/conf/nginx.conf.full.template https://lnmp.nuoyis.net/config/nginx.conf.full.template.txt
curl -k -L -o /${prefixpath}server/web/nginx/conf/nginx.conf.succinct.template https://lnmp.nuoyis.net/config/nginx.conf.succinct.template.txt
curl -k -L -o /${prefixpath}server/web/nginx/conf/default.conf.init https://lnmp.nuoyis.net/config/default.conf.txt

# 替换为实际路径
sed -i "s#/web#/${prefixpath}server/web#g"                                                                 /${prefixpath}server/web/nginx/server/conf/nginx.conf
sed -i "s#/web/nginx#/${prefixpath}server/web/nginx#g"                                                     /${prefixpath}server/web/nginx/conf/default.conf.init
sed -i "s#/web#/${prefixpath}server/web#g"                                                                 /${prefixpath}server/web/php/etc/php-fpm.d/fpm.conf
sed -i "s#/web#/${prefixpath}server/web#g"                                                                 /${prefixpath}server/web/php/etc/php.ini
sed -i -e "s#/web/nginx#/${prefixpath}server/web/nginx#g" -e "s#/web/logs#/${prefixpath}server/web/logs#g" /${prefixpath}server/web/nginx/conf/nginx.conf.full.template
sed -i -e "s#/web/nginx#/${prefixpath}server/web/nginx#g" -e "s#/web/logs#/${prefixpath}server/web/logs#g" /${prefixpath}server/web/nginx/conf/nginx.conf.succinct.template

ln -s /${prefixpath}server/web/nginx/server/sbin/nginx /usr/local/bin/
cat > /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=Nginx HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=nginx
ExecReload=nginx -s reload
ExecStop=nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
	manager::systemctl start nginx
}

install::lnmp::docker(){
	if [ -z $options_mariadb_value ];then
		read -e -p "请输入mariadb root密码:" options_mariadb_value
    fi
	touch /${prefixpath}server/docker-yaml/docker-lnmp.yaml
	touch /${prefixpath}server/web/mariadb/config/my.cnf
	manager::nuoyis::download scriptresources/config/docker-compose/docker-lnmp.yaml.txt /${prefixpath}server/docker-yaml/docker-lnmp.yaml
	sed -i -e "s#\$options_mariadb_value#${options_mariadb_value}#g" \
	       -e "s#\/server#${prefixpath}server#g" /${prefixpath}server/docker-yaml/docker-lnmp.yaml
	cat > /${prefixpath}server/web/mariadb/config/my.cnf << EOF
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_format=ROW
slave_skip_errors=1062
EOF
    docker rm -f lnmp-np
	docker rm -f lnmp-mariadb
    docker-compose -f /${prefixpath}server/docker-yaml/docker-lnmp.yaml up -d
}

install::lnmp(){
	echo "安装lnmp"
	sleep 30
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
		aboutserver=`systemctl is-active firewalld`
		if [ $aboutserver == "inactive" ];then
			manager::systemctl start firewalld
		fi
		firewall-cmd --set-default-zone=public
		firewall-cmd --zone=public --add-service=http --permanent
		firewall-cmd --zone=public --add-port=3306/tcp --permanent
		firewall-cmd --reload
	else
		ufw enable
		ufw allow http
		ufw allow 3306/tcp
	fi
	id -u web >/dev/null 2>&1
	if [ $? -eq 1 ];then
		useradd -u 2233 -m -s /sbin/nologin web
		groupadd web-share
		usermod -aG web-share nginx
		usermod -aG web-share web
	fi
	chown -R root:web-share /${prefixpath}server/web/nginx/
	chmod -R 2775 /${prefixpath}server/web/nginx/
	mkdir -p /${prefixpath}server/web/{logs/nginx,nginx/{server/conf/ssl,conf,webside/default,ssl},mariadb/{init,server,import,config}}
	touch /${prefixpath}server/web/logs/nginx/{error.log,nginx.pid}
	if [ $options_lnmp_value == "yum" ];then
		install::lnmp::quick
	elif [ $options_lnmp_value == "gcc" ];then
		install::lnmp::gcc
	elif [ $options_lnmp_value == "docker" ];then
		install::lnmp::docker
	fi
}
conf::reposource::yum::repowrite() {
    local id=$1
    local path=$2
    cat >> /etc/yum.repos.d/toolbox.repo <<EOF
[$id]
name=${prefixmirror}${system_name} - ${id} - ${mirror_url}
baseurl=https://${mirror_url}/${osname}/${osversion}/${path}
gpgcheck=${gpgcheck}
${gpgkey:+gpgkey=${gpgkey}}
enabled=1
countme=1
metadata_expire=6h
priority=1

EOF
}

conf::reposource::yum(){
	for repo in "${repos[@]}"; do
        set -- $repo
        conf::reposource::yum::repowrite "$1" "$2"
    done

	sed -i '/^skip_broken/d; /^max_parallel_downloads/d; /^metadata_expire/d' $PMpath
	echo "skip_broken=True" >> $PMpath
	echo "max_parallel_downloads=20" >> $PMpath
	echo "metadata_expire=15m" >> $PMpath
}

conf::reposource::yum_additional_source(){
	echo "正在配置附加源"
	if [ $system_name != "openEuler" ];then
		if [ $system_version -ge 8 ]; then
			manager::repositories install https://mirrors.aliyun.com/epel/epel-release-latest-$system_version.noarch.rpm
			if [ $system_version -lt 10 ]; then
				rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
			else
				rpm --import https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org
			fi
			rm -rf /etc/yum.repos.d/epel-cisco-openh264.repo
			sed -e 's!^metalink=!#metalink=!g' \
				-e 's!^#baseurl=!baseurl=!g' \
				-e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.aliyun.com/epel!g' \
				-e 's!https\?://download\.example/pub/epel!https://mirrors.aliyun.com/epel!g' \
				-i /etc/yum.repos.d/epel{,*}.repo
			manager::repositories install https://mirrors.aliyun.com/remi/enterprise/remi-release-$system_version.rpm
			sed -e 's|^mirrorlist=|#mirrorlist=|g' \
				-e 's|^#baseurl=http://rpms.remirepo.net|baseurl=http://mirrors.tuna.tsinghua.edu.cn/remi|g' \
				-e 's|^baseurl=http://rpms.remirepo.net|baseurl=http://mirrors.tuna.tsinghua.edu.cn/remi|g' \
				-i  /etc/yum.repos.d/remi*.repo
			manager::repositories install https://www.elrepo.org/elrepo-release-$system_version.el$system_version.elrepo.noarch.rpm
			sed -e 's/http:\/\/elrepo.org\/linux/https:\/\/mirrors.aliyun.com\/elrepo/g' \
				-e 's/mirrorlist=/#mirrorlist=/g' \
				-i /etc/yum.repos.d/elrepo.repo
		else
			manager::repositories install https://${mirror_url}/remi/enterprise/remi-release-$system_version.rpm

			sed -e 's|^mirrorlist=|#mirrorlist=|g' \
				-e 's|^#baseurl=http://rpms.remirepo.net|baseurl=http://mirrors.tuna.tsinghua.edu.cn/remi|g' \
				-e 's|^baseurl=http://rpms.remirepo.net|baseurl=http://mirrors.tuna.tsinghua.edu.cn/remi|g' \
				-i  /etc/yum.repos.d/remi*.repo
			sed -e 's!^metalink=!#metalink=!g' \
				-e 's!^#baseurl=!baseurl=!g' \
				-e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.aliyun.com/epel!g' \
				-e 's!https\?://download\.example/pub/epel!https://mirrors.aliyun.com/epel!g' \
				-i /etc/yum.repos.d/epel{,*}.repo
		fi
	fi
}

conf::reposource::deb(){
	echo "" > /etc/apt/sources.list
	rm -rf /etc/apt/sources.list.d/*
	if [ $system_name == "Debian" ]; then
		cat > /etc/apt/sources.list.d/mirror.list << EOF
deb https://${mirror_url}/debian/ $(lsb_release -sc) main contrib non-free non-free-firmware
deb https://${mirror_url}/debian/ $(lsb_release -sc)-updates main contrib non-free non-free-firmware
deb https://${mirror_url}/debian/ $(lsb_release -sc)-backports main contrib non-free non-free-firmware
deb https://${mirror_url}/debian-security $(lsb_release -sc)-security main contrib non-free non-free-firmware
EOF
       	wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
		manager::repositories install apt-transport-https
		echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    else
		cat > /etc/apt/sources.list.d/mirror.list << EOF
deb https://${mirror_url}/ubuntu/ $(lsb_release -sc) main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ $(lsb_release -sc)-updates main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ $(lsb_release -sc)-backports main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ $(lsb_release -sc)-security main restricted universe multiverse
EOF
      	yes | add-apt-repository ppa:ondrej/php
	fi
}

conf::reposource::redhat(){
	echo "正在对RHEL 9系列系统进行openssl系统特调"
	manager::repositories remove subscription-manager-gnome     
	manager::repositories remove subscription-manager-firstboot     
	manager::repositories remove subscription-manager
	rpm -e --nodeps openssl-fips-provider
	rpm -e --nodeps redhat-logos
	rpm -e --nodeps redhat-release
	rpm --import https://shell.nuoyis.net/scriptresources/download/RPM-GPG-KEY-Rocky-9
	manager::nuoyis::download scriptresources/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
	manager::nuoyis::download scriptresources/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
	manager::nuoyis::download scriptresources/download/rocky-repos-9.5-1.2.el9.noarch.rpm
	manager::nuoyis::download scriptresources/download/rocky-release-9.5-1.2.el9.noarch.rpm
	sudo rm -rf /usr/share/redhat-release
	rpm -ivh --force --nodeps openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
	rpm -ivh --force --nodeps openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
	rpm -ivh --force --nodeps rocky-repos-9.5-1.2.el9.noarch.rpm
	rpm -ivh --force --nodeps rocky-release-9.5-1.2.el9.noarch.rpm
	rm -rf openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
	rm -rf openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
	rm -rf rocky-repos-9.5-1.2.el9.noarch.rpm
	rm -rf rocky-release-9.5-1.2.el9.noarch.rpm
	rm -rf /etc/yum.repos.d/rocky*.repo
	# 可视化处理
	# sudo dnf groupinstall "Server with GUI"
	# manager::repositories install https://shell.nuoyis.net/scriptresources/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm https://shell.nuoyis.net/scriptresources/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
	if [ -d /sys/firmware/efi ] && [ -d /boot/efi/EFI/redhat ];then
		echo "你的Boot分区为EFI，正在进行特别优化"
		mv /boot/efi/EFI/redhat/ /boot/efi/EFI/rocky
		bootid=$(efibootmgr | grep BootCurrent | egrep -o "[0-9]+")
		efi_uuid=$(efibootmgr -v | grep -A 1 "Boot"$bootid  | egrep -o '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
		efi_id=$(lsblk -o NAME,UUID,PARTUUID | grep $efi_uuid |  egrep -o '[n|v][[:alnum:]]+')
		diskname=$(echo $efi_id | sed 's/[0-9]*$//; s/p[0-9]*$//')
		efi_disknumber=$(echo $efi_id | egrep -o '[0-9]$')
		sudo efibootmgr -b $bootid -B
		sudo efibootmgr --create --disk "/dev/$diskname" --part $efi_disknumber --label "nuoyis-redhat Linux" --loader "\EFI\rocky\shimx64.efi"
		sudo grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg
	fi
}

conf::reposource(){
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
		# 判断源站
		if [ "$options_yum_install" == "other" ]; then
			manager::download https://linuxmirrors.cn/main.sh
			source main.sh
			echo "yes"
		else
			echo "正在移动源到/etc/yum.repos.d/bak"
			if [ ! -d /etc/yum.repos.d/bak ];then
				mkdir -p /etc/yum.repos.d/bak
			fi
			mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null
			mv -f /etc/yum.repos.d/*.repo.* /etc/yum.repos.d/bak/ 2>/dev/null
			manager::repositories installcheck epel
			if [ $? -eq 0 ];then
				manager::repositories remove epel-release epel-next-release
			fi
	
			manager::repositories installcheck remi
			if [ $? -eq 0 ];then
				manager::repositories remove remi-release.remi.noarch
			fi
	
			manager::repositories installcheck elrepo
			if [ $? -eq 0 ];then
				manager::repositories remove elrepo-release.noarch
			fi

			echo "正在配置源"
			# yum系统判断
			case "$system_name" in
				"openEuler")
					conf::reposource::yum
				;;
				"Rocky")
					echo "正在检查是否存在冲突/模块缺失"
					echo "正在检查模块依赖问题..."
					options_install_check_modules_bug=$($PM check 2>&1)
					if [ -z "$options_install_check_modules_bug" ]; then
						echo "没有发现模块依赖问题,继续下一步"
					else
						echo "发现模块依赖问题："
						# 提取并禁用冲突的模块
						echo "正在禁用冲突模块"
						while read -r module; do
							# 提取模块名和版本
							module_name=$(echo $module | grep -oP '(?<=module )[^:]+:[^ ]+' | sed 's/:[^:]*$//')
							if [ -n "$module_name" ]; then
								echo "禁用模块: $module_name"
								sudo yum module disable "$module_name" -y
								if [ $? -eq 0 ]; then
									echo "模块 $module_name 禁用成功"
								else
									echo "模块 $module_name 禁用失败"
								fi
							fi
						done <<< "$options_install_check_modules_bug"
						echo "模块依赖修复和冲突模块禁用完成。"
					fi
					conf::reposource::yum
				;;
				"CentOS")
					conf::reposource::yum
				;;
				"Red")
					conf::reposource::redhat
				;;
			esac			
		fi
	elif [ "$PM" = "apt" ];then
			conf::reposource::deb
	fi
	
	if [[ $installlock -eq 0 ]]; then
		echo "正在安装时间同步软件，以及检查时间并同步，防止yum报错"
		if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
	    	yum --setopt=sslverify=0 -y install chrony cronie
		else
	    	apt-get -o Acquire::Check-Valid-Until=false -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false update -y
	    	apt-get -o Acquire::Check-Valid-Until=false -o Acquire::https::Verify-Peer=false -o Acquire::https::Verify-Host=false install -y chrony
		fi
	fi
	cat > "$chronyconf" << EOF
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp.tencent.com iburst
server ntp1.tencent.com iburst
server ntp2.tencent.com iburst
server ntp.ntsc.ac.cn iburst
server pool.ntp.org iburst
logdir /var/log/chrony
driftfile /var/lib/chrony/chrony.drift
makestep 1.0 3
EOF
	if [[ $installlock -eq 0 ]]; then
		if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
			systemctl enable --now chronyd 2>/dev/null
			systemctl restart chronyd 2>/dev/null
			crontab -l 2>/dev/null | sed '/chronyd/d' | crontab -
			(crontab -l 2>/dev/null; echo "0 1 * * * systemctl restart chronyd") | crontab -
		else
			systemctl enable --now chrony 2>/dev/null
			systemctl restart chrony 2>/dev/null
			crontab -l 2>/dev/null | sed '/chrony/d' | crontab -
			(crontab -l 2>/dev/null; echo "0 1 * * * systemctl restart chrony") | crontab -
		fi

		echo "等待 10 秒让时间生效..."
		sleep 10
	fi
	# 配置附加源(重新配置)
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
		conf::reposource::yum_additional_source
	fi

	if [[ $mirror_update -eq 1 ]];then
		echo "正在更新源"
		rm -rf /etc/yum.repods.d/*.rpmsave
		if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
			manager::repositories clean
			manager::repositories makecache
		fi
		manager::repositories update
	fi
}

install::kernel(){
echo "内核更最新"
if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
	if [ $system_version -gt 8 ];then
		manager::repositories installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml.x86_64
		manager::repositories remove kernel-tools-libs.x86_64 kernel-tools.x86_64
		manager::repositories installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml-tools.x86_64
	elif [ $system_version -eq 7 ];then
		manager::nuoyis::download scriptresources/download/kernel/centos/7/kernel-lt-devel-5.4.226-1.el7.elrepo.x86_64.rpm
		manager::nuoyis::download scriptresources/download/kernel/centos/7/kernel-lt-headers-5.4.226-1.el7.elrepo.x86_64.rpm
		manager::nuoyis::download scriptresources/download/kernel/centos/7/kernel-lt-5.4.226-1.el7.elrepo.x86_64.rpm
    	rpm -ivh kernel-lt-devel-5.4.226-1.el7.elrepo.x86_64.rpm
    	rpm -ivh kernel-lt-5.4.226-1.el7.elrepo.x86_64.rpm
    	yum remove kernel-headers -y
    	rpm -ivh kernel-lt-headers-5.4.226-1.el7.elrepo.x86_64.rpm
    	grub2-set-default 0
    	grub2-mkconfig -o /boot/grub2/grub.cfg
	fi
	cat > /${prefixpath}server/shell/kernel-update.sh << EOF
#!/bin/bash
yum clean all;
yum upgrade -y;
yes | dnf --disablerepo=\* --enablerepo=elrepo-kernel update kernel-ml*;
yes | dnf remove --oldinstallonly --setopt installonly_limit=2 kernel;
# 0 0 * * 1 bash /${prefixpath}server/shell/kernel-update.sh > /${prefixpath}server/logs/update.log 2>&1;
EOF
(crontab -l 2>/dev/null; echo "0 0 * * 1 bash /${prefixpath}server/shell/kernel-update.sh > /${prefixpath}server/logs/update.log 2>&1;") | crontab -
else
	# https://zichen.zone/archives/debian_linux_kernel_update.html
	manager::repositories install linux-image-amd64 linux-headers-amd64
fi

}

install::systemupdate(){
echo "正在检查版本是否支持"
if [ $PM == "yum" ] && [ $system_name != "openEuler" ];then
	if [ $system_version -lt 9 ];then
		if [ $system_version -eq 8 ] && [ $system_name == "Rocky" ];then
			read -e -p "是否进行版本更新" options_update
			if [ $options_update == "n" ];then
        		echo "请重新执行脚本继续完成初始化"
       	 		exit 0
			else
				echo -e "警告！！！"
				echo -e "请保证升级9之前，请先检查是否有重要备份数据，不过本脚本作者精心提醒:生产环境就不要执行脚本了，如果是云厂商只有8版本，且是空白面板可以执行"
				echo -e "重启后需要重新执行该命令操作下一步，如果同意更新请输入y,更新出现任何问题与作者无关"
				read -e -p "是否进行版本更新，反之退出脚本(y/n):" options_update_again
				if [ $options_update_again == "n" ];then
        			echo "请重新执行脚本继续完成初始化"
       	 			exit 0
				else
					options_source_installer
					# https://www.rockylinux.cn/notes/strong-rocky-linux-8-sheng-ji-zhi-rocky-linux-9-strong.html
					# 安装 epel 源
					manager::repositories epel-release
					
					# 更新系统至最新版
					manager::repositories update

					# 安装 rpmconf 和 yum-utils
					manager::repositories rpmconf yum-utils
					
					# 执行 rpmconf，如果出现提示信息，请输入 Y 和回车继续，如果没提示继续。
					yes | rpmconf -a
					
					# 安装 rocky-release 包
					rpm -e --nodeps `rpm -qa|grep rocky-release`
					rpm -e --nodeps `rpm -qa|grep rocky-gpg-keys`
					rpm -e --nodeps `rpm -qa|grep rocky-repos`
					rpm -ivh --nodeps --force https://mirrors.aliyun.com/rockylinux/9/BaseOS/x86_64/os/Packages/r/rocky-gpg-keys-9.4-1.7.el9.noarch.rpm
					rpm -ivh --nodeps --force https://mirrors.aliyun.com/rockylinux/9/BaseOS/x86_64/os/Packages/r/rocky-release-9.4-1.7.el9.noarch.rpm
					rpm -ivh --nodeps --force https://mirrors.aliyun.com/rockylinux/9/BaseOS/x86_64/os/Packages/r/rocky-repos-9.4-1.7.el9.noarch.rpm
					dnf clean all
					
					# 升级 Rocky Linux 9
					rpm -e --nodeps rocky-logos-86.2-1.el8.x86_64
					dnf clean all
					yes | dnf --releasever=9 --allowerasing --setopt=deltarpm=false distro-sync
										
					# 重建 rpm 数据库，出现警告忽略。
					yes | rpm --rebuilddb
					
					# 安装新内核
					manager::repositories install kernel
					manager::repositories install kernel-core
					manager::repositories install shim
					
					# 安装基础环境
					manager::repositories installfull group minimal-environment
					
					# 安装 rpmconf 和 yum-utils
					manager::repositories install rpmconf yum-utils
					
					# 执行 rpmconf，根据提示一直输入 Y 和回车即可
					rpmconf -a
					
					# 设置采用最新内核引导
					export grubcfg=`find /boot/ -name rocky`
					grub2-mkconfig -o $grubcfg/grub.cfg
					
					# 更新系统
					manager::repositories update
					
					# 重启系统
					reboot
				fi
			fi
		elif [ $system_version -eq 7 ] && [ $system_name == "Centos" ];then
			echo -e "警告！！！"
			echo -e "请保证升级8之前，请先检查是否有重要备份数据，不过本脚本作者精心提醒:生产环境就不要执行脚本了，如果是不重要数据或者新安装的可以执行"
			echo -e "重启后需要重新执行该命令操作下一步，如果同意更新请输入y,更新出现任何问题与作者无关"
			read -e -p "是否进行版本更新，反之退出脚本(y/n):" options_update_again
			if [ $options_update_again == "n" ];then
        		echo "请重新执行脚本继续完成初始化"
       	 		exit 0
			else
				echo "等待更新"
			fi
		elif [ $system_version -eq 8 ] && [ $system_name == "Centos" ];then
			echo -e "警告！！！"
			echo -e "请保证升级8之前，请先检查是否有重要备份数据，不过本脚本作者精心提醒:生产环境就不要执行脚本了，如果是不重要数据或者新安装的可以执行"
			echo -e "重启后需要重新执行该命令操作下一步，如果同意更新请输入y,更新出现任何问题与作者无关"
			read -e -p "是否进行版本更新，反之退出脚本(y/n):" options_update_again
			if [ $options_update_again == "n" ];then
        		echo "请重新执行脚本继续完成初始化"
       	 		exit 0
			else
				echo "等待更新"
			fi
		else
			echo "不支持的系统，请更换后再试"
			exit 1
		fi
	fi
fi
}

install::main(){
	echo "核心函数检查和安装"
	echo "检测hostname是否设置"
	HOSTNAME_CHECK=$(cat /etc/hostname)
	if [ -z $HOSTNAME_CHECK ];then
		echo "当前主机名hostname为空，设置默认hostname"
		hostnamectl set-hostname ${prefix}init-shell
	fi

	echo "创建临时服务部署文件夹server/install"
	mkdir -p /server/install

	echo "创建${prefix}服务核心文件夹"
	mkdir -p /${prefixpath}server/{logs,shell}

	echo "安装核心软件包"
	if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ];then
		manager::repositories install jq sshpass dnf-plugins-core python3 python3-pip bash-completion vim git wget net-tools tuned dos2unix gcc gcc-c++ make unzip perl perl-IPC-Cmd perl-Test-Simple pciutils tar chrony
	else
		export DEBIAN_FRONTEND=noninteractive
		manager::repositories install jq sshpass python3 python3-pip bash-completion vim git wget net-tools tuned dos2unix gcc g++ make unzip perl libipc-cmd-perl libtest-simple-perl pciutils tar ca-certificates curl gnupg ufw chrony
	fi
}

conf::tuning(){
	echo "系统调优"
	manager::systemctl start tuned.service
	tuned-adm profile `tuned-adm recommend`
	for nsysctl in net.core.default_qdisc net.ipv4.tcp_congestion_control kernel.sysrq net.ipv4.neigh.default.gc_stale_time net.ipv4.conf.all.rp_filter net.ipv4.conf.default.rp_filter net.ipv4.conf.default.arp_announce net.ipv4.conf.lo.arp_announce net.ipv4.conf.all.arp_announce net.ipv4.tcp_max_tw_buckets net.ipv4.tcp_syncookies net.ipv4.tcp_max_syn_backlog net.ipv4.tcp_synack_retries net.ipv4.tcp_slow_start_after_idle
	do
	    sed -i "/^${nsysctl}/d" /etc/sysctl.conf
	done
	cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
kernel.sysrq = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_slow_start_after_idle = 0
EOF
	sysctl -p
}

show::updateurl(){
	if [ -z $nuoyis_install_mirrors ];then
		nuoyis_install_mirrors=1
	fi
	if [ $nuoyis_install_mirrors -eq 1 ];then
		updateurl="https://gitee.com/nuoyis/shell/raw/main/nuoyis-linux-toolbox.sh"
	else
		# github加速器列表
		github_mirrors=(
	  		"https://ghfast.top"
	  		"https://gh-proxy.com"
	  		"https://raw.githubusercontent.com"
		)

		for github_mirror in "${github_mirrors[@]}"; do
			test_url="${github_mirror}/https://raw.githubusercontent.com/nuoyis/shell/refs/heads/main/nuoyis-linux-toolbox.sh"
			curl -sSk -o /dev/null $test_url
			if [ $? -eq 0 ];then
	    		updateurl=$test_url
				break
	    	fi
		done
	fi
}

show::version(){
	show::updateurl
	if [ -z $1 ];then
		shell_localhost="/usr/bin/nuoyis-toolbox"
	else
		shell_localhost="$1"
	fi
	REMOTE_HASH=$(curl -k -H "Cache-Control: no-cache" -H "Pragma: no-cache" -sSkL "$updateurl" | sha256sum | awk '{print $1}')
	LOCAL_HASH=$(sha256sum "$shell_localhost" | awk '{print $1}')
}

update::version(){
	show::version
	if [ "$REMOTE_HASH" != "$LOCAL_HASH" ]; then
    	echo "shell will update"
		curl -sSkL -o /tmp/nuoyis-toolbox $updateurl
		show::version /tmp/nuoyis-toolbox
		if [ "$REMOTE_HASH" != "$LOCAL_HASH" ]; then
			rm -rf /tmp/nuoyis-toolbox
			echo "shell update have error"
		else
			rm -rf /usr/bin/nuoyis-toolbox
			mv /tmp/nuoyis-toolbox /usr/bin/nuoyis-toolbox
			chmod +x /usr/bin/nuoyis-toolbox
			echo "shell is updated"
		fi
	else
    	echo "shell is already up to date"
	fi
}

toolbox::install(){
	echo "检查脚本是否存在/usr/bin/nuoyis-toolbox中"
	if [ ! -f /usr/bin/nuoyis-toolbox ]; then
		echo "脚本不存在存在于环境变量，正在下载并创建到/usr/bin/nuoyis-toolbox"
		if [ -z "$2" ];then
			read -p "请输入下载渠道，1是gitee加速版，2是github版" nuoyis_install_mirrors
		else
			nuoyis_install_mirrors=$2
		fi
		while [[ ! "$nuoyis_install_mirrors" =~ ^[1-2]$ ]]; do
			echo "无效输入，请输入 1 2作为有效选项。"
			read -p "请输入下载渠道，1是gitee加速版，2是github版" nuoyis_install_mirrors
		done
		show::updateurl
		curl -sSkL -o /usr/bin/nuoyis-toolbox $updateurl
		chmod +x /usr/bin/nuoyis-toolbox
		echo "开启crontab 自动更新检测，如果介意请使用 crontab -l 2>/dev/null | sed '/nuoyis-toolbox/d' | crontab - 删除该行"
		crontab -l 2>/dev/null | sed '/nuoyis-toolbox/d' | crontab -
		(crontab -l 2>/dev/null; echo "0 * * * * /usr/bin/nuoyis-toolbox -update $nuoyis_install_mirrors;") | crontab -
	else
		echo "已通过各种方式部署于环境变量中，无需重复安装"
	fi
	exit 0
}

# ---------- k8s 函数区域 ----------
k8s_MIN_KERNEL_VERSION="4.15"
k8s::compare_versions() {
    local ver1=$(echo "$1" | sed 's/^v//' | cut -d'-' -f1 | cut -d'+' -f1)
    local ver2=$(echo "$2" | sed 's/^v//' | cut -d'-' -f1 | cut -d'+' -f1)
    local version1=$(echo "$ver1" | awk -F. '{printf("%03d%03d%03d\n", $1, $2, $3)}')
    local version2=$(echo "$ver2" | awk -F. '{printf("%03d%03d%03d\n", $1, $2, $3)}')
    if [ "$version1" -lt "$version2" ]; then echo -1
    elif [ "$version1" -gt "$version2" ]; then echo 1
    else echo 0; fi
}

k8s::version_check() {
    local input="$1"
    input="${input#v}"; input="${input#V}"
    input="${input%%-*}"; input="${input%%+*}"
    local major minor
    IFS='.' read -r major minor _ <<< "$input"
    [[ -z "$minor" ]] && minor=0
    major=$(echo "$major" | sed 's/[^0-9].*//')
    minor=$(echo "$minor" | sed 's/[^0-9].*//')
    [[ -z "$major" ]] && major=0
    [[ -z "$minor" ]] && minor=0
    local ref_major=1 ref_minor=24
    if (( major > ref_major )) || (( major == ref_major && minor >= ref_minor )); then echo "1"
    else echo "0"; fi
}

k8s::install_kubernetes(){
    touch /etc/yum.repos.d/toolbox-kubernetes.repo
    if [ $(k8s::version_check $options_k8s_version) -eq 0 ]; then
        cat > /etc/yum.repos.d/toolbox-kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF
    else
        cat > /etc/yum.repos.d/toolbox-kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v$(echo "$options_k8s_version" | cut -d'.' -f1,2)/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v$(echo "$options_k8s_version" | cut -d'.' -f1,2)/rpm/repodata/repomd.xml.key
EOF
    fi
    systemctl enable --now docker
    systemctl enable --now containerd
    cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://docker.m.daocloud.io",
    "https://docker66ccff.lovablewyh.eu.org"
  ],
  "bip": "192.168.100.1/24",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    containerd config default > /etc/containerd/config.toml
    sed -i -e "s|registry.k8s.io/pause|registry.aliyuncs.com/google_containers/pause|g" \
           -e "s|SystemdCgroup = false|SystemdCgroup = true|g" /etc/containerd/config.toml
    systemctl daemon-reload
    systemctl restart docker
    systemctl restart containerd
    yum install -y kubelet-$options_k8s_version kubeadm-$options_k8s_version kubectl-$options_k8s_version
    systemctl enable --now kubelet
    cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
}

k8s::install_kernel(){
    wget https://openlist.nuoyis.net/d/blog/kubernetes/kernel-lt-devel-5.4.226-1.el7.elrepo.x86_64.rpm
    wget https://openlist.nuoyis.net/d/blog/kubernetes/kernel-lt-headers-5.4.226-1.el7.elrepo.x86_64.rpm
    wget https://openlist.nuoyis.net/d/blog/kubernetes/kernel-lt-5.4.226-1.el7.elrepo.x86_64.rpm
    rpm -ivh kernel-lt-devel-5.4.226-1.el7.elrepo.x86_64.rpm
    rpm -ivh kernel-lt-5.4.226-1.el7.elrepo.x86_64.rpm
    yum remove kernel-headers -y
    rpm -ivh kernel-lt-headers-5.4.226-1.el7.elrepo.x86_64.rpm
    grub2-set-default 0
    grub2-mkconfig -o /boot/grub2/grub.cfg
    reboot
}

k8s::join(){
    if [ $options_k8s_device == "master" ];then
        if ! $k8s_is_first_master; then
            source /kubernetes-master-join.sh
        fi
        rm -rf $HOME/.kube
        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
        sed -i '/KUBECONFIG/d' /etc/bashrc
        export KUBECONFIG=/etc/kubernetes/admin.conf
        echo "KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/bashrc
        if $k8s_is_first_master; then
            if [ "${#options_k8s_mastersip[@]}" -gt 1 ]; then
                systemctl enable --now nginx
            fi
        fi
    else
        source /kubernetes-node-join.sh
    fi
}

k8s::docker_init(){
    kubeadm init --kubernetes-version=$options_k8s_version --apiserver-advertise-address=${options_k8s_mastersip[0]} --image-repository registry.aliyuncs.com/google_containers --pod-network-cidr=10.223.0.0/16 --ignore-preflight-errors=SystemVerification --ignore-preflight-errors=Mem
}

k8s::containerd_init(){
    if [ $(uname -m) != "x86_64" ];then
        touch /toolbox-pi-containerkill.sh
        cat > /toolbox-pi-containerkill.sh << "EOF"
mkdir -p /etc/systemd/system/kubelet.service.d/
cat > /etc/systemd/system/kubelet.service.d/nuoyis-init.conf << 'pi_EOF'
[Unit]
After=containerd.service
Requires=containerd.service

[Service]
ExecStartPre=/bin/bash -c '/usr/bin/crictl rm -f $(crictl ps -a -q)'
ExecStartPre=rm -rf /run/containerd/io.containerd.runtime.v2.task/k8s.io/*
ExecStartPre=rm -rf /run/containerd/io.containerd.metadata.v1.bolt/meta.db
pi_EOF
EOF
    fi
    kubeadm config print init-defaults > kubeadm.yaml
    sed -i -e "s|  criSocket: unix:///var/run/containerd/containerd.sock|  criSocket: unix:///run/containerd/containerd.sock|g" \
           -e "s|imageRepository: registry.k8s.io|imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers|g" \
           -e "/serviceSubnet: 10.96.0.0\\/12/i \\  podSubnet: 10.223.0.0/16" kubeadm.yaml
    if [ "${#options_k8s_mastersip[@]}" -eq 1 ]; then
        sed -i -e "s|  advertiseAddress: 1.2.3.4|  advertiseAddress: ${options_k8s_mastersip[0]}|g" \
               -e "s|  name: node|  name: kubernetes-master1|g" kubeadm.yaml
    else
        sed -i -e "\|^localAPIEndpoint:|,\|^  bindPort:|s|^|# |" \
               -e "\|^[[:space:]]*name: node|s|^|# |" \
               -e "s|imageRepository: registry.k8s.io|imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers|g" \
               -e "\|^kubernetesVersion:|a\controlPlaneEndpoint: $k8s_keepalived" kubeadm.yaml
        cat > /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;
events {
    worker_connections 1024;
}
stream {
    log_format  main  '\$remote_addr \$upstream_addr - [\$time_local] \$status \$upstream_bytes_sent';
    access_log  /var/log/nginx/k8s-access.log  main;
    upstream k8s-apiserver {
EOF
        for ip in "${options_k8s_mastersip[@]}"; do
            echo "    server $ip:6443 weight=5 max_fails=3 fail_timeout=30s;" >> /etc/nginx/nginx.conf
        done
        cat >> /etc/nginx/nginx.conf << EOF
    }
    server {
       listen $(echo $k8s_keepalived | cut -d':' -f2- | xargs);
       proxy_pass k8s-apiserver;
    }
}
http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                       '\$status \$body_bytes_sent "\$http_referer" '
                       '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    server {
        listen       80 default_server;
        server_name  _;
        location / {
        }
    }
}
EOF
        systemctl enable --now nginx
        cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
   notification_email {
     acassen@firewall.loc
     failover@firewall.loc
     sysadmin@firewall.loc
   }
   notification_email_from Alexandre.Cassen@firewall.loc
   smtp_server 127.0.0.1
   smtp_connect_timeout 30
   router_id NGINX_MASTER
}
vrrp_instance VI_1 {
    state MASTER
    interface $k8s_networkname
    virtual_router_id 1
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass k8svip
    }
    virtual_ipaddress {
        $(echo $k8s_keepalived | cut -d':' -f1 | xargs)/$options_k8s_mask
    }
}
EOF
        systemctl enable --now keepalived
    fi
    cat >> kubeadm.yaml << 'EOF'
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
    kubeadm init --config=kubeadm.yaml --ignore-preflight-errors=SystemVerification --ignore-preflight-errors=Mem
    for masterip in "${options_k8s_mastersip[@]:1}"; do
        sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$masterip "mkdir -p /etc/kubernetes/pki/etcd && mkdir -p /root/.kube/"
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/ca.crt root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/ca.key root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/sa.key root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/sa.pub root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/front-proxy-ca.crt root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/front-proxy-ca.key root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/etcd/ca.crt root@$masterip:/etc/kubernetes/pki/etcd/
        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/etcd/ca.key root@$masterip:/etc/kubernetes/pki/etcd/
    done
}

k8s::config(){
    if [[ "$options_k8s_device" == "master" && "$k8s_is_first_master" == true ]]; then
        kubeadm reset -f
        if [ $(k8s::version_check $options_k8s_version) -eq 0 ]; then
            k8s::docker_init
        else
            k8s::containerd_init
        fi
        k8s::join
        sleep 5
        KUBE_MINOR=$(echo "$options_k8s_version" | awk -F. '{print $2}')
        if [ "$KUBE_MINOR" -lt 21 ]; then
            echo "($options_k8s_version<1.21)，install calico v3.19"
            wget -O calico.yaml "https://docs.projectcalico.org/archive/v3.19/manifests/calico.yaml"
            sed -i 's#docker.io/##g' calico.yaml
        else
            if [ $KUBE_MINOR -lt 31 ]; then
                echo "(1.31>=$options_k8s_version>=1.21)，install calico v3.24"
                calicoversion="https://docs.projectcalico.org/archive/v3.24/manifests/calico.yaml"
            else
                echo "($options_k8s_version>=1.31)，install calico latest"
                calicoversion="https://ghfast.top/https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml"
            fi
            wget -O calico.yaml $calicoversion
            sed -i -e '/# - name: CALICO_IPV4POOL_CIDR/{
N
N
c\
            - name: CALICO_IPV4POOL_CIDR\
              value: "10.223.0.0/12"\
            - name: IP_AUTODETECTION_METHOD\
              value: "interface='"$k8s_networkname"'"
}' \
               -e 's|docker.io|docker.m.daocloud.io|g' \
               -e 's|quay.io|quay.dockerproxy.net|g' calico.yaml
        fi
        kubectl apply -f calico.yaml
        if [[ -n "${options_k8s_nodesip[*]}" ]]; then
            k8s::otherserver
        fi
    else
        k8s::join
    fi
    sed -i '/kubectl completion bash/d' /etc/bashrc
    echo "source <(kubectl completion bash)" >> /etc/bashrc
    bash /etc/bashrc
}

k8s::otherserver(){
    join_cmd=$(kubeadm token create --print-join-command | grep "kubeadm")
    echo "$join_cmd" > kubernetes-node-join.sh
    echo "$join_cmd --control-plane --ignore-preflight-errors=SystemVerification" > kubernetes-master-join.sh
    all_ips=("${options_k8s_mastersip[@]:1}" "${options_k8s_nodesip[@]}")
    nodenumber=1
    vipid=90
    for nodeip in "${all_ips[@]}"; do
        is_master=false
        for m_ip in "${options_k8s_mastersip[@]}"; do
            if [[ "$nodeip" == "$m_ip" ]]; then is_master=true; break; fi
        done
        device_type=$($is_master && echo master || echo node)
        # scp join 脚本到远端
        if $is_master; then
            sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no kubernetes-master-join.sh root@$nodeip:/kubernetes-master-join.sh
        else
            sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no kubernetes-node-join.sh root@$nodeip:/kubernetes-node-join.sh
        fi
        kernel_version=$(sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no "root@$nodeip" "uname -r | cut -d- -f1")
        echo "current node $nodenumber IP: $nodeip kernel: $kernel_version"
        if [ $(k8s::version_check $options_k8s_version) -eq 1 ]; then
            if printf "%s\n%s\n" "$k8s_MIN_KERNEL_VERSION" "$kernel_version" | sort -V -C; then
                echo "kernel ok"
            else
                echo "kernel too old, upgrading and reboot"
            fi
        fi
        # 远端已安装 toolbox，直接用 k8s 参数调用
        sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$nodeip "nuoyis-toolbox -k8s --km $options_k8s_master --kn $options_k8s_node --kp $options_k8s_password --kd $device_type --kv $options_k8s_version"
        if $is_master; then
            sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no /etc/nginx/nginx.conf root@$nodeip:/etc/nginx/nginx.conf
            sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$nodeip "cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
   notification_email {
     acassen@firewall.loc
     failover@firewall.loc
     sysadmin@firewall.loc
   }
   notification_email_from Alexandre.Cassen@firewall.loc
   smtp_server 127.0.0.1
   smtp_connect_timeout 30
   router_id NGINX_MASTER
}
vrrp_instance VI_1 {
    state BACKUP
    interface $k8s_networkname
    virtual_router_id 1
    priority $vipid
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass k8svip
    }
    virtual_ipaddress {
        $(echo $k8s_keepalived | cut -d':' -f1 | xargs)/$options_k8s_mask
    }
}
EOF"
            sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$nodeip "systemctl enable --now keepalived"
            vipid=$(($vipid-10))
        fi
        if [ $(k8s::version_check $options_k8s_version) -eq 1 ]; then
            if ! printf "%s\n%s\n" "$k8s_MIN_KERNEL_VERSION" "$kernel_version" | sort -V -C; then
                echo "wait $nodeip reboot..."
                sleep 70
                while ! ping -c 1 -W 1 "$nodeip" >/dev/null 2>&1; do
                    echo "wait $nodeip booting..."
                    sleep 3
                done
                echo "re-run install via toolbox"
                sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$nodeip "nuoyis-toolbox -k8s --km $options_k8s_master --kn $options_k8s_node --kp $options_k8s_password --kd $device_type --kv $options_k8s_version"
            fi
        fi
        nodenumber=$((nodenumber + 1))
    done
}

k8s::init(){
    systemctl disable --now firewalld
    setenforce 0
    swapoff -a
    yum install nginx keepalived nginx-mod-stream yum-utils device-mapper-persistent-data lvm2 wget bash* net-tools nfs-utils lrzsz gcc gcc-c++ make cmake openssl-devel curl curl-devel unzip sudo libaio-devel wget vim autoconf sshpass automake zlib-devel python-devel epel-release openssh-server chrony -y
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    sed -i '/^\s*server\s\+/d' /etc/chrony.conf
    sed -i '/kubernetes/d' /etc/hosts
    sed -i 's/.*swap.*/#&/' /etc/fstab
    echo "disable swap for k8s"
    systemctl mask swap.target
    sed -i '/^net.bridge.bridge-nf-call-ip6tables/d; /^net.bridge.bridge-nf-call-iptables/d; /^net.ipv4.ip_forward/d' /etc/sysctl.conf
    rm -rf /etc/sysctl.d/kubernetes.conf
    if [[ -n "${options_k8s_nodesip[*]}" ]]; then
        if [[ "$options_k8s_device" == "master" && "$k8s_is_first_master" == true ]]; then
            nodenumber=1
            for masterip in "${options_k8s_mastersip[@]}"; do
                sshpass -p $options_k8s_password ssh -o StrictHostKeyChecking=no root@$masterip "hostnamectl set-hostname kubernetes-master$nodenumber"
                nodenumber=$(($nodenumber+1))
            done
            nodenumber=1
            for nodeip in "${options_k8s_nodesip[@]}"; do
                sshpass -p $options_k8s_password ssh -o StrictHostKeyChecking=no root@$nodeip "hostnamectl set-hostname kubernetes-node$nodenumber"
                nodenumber=$(($nodenumber+1))
            done
        fi
        nodenumber=1
        for nodeip in "${options_k8s_nodesip[@]}"; do
            cat >> /etc/hosts << EOF
$nodeip kubernetes-node$nodenumber
EOF
            nodenumber=$(($nodenumber+1))
        done
    fi
    nodenumber=1
    for masterip in "${options_k8s_mastersip[@]}"; do
        cat >> /etc/hosts << EOF
$masterip kubernetes-master$nodenumber
EOF
        nodenumber=$(($nodenumber+1))
    done
    systemctl enable chronyd --now
    cat >> /etc/chrony.conf << EOF
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp1.tencent.com iburst
server ntp2.tencent.com iburst
EOF
    systemctl restart chronyd
    sed -i '/^00 0 * * * root systemctl restart chronyd iburst/d' /etc/chrony.conf
    cat >> /etc/crontab.conf << EOF
00 0 * * * root systemctl restart chronyd
EOF
    modprobe br_netfilter
    echo "br_netfilter" >> /etc/modules-load.d/modules.conf
    cat > /etc/sysctl.d/kubernetes.conf << "EOF"
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
    sysctl -p /etc/sysctl.d/kubernetes.conf
}

k8s::k3s(){
    if [ $options_yum -eq 0 ]; then
        options_yum_install="aliyun"; options_yum=1; conf::reposource
    fi
    if [ $options_docker -eq 0 ]; then
        options_docker=1; install::docker
    fi
    curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn INSTALL_K3S_EXEC="--docker --disable traefik,metrics-server --service-node-port-range=1-65535 --flannel-ipv6-masq" sh -
}

k8s::main(){
    local MIN_VERSION="1.19.0"
    local MAX_VERSION=$(curl -sk "https://version.nuoyis.net/json/kubernetes.json" 2>/dev/null | grep -o '"versions"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"//;s/"$//')
    if [ -z "$MAX_VERSION" ]; then MAX_VERSION="1.35.1"; fi
    if [ -z "$options_k8s_version" ]; then options_k8s_version="$MAX_VERSION"; fi
    k8s_networkname=$(ip route | grep default | awk '{print $5}')
    current_kernel=$(uname -r | cut -d- -f1)
    if [ -z "$options_k8s_keepalived" ]; then
        k8s_keepalived="$(hostname -I | awk '{print $1}' | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)\..*/\1/').199:16443"
    else
        k8s_keepalived="$options_k8s_keepalived"
    fi

    if [ $(k8s::compare_versions $options_k8s_version $MIN_VERSION) -lt 0 ]; then
            echo "version ($options_k8s_version) < min ($MIN_VERSION)."; exit 1
        elif [ $(k8s::compare_versions $options_k8s_version $MAX_VERSION) -gt 0 ]; then
            echo "version ($options_k8s_version) > max ($MAX_VERSION)."; exit 1
        else
            if [ $(k8s::version_check $options_k8s_version) -eq 0 ]; then
                if [ $system_version -gt "8" ];then
                    echo "os version 8+ not support docker mode k8s"; exit 1
                fi
            fi
            for ip in $(hostname -I); do
                if [[ "$ip" == "${options_k8s_mastersip[0]}" ]]; then
                    k8s_is_first_master=true
                    # 若用户已指定 -r 参数则跳过默认源配置；否则用 aliyun 默认源
                    if [ $options_yum -eq 0 ]; then
                        options_yum_install="aliyun"; options_yum=1; conf::reposource
                    fi
                    yum install sshpass -y
                    echo "parallel installing base software, check log in /var/log/toolbox-kubernetes"
                    mkdir -p /var/log/toolbox-kubernetes
                    all_ips=("${options_k8s_mastersip[@]}" "${options_k8s_nodesip[@]}")
                    pids=()
                    declare -A pid_host
                    fail_count=0
                    for initip in "${all_ips[@]}"; do
                        {
                        k8s_toolbox_path="$(realpath "$0")"
                        sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$initip "rm -rf /usr/bin/nuoyis-toolbox"
                        sshpass -p "$options_k8s_password" scp -o StrictHostKeyChecking=no "$k8s_toolbox_path" root@$initip:/usr/bin/nuoyis-toolbox
                        sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$initip "chmod +x /usr/bin/nuoyis-toolbox"
                        sshpass -p "$options_k8s_password" ssh -o StrictHostKeyChecking=no root@$initip "nuoyis-toolbox -r aliyun -do" >> "/var/log/toolbox-kubernetes/${initip}.log" 2>&1
                        } &
                        pid=$!
                        pids+=($pid)
                        pid_host[$pid]=$initip
                    done
                    for pid in "${pids[@]}"; do
                        wait $pid
                        if [ $? -ne 0 ]; then
                            echo "${pid_host[$pid]} install failed"
                            ((fail_count++))
                        fi
                    done
                    break
                fi
            done
            k8s::init
            if [ $(k8s::version_check $options_k8s_version) -eq 0 ]; then
                yum remove -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin -y
                yum install docker-ce-19.03.15 docker-ce-cli-19.03.15 -y
            fi
            k8s::install_kubernetes
            if [ $(k8s::version_check $options_k8s_version) -eq 1 ]; then
                if [ $system_version == "7" ];then
                    echo "current kernel: $current_kernel, require >= $k8s_MIN_KERNEL_VERSION"
                    if printf "%s\n%s\n" "$k8s_MIN_KERNEL_VERSION" "$current_kernel" | sort -V -C; then
                        echo "kernel ok"
                    else
                        echo "kernel too old, upgrading and rebooting"
                        k8s::install_kernel
                        exit 0
                    fi
                fi
            fi
            k8s::config
        fi
}


echo "判断服务器位置为:$server_location"

#### 执行函数区域 ####
[[ $options_install -eq 1 ]] && toolbox::install
[[ $options_yum -eq 1 ]] && conf::reposource
[[ $options_swap -eq 1 ]] && manager::swap
[[ $installlock -eq 0 ]] && install::main && touch /root/.toolbox-install-init.lock
[[ $options_bt -eq 1 ]] && install::bt
[[ $options_kernel_update -eq 1 ]] && install::kernel
[[ $options_tuning -eq 1 ]] && conf::tuning
[[ $options_docker -eq 1 ]] && install::docker
[[ $options_docker_app -eq 1 ]] && install::dockerapp
[[ $options_lnmp -eq 1 ]] && install::lnmp
[[ $options_ollama -eq 1 ]] && install::ollama
[[ $options_nas -eq 1 ]] && install::nas
[[ $options_k3s -eq 1 ]] && k8s::k3s
[[ $options_k8s -eq 1 ]] && k8s::main

# 销毁脚本安装时创建目录
rm -rf /server/install