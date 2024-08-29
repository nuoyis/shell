# !/bin/sh
# 诺依阁-初始化脚本
LANG=en_US.UTF-8
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
if [ -f "/etc/redhat-release" ];then
	system_name=`cat /etc/redhat-release | awk '{print $1$2}'`
	system_version=`cat /etc/redhat-release | egrep -o "[0-9].[0-9]"`
	system_version=${system_version%.*}
fi

# 检测包管理器
if command -v yum > /dev/null 2>&1 && [ -d "/etc/yum.repos.d/" ]; then
    PM="yum"
	setenforce 0
elif command -v apt-get > /dev/null 2>&1 && command -v dpkg > /dev/null 2>&1; then
    PM="apt"
fi

# 函数类

# 文件/脚本下载类
nuoyis_download_manager(){
	if [ -f /usr/bin/curl ];then
		curl -sSO $1;
	else 
		wget $1;
	fi;
}

# 系统项启动
nuoyis_systemctl_manger(){
	if [ -n $1 ] && [ -n $2 ];then
		case $1 in
			"start")
				systemctl enable --now $2
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

# 源安装/更新函数
nuoyis_install_manger(){
	case $1 in
		"remove")
			# 移除指定的软件包
			yes | $PM remove $2 -y
			;;
		"install")
			# 安装多个指定的软件包
			for nuoyis_install in ${@:2}
			do
				yes | $PM install $nuoyis_install -y
			done
			;;
		"update")
			# 更新所有软件包
			if [ $PM = "apt" ]; then
				yes | $PM update
			fi
			yes | $PM upgrade
			;;
		"clean")
			# 清理缓存
			$PM clean all
			;;
		"makecache")
			# 生成缓存
			$PM makecache
			;;
		"installfull")
			# 在Yum中使用特定选项安装软件包
			if [ $PM = "yum" ]; then
				yes | $PM $2 install ${@:3} -y
			fi
			;;
		"updatefull")
			# 在Yum中使用特定选项更新软件包
			if [ $PM = "yum" ]; then
				yes | $PM $2 update ${@:3} -y
			fi
			;;		
		"installcheck") 
			# 检查指定的软件包是否安装
			$PM list installed | egrep $2 &>/dev/null
			;;
		"repoadd")
			if [ $PM = "yum" ]; then
				# repo添加
				$PM config-manager --add-repo $2
			fi
			;;
		*)
			# 无效参数处理
			echo "错误指令"
			exit 1
	esac
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

# 原有宝塔则卸载
	if [ -f "/etc/init.d/bt" ] || [ -d "/www/server/panel" ]; then
		echo -e "此服务器安装过宝塔，正在删除"
		nuoyis_download_manager https://download.bt.cn/install/bt-uninstall.sh;
		echo yes | source bt-uninstall.sh -y
		rm -rf ./bt-uninstall.sh
	fi

# 原有环境判断并卸载
    nuoyis_install_manger remove nginx* php* mariadb* mysql*
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
	nuoyis_download_manager https://download.bt.cn/install/install_panel.sh
	# 安装宝塔
	echo yes | source install_panel.sh -y

	# 检查宝塔是否安装成功


	# 修复宝塔php8.3 无--enable-mbstring问题
	nuoyis_download_manager https://gitee.com/nuoyis/shell/raw/main/btpanel_bug_update/php.sh
	mv -f ./php.sh /www/server/panel/install/php.sh 2>/dev/null
	
	# 删除残留脚本
	rm -rf ./install_panel.sh
}

# lnmp安装类
nuoyis_lnmp_install(){
	echo "安装lnmp"
	echo "正在测试中，请晚些时候再执行"
	if [ $PM = "yum" ];then
		nuoyis_install_manger install pcre pcre-devel zlib zlib-devel libxml2 libxml2-devel readline readline-devel ncurses ncerses-devel perl-devel perl-ExtUtils-Embed
    else
		nuoyis_install_manger install apt-transport-https dirmngr software-properties-common ca-certificates libgd-dev libgd2-xpm-dev
	fi
	if [ $nuoyis_lnmp_install_yn = "y" ];then
            # 快速安装
			if [ $PM = "yum" ];then
				yes | dnf module reset php
				yes | dnf module install php:remi-8.2
				nuoyis_install_manger install nginx* php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-redis mariadb*
				nuoyis_systemctl_manger start nginx
				nuoyis_systemctl_manger start php-fpm
				nuoyis_systemctl_manger start mysqld
			else
				nuoyis_install_manger install nginx mariadb-server mariadb-client php8.2 php8.2-mysql php8.2-fpm php8.2-gd php8.2-xmlrpc php8.2-curl php8.2-intl php8.2-mbstring php8.2-soap php8.2-zip php8.2-ldap php8.2-xsl php8.2-opcache php8.2-cli php8.2-xml php8.2-common
			fi
    else
            # 编译安装
			echo "创建lnmp基础文件夹"
			mkdir -p /$auth-server/{nginx/{webside,server,conf},php,mysql}
            nuoyis_download_manager https://mirrors.huaweicloud.com/nginx/nginx-1.27.0.tar.gz
            tar -xzvf nginx-1.27.0.tar.gz
            cd nginx-1.27.0
			id -u ${auth}_web >/dev/null 2>&1
			if [ $? -eq 1 ];then
            	useradd ${auth}_web -s /sbin/nologin -M
			fi;
			nuoyis_install_manger install gd-devel.x86_64
			# --with-openssl=${nuoyis_openssl} 
			./configure --prefix=/$auth-server/nginx/server --user=${auth}_web --group=${auth}_web --with-http_stub_status_module --with-http_ssl_module --with-http_image_filter_module --with-http_gzip_static_module --with-http_gunzip_module --with-ipv6 --with-http_sub_module --with-http_flv_module --with-http_addition_module --with-http_realip_module --with-http_mp4_module --with-http_auth_request_module
			make && make install
			mkdir -p /$auth-server/logs/nginx
			touch /$auth-server/logs/nginx/{error.log,nginx.pid}
			cd ..
			rm -rf ./nginx-1.27.0
			rm -rf ./nginx.tar.gz
			cat > /$auth-server/nginx/server/conf/nginx.conf << EOF
worker_processes  1;

error_log  /${auth}-server/logs/nginx/error.log;

pid        /${auth}-server/logs/nginx/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    #                  '\$status \$body_bytes_sent "\$http_referer" '
    #                  '"\$http_user_agent" "\$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;
	
    gzip on;
	include /$auth-server/nginx/conf/*.conf;
}
EOF
			cat > /$auth-server/nginx/conf/default.conf << EOF
server {
	listen 80;
	# listen 443 ssl;
	server_name localhost;

	#charset koi8-r;

	#access_log  logs/host.access.log  main;

	location / {
		root   html;
		index  index.html index.htm;
	}

	# if ($server_port !~ 443){
    #     rewrite ^(/.*)$ https://$host$1 permanent;
    # }

	error_page 404 /404.html;

	# redirect server error pages to the static page /50x.html
	#
	error_page   500 502 503 504  /50x.html;
	location = /50x.html {
		root  html;
	}

	# proxy the PHP scripts to Apache listening on 127.0.0.1:80
	#
	#location ~ \.php$ {
	#    proxy_pass   http://127.0.0.1;
	#}

	# pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
	#
	#location ~ \.php$ {
	#    root           html;
	#    fastcgi_pass   127.0.0.1:9000;
	#    fastcgi_index  index.php;
	#    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
	#    include        fastcgi_params;
	#}

	# deny access to .htaccess files, if Apache's document root
	# concurs with nginx's one
	#
	#location ~ /\.ht {
	#    deny  all;
	#}
}

EOF
    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

			ln -s /$auth-server/nginx/server/sbin/nginx /usr/local/bin/
			nginx
    fi	
}

# docker安装类
nuoyis_docker_install(){
	echo "安装Docker"
	if [ $PM = "yum" ];then
	nuoyis_install_manger install yum-utils device-mapper-persistent-data lvm2
	nuoyis_install_manger repoadd https://chinanet.mirrors.ustc.edu.cn/docker-ce/linux/centos/docker-ce.repo
	fi
	sed -i 's+download.docker.com+chinanet.mirrors.ustc.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo
	nuoyis_install_manger makecache
	nuoyis_install_manger install docker-ce
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
}

# 源配置类
nuoyis_source_installer(){
	reponum=`$PM list | wc -l`
	
	# if [ $reponum -lt 1000 ];then
		if [ $PM = "yum" ];then
			echo "正在检查是否存在冲突/模块缺失"
			echo "正在检查模块依赖问题..."

			nuoyis_install_check_modules_bug=$(yum check 2>&1)

			if [ -z "$nuoyis_install_check_modules_bug" ]; then
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
				done <<< "$nuoyis_install_check_modules_bug"
				echo "模块依赖修复和冲突模块禁用完成。"
			fi

			if [ ! -d /etc/yum.repos.d/bak ];then
				mkdir -p /etc/yum.repos.d/bak
			fi
			mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null
			mv -f /etc/yum.repos.d/*.repo.* /etc/yum.repos.d/bak/ 2>/dev/null
			cat > /etc/yum.repos.d/$auth.repo << EOF
[${auth}-BaseOS]
name=${auth} - BaseOS
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/BaseOS/\$basearch/os/
gpgcheck=0

[${auth}-baseos-debuginfo]
name=${auth} - BaseOS - Debug
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=BaseOS-\$releasever-debug\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/BaseOS/\$basearch/debug/tree/
gpgcheck=0

[${auth}-baseos-source]
name=${auth} - BaseOS - Source
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=BaseOS-\$releasever-source\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/BaseOS/source/tree/
gpgcheck=0

[${auth}-appstream]
name=${auth} - AppStream
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=AppStream-\$releasever\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/AppStream/\$basearch/os/
gpgcheck=0

[${auth}-appstream-debuginfo]
name=${auth} - AppStream - Debug
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=AppStream-\$releasever-debug\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/AppStream/\$basearch/debug/tree/
gpgcheck=0

[${auth}-appstream-source]
name=${auth} - AppStream - Source
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=AppStream-\$releasever-source\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/AppStream/source/tree/
gpgcheck=0

[${auth}-crb]
name=${auth} - CRB
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=CRB-\$releasever\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/CRB/\$basearch/os/
gpgcheck=0

[${auth}-crb-debuginfo]
name=${auth} - CRB - Debug
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=CRB-\$releasever-debug\$rltype
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/CRB/\$basearch/debug/tree/
gpgcheck=0

[${auth}-crb-source]
name=${auth} - CRB - Source
baseurl=https://chinanet.mirrors.ustc.edu.cn/rocky/\$releasever/CRB/source/tree/
gpgcheck=0
EOF

# [${auth}-epel]
# name=${auth} - epel
# # It is much more secure to use the metalink, but if you wish to use a local mirror
# # place its address here.
# baseurl=https://chinanet.mirrors.ustc.edu.cn/epel/\$releasever/Everything/\$basearch/
# #metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-\$releasever&arch=\$basearch&infra=\$infra&content=\$contentdir
# gpgcheck=0

# [${auth}-epel-debuginfo]
# name=${auth} - epel - Debug
# # It is much more secure to use the metalink, but if you wish to use a local mirror
# # place its address here.
# baseurl=https://chinanet.mirrors.ustc.edu.cn/epel/\$releasever/Everything/\$basearch/debug/
# #metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-\$releasever&arch=\$basearch&infra=\$infra&content=\$contentdir
# gpgcheck=0

# [${auth}-epel-source]
# name=${auth} - epel - Source
# baseurl=https://chinanet.mirrors.ustc.edu.cn/epel/\$releasever/Everything/source/tree/
# #metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-source-\$releasever&arch=\$basearch&infra=\$infra&content=\$contentdir
# gpgcheck=0


	echo "skip_broken=True" >> /etc/yum.conf
	echo "skip_broken=True" >> /etc/dnf/dnf.conf

	echo "正在配置附加源"
	nuoyis_install_manger installcheck epel
	if [ $? -eq 0 ];then
		nuoyis_install_manger remove epel-release epel-next-release
	fi

	nuoyis_install_manger installcheck remi
	if [ $? -eq 0 ];then
		nuoyis_install_manger remove remi-release-9.4-2.el9.remi.noarch
	fi

	nuoyis_install_manger installcheck elrepo
	if [ $? -eq 0 ];then
		nuoyis_install_manger remove elrepo-release.noarch
	fi

	rpm --import https://shell.nuoyis.net/download/RPM-GPG-KEY-elrepo.org
	rpm --import https://mirrors.bfsu.edu.cn/epel/RPM-GPG-KEY-EPEL-9
	nuoyis_install_manger install https://mirrors.bfsu.edu.cn/epel/epel-release-latest-9.noarch.rpm https://mirrors.bfsu.edu.cn/epel/epel-next-release-latest-9.noarch.rpm https://shell.nuoyis.net/download/elrepo-release-9.1-1.el9.elrepo.noarch.rpm
	sudo sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.cernet.edu.cn/epel!g' \
    -e 's!https\?://download\.example/pub/epel!https://mirrors.cernet.edu.cn/epel!g' \
    -i /etc/yum.repos.d/epel{,-testing}.repo
	sed -i 's/mirrorlist=/#mirrorlist=/g' /etc/yum.repos.d/elrepo.repo
	sed -i 's#elrepo.org/linux#mirrors.cernet.edu.cn/elrepo#g' /etc/yum.repos.d/elrepo.repo
	nuoyis_install_manger install https://shell.nuoyis.net/download/remi-release-9.rpm
	else
		# sudo sed -i -r 's#http://(archive|security).ubuntu.com#https://mirrors.aliyun.com#g' /etc/apt/sources.list && sudo apt-get update
		echo "debian架构系列正在进入第三方脚本，请注意版本安全"
		nuoyis_download_manager https://3lu.cn/main.sh
		source main.sh
		echo "yes"
	fi

	if [ $system_name == "RedHat" ];then
		echo "正在对RHEL系统进行openssl系统特调"
		# if [ -d `whereis openssl | cut -d : -f 2 | awk '{print $1}'` ];then
		# 	nuoyis_openssl=`whereis openssl | cut -d : -f 2 | awk '{print $1}'`
		# else
		rpm --import https://shell.nuoyis.net/download/RPM-GPG-KEY-Rocky-9
		nuoyis_download_manager https://shell.nuoyis.net/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
		nuoyis_download_manager https://shell.nuoyis.net/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
		rpm -ivh --force --nodeps openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
		rpm -ivh --force --nodeps openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
		rm -rf openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
		install_dir="/nuoyis-server/openssl/3.3.1"
		mkdir -p $install_dir
		nuoyis_install_manger remove subscription-manager-gnome     
		nuoyis_install_manger remove subscription-manager-firstboot     
		nuoyis_install_manger remove subscription-manager
		nuoyis_install_manger install gcc gcc-c++ zlib-devel libtool autoconf automake perl perl-IPC-Cmd perl-Data-Dumper perl-CPAN yum-versionlock
		nuoyis_download_manager https://shell.nuoyis.net/download/openssl-3.3.1.tar.gz
		tar -xzvf openssl-3.3.1.tar.gz openssl-3.3.1/
		./openssl-3.3.1/config --prefix=${install_dir} shared zlib-dynamic enable-ec_nistp_64_gcc_128 enable-ssl3 enable-ssl3-method enable-mdc2 enable-md2
		make -j$(nproc) && make install_sw
		# mv -f ./openssl-3.3.1/* /nuoyis-server/openssl/ &> /dev/null
		# nuoyis_openssl="/nuoyis-server/openssl/"
		rm -rf ./openssl-3.3.1
		rm -rf ./openssl-3.3.1.tar.gz
		# fi;
		# rpm -e --nodeps openssl
		echo "exclude=openssh* openssl openssl-lib" >> /etc/yum.conf

		mv -f /usr/lib64/libcrypto.so.3 /usr/lib64/libcrypto.so.3.old 2> /dev/null
		mv -f /usr/lib64/libssl.so.3 /usr/lib64/libssl.so.3.old 2> /dev/null
		mv -f /usr/bin/openssl /usr/lib64/openssl.old

		ln -sf $install_dir/lib64/libcrypto.so.3 /usr/lib64/libcrypto.so.3
		ln -sf $install_dir/lib64/libssl.so.3 /usr/lib64/libssl.so.3
		ln -sf $install_dir/bin/openssl /usr/bin/openssl

		
		echo "export PATH=\$PATH:${install_dir}/bin" >> /etc/profile
		echo "export LD_LIBRARY_PATH="${install_dir}/lib:\$LD_LIBRARY_PATH"" >> /etc/profile
		source /etc/profile

		echo "$install_dir/lib" > /etc/ld.so.conf.d/openssl-3.3.1.conf
		ldconfig
	fi

	echo "正在更新源"
	nuoyis_install_manger clean
	nuoyis_install_manger update
	nuoyis_install_manger makecache
	# fi
}


# 脚本run --> 起始点

echo -e "=================================================================="
echo -e "     诺依阁服务器初始化脚本V2.1"
echo -e "     更新时间:2024.08.16"
echo -e "     博客地址:https://blog.nuoyis.net"
echo -e "     \e[31m\e[1m注意1:执行本脚本即同意作者方不承担执行脚本的后果 \e[0m"
echo -e "     \e[31m\e[1m注意2:当前脚本pid为$$,如果卡死请执行kill -9 $$ \e[0m"
echo -e "=================================================================="
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

echo "创建$auth服务初始化内容"
mkdir -p /$auth-server/{openssl,logs,shell}
# for i in 
# touch /$auth-server/

echo "检测hostname是否设置"
HOSTNAME_CHECK=$(cat /etc/hostname)
if [ -z $HOSTNAME_CHECK ];then
	echo "当前主机名hostname为空，设置默认hostname"
	hostnamectl set-hostname $auth-init-shell
fi

echo "正在检查支持版本"
if [ $PM == "yum" ];then
	if [ $system_version -lt 9 ];then
		echo "不受支持版本,正在检测你的系统"
		if [ $system_version -eq 8 ] && [ $system_name == "RockyLinux" ];then
			read -p "是否进行版本更新，反之退出脚本(y/n):" nuoyis_update
			if [ $nuoyis_update == "n" ];then
        		echo "正在退出脚本"
       	 		exit 0
			else
				echo -e "警告！！！"
				echo -e "请保证升级9之前，请先检查是否有重要备份数据，不过本脚本作者精心提醒:生产环境就不要执行脚本了，如果是云厂商只有8版本，且是空白面板可以执行"
				echo -e "重启后需要重新执行该命令操作下一步，如果同意更新请输入y,更新出现任何问题与作者无关"
				read -p "是否进行版本更新，反之退出脚本(y/n):" nuoyis_update_again
				if [ $nuoyis_update_again == "n" ];then
        			echo "正在退出脚本"
       	 			exit 0
				else
					nuoyis_source_installer
					# https://www.rockylinux.cn/notes/strong-rocky-linux-8-sheng-ji-zhi-rocky-linux-9-strong.html
					# 安装 epel 源
					dnf -y install epel-release
					
					# 更新系统至最新版
					dnf -y update

					# 安装 rpmconf 和 yum-utils
					dnf -y install rpmconf yum-utils
					
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
					dnf -y --releasever=9 --allowerasing --setopt=deltarpm=false distro-sync
										
					# 重建 rpm 数据库，出现警告忽略。
					yes | rpm --rebuilddb
					
					# 安装新内核
					dnf -y install kernel
					dnf -y install kernel-core
					dnf -y install shim
					
					# 安装基础环境
					dnf group install minimal-environment -y
					
					# 安装 rpmconf 和 yum-utils
					dnf -y install rpmconf yum-utils
					
					# 执行 rpmconf，根据提示一直输入 Y 和回车即可
					rpmconf -a
					
					# 设置采用最新内核引导
					export grubcfg=`find /boot/ -name rocky`
					grub2-mkconfig -o $grubcfg/grub.cfg
					
					# 更新系统
					dnf -y update
					
					# 重启系统
					reboot
				fi
			fi
		elif [ $system_version -eq 7 ] && [ $system_name == "Centos" ];then
			echo "等待更新"
		elif [ $system_version -eq 8 ] && [ $system_name == "Centos" ];then
			echo "等待更新"
		fi
	fi
fi

echo "环境提前配置问答"
read -p "附加项:是否安装/重装宝塔面板(y/n):" nuoyis_bt
if [ $nuoyis_bt == "y" ];then
	echo "宝塔启动安装后，则请在宝塔内安装其他附加环境,将不再提醒其他环境"
	echo -e "\e[31m\e[1m注意:国内版宝塔安装完毕后，请执行bt 输入5修改密码，6修改用户名,bt命令后14查看默认信息\e[0m"
	read -p "请按任意键继续" nuoyis_go
	nuoyis_lnmp=n
	nuoyis_docker=n
else
	read -p "附加项:是否安装LNMP环境(y/n):" nuoyis_lnmp
	if [ $nuoyis_lnmp == "y" ];then
	read -p "请输入是快速安装(y)还是编译安装(n):" nuoyis_lnmp_install_yn
	fi
	read -p "附加项:是否安装Docker(y/n):" nuoyis_docker
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
nuoyis_source_installer

echo "系统优化类"

echo "配置基础系统文件"
nuoyis_install_manger install dnf-plugins-core python3 pip bash* vim git wget net-tools tuned dos2unix gcc gcc-c++ make unzip perl perl-IPC-Cmd perl-Test-Simple


# 来自https://www.rockylinux.cn

echo "正在对系统进行调优"

if [ $PM = "yum" ];then
nuoyis_install_manger installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml.x86_64
nuoyis_install_manger remove kernel-tools-libs.x86_64 kernel-tools.x86_64
nuoyis_install_manger installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml-tools.x86_64
else
	echo "暂时不支持rhel以外系列更新内核"
fi

nuoyis_systemctl_manger start tuned.service
tuned-adm profile `tuned-adm recommend`
cat > /etc/sysctl.conf << EOF
$(egrep -v '^net.core.default_qdisc|^net.ipv4.tcp_congestion_co
ntrol' /etc/sysctl.conf)
EOF
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p

# kernel-Version=yum info kernel-ml-tools | grep Version | awk '{print $3}'

# 安装宝塔
if [ $nuoyis_bt == "y" ];then
	nuoyis_bt_install
fi

# 安装lnmp
if [ $nuoyis_lnmp == "y" ];then
	nuoyis_lnmp_install
fi

# 安装docker
if [ $nuoyis_docker == "y" ];then
	nuoyis_docker_install
fi

# 校园网账号破解多设备
#echo "自启动firewalld"
## 安装并启用firewalld
#sudo yum install -y firewalld
#sudo systemctl enable --now firewalld
#
#echo "网卡转发配置"
## 启用IP转发
#sudo sysctl -w net.ipv4.ip_forward=1
#echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
#
## 配置转发和屏蔽规则
#sudo firewall-cmd --permanent --add-masquerade
## sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" forward destination address="172.17.1.2" reject'
## sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" forward source address="172.17.1.2" reject'
#
## 重新加载firewalld规则
#sudo firewall-cmd --reload

rm -rf ./nuoyis-init.sh

echo "安装完毕，向前出发吧"