#!/bin/bash
# Script Name    : nuoyis toolbox
# Version:       : v1.5
# Description    : Linux quick initialization and installation
# Create Date    : 2025-04-23
# auth           : nuoyis
# Webside        : blog.nuoyis.net

LANG=en_US.UTF-8
#变量定义区域
#手动变量定义区域
nuname="nuoyis"
CIDR="10.104.43"
gateway="10.104.0.1"
dns="223.5.5.5"

#自动获取变量区域
startTime=`date +%Y%m%d-%H:%M:%S`
startTime_s=`date +%s`
osversion="\$releasever"
whois=$(whoami)
# nuo_setnetwork_shell=$(ip a | grep -E '^[0-9]+: ' | grep -v lo | awk '{print $2}' | sed 's/://')
nuo_setnetwork_shell=$(ip a | grep -oE "inet ([0-9]{1,3}.){3}[0-9]{1,3}" | awk 'NR==2 {print $2}')
system_name=`head -n 1 /etc/os-release | grep -oP '(?<=NAME=").*(?=")' | awk '{print$1}'`
system_version=`cat /etc/os-release | grep -oP '(?<=VERSION_ID=").*(?=")'`
system_version=${system_version%.*}

# 检测包管理器
if command -v yum > /dev/null 2>&1 && [ -d "/etc/yum.repos.d/" ]; then
    PM="yum"
	case $system_name in
		"CentOS")
		osname="centos-stream"
		osversion="\$releasever-stream"
		;;
		"openEuler")
	esac
	if [ -f "/etc/redhat-release" ];then
		setenforce 0 &> /dev/null
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
	fi
elif command -v apt-get > /dev/null 2>&1 && command -v dpkg > /dev/null 2>&1; then
    PM="apt"
fi

manager::download(){
	if [ -f /usr/bin/curl ];then
		curl -sSOLk $1;
	else 
		wget $1;
	fi;
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

manager::yum(){
    case $1 in
		"remove")
			# 移除指定的软件包
			yes | $PM autoremove $2 -y
			;;
		"install")
			# 安装多个指定的软件包
			for options_install in ${@:2}
			do
				yes | $PM install $options_install -y
			done
			;;
		"update")
			# 更新所有软件包
			if [ $PM = "apt" ]; then
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

manager::filewrite(){
	if [ $1 -eq 0 ];then
		$3 > $2
	elif [ $1 -eq 1 ];then
		$3 >> $2
	# elif [ $1 -eq 2 ];then
	fi
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
    manager::yum remove nginx* php* mariadb* mysql*
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

	# 检查宝塔是否安装成功


	# 修复宝塔php8.3 无--enable-mbstring问题
	manager::download https://gitee.com/nuoyis/shell/raw/main/btpanel_bug_update/php.sh
	mv -f ./php.sh /www/server/panel/install/php.sh 2>/dev/null
	
	# 删除残留脚本
	rm -rf ./install_panel.sh
}

install::nas(){
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    useradd nuoyis-file
    mkdir -p /$nuname-server/sharefile
    chown -R nuoyis-file:nuoyis-file /$nuname-server/sharefile
    chown root:nuoyis-file /$nuname-server/sharefile
    chmod -R 775 /$nuname-server/sharefile
    # chmod g+s /$nuname-server/sharefile
    # 额外配置
    manager::yum install vsftpd samba*

    firewall-cmd --per --add-service=smb
    firewall-cmd --per --add-service=ftp
    firewall-cmd --reload

    cat > /etc/vsftpd/vsftpd.conf << EOF
# 不以独立模式运行
listen=NO
# 支持 IPV6，如不开启 IPV4 也无法登录
listen_ipv6=YES

# 匿名用户登录
anonymous_enable=YES
no_anon_password=YES
# 允许匿名用户上传文件
anon_upload_enable=YES
# 允许匿名用户新建文件夹
anon_mkdir_write_enable=YES
# 匿名用户删除文件和重命名文件
anon_other_write_enable=YES
# 匿名用户的掩码（022 的实际权限为 666-022=644）
anon_umask=022
anon_root=/$nuname-server/sharefile
chown_uploads=YES
chown_username=nuoyis-file

# 系统用户登录
local_enable=YES
local_umask=022
local_root=/$nuname-server/sharefile
chroot_local_user=YES
allow_writeable_chroot=YES
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd/chroot_list
# 对文件具有写权限，否则无法上传
write_enable=YES

max_clients=0
max_per_ip=0

# 使用主机时间
use_localtime=YES
pam_service_name=vsftpd
EOF

cat > /etc/samba/smb.conf <<EOF
# See smb.conf.example for a more detailed config file or
# read the smb.conf manpage.
# Run 'testparm' to verify the config is correct after
# you modified it.
#
# Note:
# SMB1 is disabled by default. This means clients without support for SMB2 or
# SMB3 are no longer able to connect to smbd (by default).

[global]
	workgroup = SAMBA
	security = user
	passdb backend = tdbsam
	printing = cups
	printcap name = cups
	load printers = yes
	cups options = raw
	map to guest = bad user

[homes]
	comment = Home Directories
	valid users = %S, %D%w%S
	browseable = No
	read only = No
	inherit acls = Yes

[printers]
	comment = All Printers
	path = /var/tmp
	printable = Yes
	create mask = 0600
	browseable = No

[print$]
	comment = Printer Drivers
	path = /var/lib/samba/drivers
	write list = @printadmin root
	force group = @printadmin
	create mask = 0664
	directory mask = 0775

[share]
        comment = nuoyis's share
        path = /$nuname-server/sharefile
		browsable = yes
		writable = yes
		guest ok = yes
		force user = nuoyis-file
		force group = nuoyis-file
		create mask = 0775
		directory mask = 0775
        public = yes
EOF

cat >> /etc/profile << EOF
echo "################################"
echo "#  Welcome  to  $nuname's  NAS  #"
echo "################################"
EOF

cat > /$nuname-server/web/nginx/server/conf/nginx.conf << EOF
server {
	listen 80;
    listen [::]:80;
	# listen 443 ssl;
	server_name _;
	#charset koi8-r;
	charset utf-8;
	location /nuoyisnb {
                alias /$nuname-server/sharefile;
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
        
        #       aio on;                               # 启用异步传输
                directio 5m;                          # 当文件大于5MB时以直接读取磁盘的方式读取文件
                directio_alignment 4096;              # 与磁盘的文件系统对齐
                output_buffers 4 32k;                 # 文件输出的缓冲区大小为128KB
        
        #       limit_rate 1m;                        # 限制下载速度为1MB
        #       limit_rate_after 2m;                  # 当客户端下载速度达到2MB时进入限速模式
                max_ranges 4096;                      # 客户端执行范围读取的最大值是4096B
                send_timeout 20s;                     # 客户端引发传输超时时间为20s
                postpone_output 2048;                 # 当缓冲区的数据达到2048B时再向客户端发送
	}
	location /{
		rewrite ^/(.*) https://blog.nuoyis.net permanent;
	}
}
EOF
systemctl reload nginx
manager::systemctl start vsftpd smb nmb
}

install::docker(){
	echo "安装Docker"
	mkdir -p /$nuname-server/docker-yaml/
	if [ $PM = "yum" ];then
	manager::yum install yum-utils device-mapper-persistent-data lvm2
	manager::yum repoadd https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	fi
	sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
	if [ $system_name == "openEuler" ];then
		sed -i 's+$releasever+8+'  /etc/yum.repos.d/docker-ce.repo
	fi
	manager::yum makecache
	manager::yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin
	mkdir -p /etc/docker
	touch /etc/docker/daemon.json
	cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://hub.nastool.de",
    "https://docker.1ms.run",
    "https://docker.1panel.live",
    "https://docker.1panel.top",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://dockerhub.icu",
    "https://hub.rat.dev",
    "https://docker.wanpeng.top",
    "https://docker.mrxn.net",
    "https://docker.anyhub.us.kg",
    "https://dislabaiot.xyz",
    "https://docker.fxxk.dedyn.io",
    "https://docker-mirror.aigc2d.com",
    "https://doublezonline.cloud",
    "https://dockerproxy.com",
    "https://mirror.iscas.ac.cn",
    "https://docker66ccff.lovablewyh.eu.org",
    "https://docker.m.daocloud.io"
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
	manager::systemctl start docker
	curl -L "https://hub.gitmirror.com/https://github.com/docker/compose/releases/download/v2.32.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose && chmod +x /usr/bin/docker-compose
}

install::dockerapp(){
	cat > /nuoyis-server/docker-yaml/app.yaml <<EOF
version: '3'
services:
  nuoyis-app-alist:
    container_name: alist
    image: docker.m.daocloud.io/xhofe/alist:latest
    volumes:
      - /nuoyis-server/alist/data:/opt/alist/data
    ports:
      - 5244:5244
    environment:
      - PUID=0
      - PGID=0
      - UMASK=022
    restart: always
  nuoyis-app-qinglong:
    container_name: qinglong
    image: docker.m.daocloud.io/whyour/qinglong:debian
    volumes:
      - /nuoyis-server/qinglong/data:/ql/data
    ports:
      - 5700:5700
    environment:
      QlBaseUrl: '/'
    restart: always
  nuoyis-app-certd:
    image: registry.cn-shenzhen.aliyuncs.com/handsfree/certd:latest
    container_name: certd
    ports:
      - 7001:7001
      - 7002:7002
    volumes:
      - /nuoyis-server/certd:/app/data
    labels:
      com.centurylinklabs.watchtower.enable: "true"
    environment:
      - certd_system_resetAdminPasswd=false
    restart: always
  nuoyis-lnmp-autorestart:
    container_name: nuoyis-apps-autorestart
    image: docker.m.daocloud.io/willfarrell/autoheal
    environment:
      - AUTOHEAL_CONTAINER_LABEL=all
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
  nuoyis-apps-autoupdate:
    command: '--cleanup -i 3600'
    image: docker.m.daocloud.io/containrrr/watchtower
    volumes:
      - '/etc/docker/daemon.json:/etc/docker/daemon.json'
      - '/var/run/docker.sock:/var/run/docker.sock'
    environment:
      - TZ=Asia/Shanghai
    container_name: nuoyis-apps-autoupdate
    restart: always
EOF
docker-compose -f /$nuname-server/docker-yaml/app.yaml up -d
}

install::ollama(){
    manager::download https://ollama.com/install.sh
	source install_panel.sh
}

install::lnmp(){
	echo "安装lnmp"
	sleep 30
	if [ $PM = "yum" ];then
		aboutserver=`systemctl is-active firewalld`
		if [ $aboutserver == "inactive" ];then
			manager::systemctl start firewalld
		fi
		firewall-cmd --set-default-zone=public
		firewall-cmd --zone=public --add-service=http --per
		firewall-cmd --zone=public --add-port=3306/tcp --per
		firewall-cmd --reload
		if [ $options_lnmp_value == "yum" ];then
			# 快速安装
			yes | dnf module reset php
			yes | dnf module install php:remi-8.4
			manager::yum install nginx* php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-redis mariadb-server
			manager::systemctl start nginx php-fpm mariadb
			# ln -sf 
		elif [ $options_lnmp_value == "gcc" ];then
			# 编译安装
			mkdir -p /$nuname-server/{logs/nginx,web/{nginx/{webside/default,server/conf/ssl,conf},php/{server,conf},mysql}}
			touch /$nuname-server/logs/nginx/nginx.pid
			id -u nuoyis-web >/dev/null 2>&1
			if [ $? -eq 1 ];then
				useradd -u 2233 -m -s /sbin/nologin nuoyis-web
			fi;
			echo "安装必要依赖项"
			manager::yum install autoconf bison re2c make procps-ng gcc gcc-c++ iputils pkgconfig pcre pcre-devel zlib-devel openssl openssl-devel libxslt-devel libpng-devel libjpeg-devel freetype-devel libxml2-devel sqlite-devel bzip2-devel libcurl-devel libXpm-devel libzip-devel oniguruma-devel gd-devel geoip-devel
			manager::download https://mirrors.huaweicloud.com/nginx/nginx-1.27.0.tar.gz
			manager::download https://alist.nuoyis.net/d/blog/linux%E8%BD%AF%E4%BB%B6%E5%8C%85%E5%8A%A0%E9%80%9F/php/php-8.4.2.tar.gz
			tar -xzvf nginx-1.27.0.tar.gz
			tar -xzvf php-8.4.2.tar.gz
			cd nginx-1.27.0
			sed -i 's/#define NGINX_VERSION\s\+".*"/#define NGINX_VERSION      "1.27.0"/g' ./src/core/nginx.h
            sed -i 's/"nginx\/" NGINX_VERSION/"nuoyis server"/g' ./src/core/nginx.h
            sed -i 's/Server: nginx/Server: nuoyis server/g' ./src/http/ngx_http_header_filter_module.c
            sed -i 's/"Server: " NGINX_VER CRLF/"Server: nuoyis server" CRLF/g' ./src/http/ngx_http_header_filter_module.c
            sed -i 's/"Server: " NGINX_VER_BUILD CRLF/"Server: nuoyis server" CRLF/g' ./src/http/ngx_http_header_filter_module.c
            ./configure --prefix=/$nuname-server/web/nginx/server \
                --user=nuoyis-web --group=nuoyis-web \
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
                --with-mail \
                --with-mail_ssl_module \
                --with-stream \
                --with-stream_realip_module \
                --with-stream_ssl_module \
                --with-stream_ssl_preread_module
			make -j$(nproc) && make install
			chmod +x /$nuname-server/nginx/server/sbin/nginx
			cd ../php-8.4.2
			./configure --prefix=/$nuname-server/web/php \
                --disable-shared \
                --with-config-file-path=/$nuname-server/web/php/etc/ \
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
			cd ..
			touch /$nuname-server/logs/nginx/{error.log,nginx.pid}
cat > /$nuname-server/web/nginx/server/conf/nginx.conf <<EOF
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /nuoyis-server/logs/nginx/error.log warn;
pid /nuoyis-server/logs/nginx/nginx.pid;

events {
    worker_connections 2048;
}

http {
    include mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                     '\$status \$body_bytes_sent "\$http_referer" '
                     '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /nuoyis-server/logs/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;

    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_types text/plain application/xml text/css application/javascript application/json image/svg+xml;
    gzip_proxied any;

    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_errors off;

    client_body_buffer_size 16K;
    client_max_body_size 10M;


    # 默认页面的 server 配置
    server {
        listen 80 default_server;
        listen 443 default_server ssl;
        server_name _;
        # SSL 配置
        ssl_certificate /$nuname-server/web/nginx/server/conf/ssl/default.pem;
        ssl_certificate_key /$nuname-server/web/nginx/server/conf/ssl/default.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        charset utf-8;
        root /$nuname-server/web/nginx/webside/default;
        index index.html;

        # 错误页面配置
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;

        # include start-php-81.conf; 
    }

    # 其他相关配置
    include /$nuname-server/web/nginx/conf/*.conf;
}
EOF
curl -L -o /$nuname-server/web/nginx/webside/default/index.html https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/index.html
curl -L -o /$nuname-server/web/nginx/server/conf/ssl/default.pem https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/ssl/default.pem
curl -L -o /$nuname-server/web/nginx/server/conf/ssl/default.key https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/ssl/default.key
curl -L -o /$nuname-server/web/nginx/server/conf/start-php-84.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/start-php-84.conf.txt
curl -L -o /$nuname-server/web/nginx/server/conf/path.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/path.conf.txt
curl -L -o /$nuname-server/web/nginx/server/conf/start-php-81.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/start-php-81.conf.txt
curl -L -o /$nuname-server/web/php/etc/php.ini https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/84php.ini.txt
curl -L -o /$nuname-server/web/php/etc/php-fpm.d/fpm.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/fpm-84.conf.txt

ln -s /$nuname-server/web/nginx/server/sbin/nginx /usr/local/bin/
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
		elif [ $options_lnmp_value == "docker" ];then
		   mkdir -p /$nuname-server/web/{docker-yaml,nginx/{conf,webside/default,ssl},mariadb/{init,server,import,config}}
		   useradd -u 2233 -m -s /sbin/nologin nuoyis-web
           if [ -z $options_mariadb_value ];then
		        read -p "请输入mariadb root密码:" options_mariadb_value
           fi
		   cat > /$nuname-server/docker-yaml/nuoyis-docker-lnmp.yaml << EOF
version: '3'
services:
  nuoyis-lnmp-np:
    container_name: nuoyis-lnmp-np
    image: registry.cn-hangzhou.aliyuncs.com/nuoyis/nuoyis-lnmp-np:latest
    networks: 
      nuoyis-net:
        aliases:
          - nuoyis-lnmp-np
    ports:
      - 80:80
      - 443:443
    volumes:
      - /$nuname-server/web/nginx/conf:/nuoyis-web/nginx/conf
      - /$nuname-server/web/nginx/webside:/nuoyis-web/nginx/webside
      - /$nuname-server/web/nginx/ssl:/nuoyis-web/nginx/ssl
      - /var/log:/nuoyis-web/logs
    shm_size: '1g'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      retries: 3
      start_period: 10s
      timeout: 10s
    user: "\${SUID}:\${SGID}"
    restart: always
  nuoyis-lnmp-mariadb:
    container_name: nuoyis-lnmp-mariadb
    image: docker.m.daocloud.io/mariadb:latest
    networks: 
      nuoyis-net:
        aliases:
          - nuoyis-lnmp-mariadb
    environment:
      TIME_ZONE: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: "$options_mariadb_value"
    volumes:
      - /$nuname-server/web/mariadb/init/init.sql:/docker-entrypoint-initdb.d/init.sql
      - /$nuname-server/web/mariadb/server:/var/lib/mysql
      - /$nuname-server/web/mariadb/import:/nuoyis-web/mariadb/import
      - /$nuname-server/web/mariadb/config/my.cnf:/etc/mysql/my.cnf
    ports:
      - 3306:3306
    shm_size: '1g'
    healthcheck:
      test: ["CMD", "sh", "-c", "mariadb -u root -p$\$MYSQL_ROOT_PASSWORD -e 'SELECT 1 FROM information_schema.tables LIMIT 1;'"]
      interval: 30s
      retries: 3
      start_period: 10s
      timeout: 10s
    restart: always
  
networks:
  nuoyis-net:
    name: nuoyis-net
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.223.0/24
          gateway: 192.168.223.1
EOF
cat > /$nuname-server/web/nginx/webside/default/index.html << EOF
welcome to nuoyis's server
EOF
cat > /$nuname-server/web/mariadb/config/my.cnf << EOF
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_format=ROW
slave_skip_errors=1062
EOF
    docker rm -f nuoyis-lnmp-np
	docker rm -f nuoyis-lnmp-mariadb
	docker rm -f nuoyis-lnmp-autoheal
    docker-compose -f /$nuname-server/docker-yaml/nuoyis-docker-lnmp.yaml up -d
    	fi
	else
		manager::yum install apt-transport-https dirmngr software-properties-common ca-certificates libgd-dev libgd2-xpm-dev nginx mariadb-server mariadb-client php8.2 php8.2-mysql php8.2-fpm php8.2-gd php8.2-xmlrpc php8.2-curl php8.2-intl php8.2-mbstring php8.2-soap php8.2-zip php8.2-ldap php8.2-xsl php8.2-opcache php8.2-cli php8.2-xml php8.2-common
	fi
}

conf::yumsource(){
reponum=`$PM list | wc -l`

# if [ $reponum -lt 1000 ];then
if [ $PM = "yum" ];then
	echo "正在检查是否存在冲突/模块缺失"
	echo "正在检查模块依赖问题..."

	options_install_check_modules_bug=$(yum check 2>&1)

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

	# 判断源站
	if [ "$options_yum_install" == "other" ]; then
		manager::download https://3lu.cn/main.sh
		source main.sh
		echo "yes"
	else
		if [ $system_name != "openEuler" ];then
			if [ ! -d /etc/yum.repos.d/bak ];then
				mkdir -p /etc/yum.repos.d/bak
			fi
			mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null
			mv -f /etc/yum.repos.d/*.repo.* /etc/yum.repos.d/bak/ 2>/dev/null
			if [ "$options_yum_install" == "edu" ];then
				yumurl="mirrors.jcut.edu.cn"
				if [ $system_name = "Rocky" ]; then
					osname="rocky"
				fi
			elif [ "$options_yum_install" == "aliyun" ];then
				yumurl="mirrors.aliyun.com"
				if [ $system_name = "Rocky" ]; then
					osname="rockylinux"
				fi
			fi
            cat > /etc/yum.repos.d/$nuname.repo << EOF
[${nuname}-BaseOS]
name=${nuname} - BaseOS
baseurl=https://${yumurl}/${osname}/${osversion}/BaseOS/\$basearch/os/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-baseos-debuginfo]
name=${nuname} - BaseOS - Debug
baseurl=https://${yumurl}/${osname}/${osversion}/BaseOS/\$basearch/debug/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-baseos-source]
name=${nuname} - BaseOS - Source
baseurl=https://${yumurl}/${osname}/${osversion}/BaseOS/source/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-appstream]
name=${nuname} - AppStream
baseurl=https://${yumurl}/${osname}/${osversion}/AppStream/\$basearch/os/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-appstream-debuginfo]
name=${nuname} - AppStream - Debug
baseurl=https://${yumurl}/${osname}/${osversion}/AppStream/\$basearch/debug/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-appstream-source]
name=${nuname} - AppStream - Source
baseurl=https://${yumurl}/${osname}/${osversion}/AppStream/source/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-crb]
name=${nuname} - CRB
baseurl=https://${yumurl}/${osname}/${osversion}/CRB/\$basearch/os/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-crb-debuginfo]
name=${nuname} - CRB - Debug
baseurl=https://${yumurl}/${osname}/${osversion}/CRB/\$basearch/debug/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${nuname}-crb-source]
name=${nuname} - CRB - Source
baseurl=https://${yumurl}/${osname}/${osversion}/CRB/source/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1
EOF
			echo "skip_broken=True" >> /etc/yum.conf
			echo "skip_broken=True" >> /etc/dnf/dnf.conf

			echo "正在配置附加源"
			manager::yum installcheck epel
			if [ $? -eq 0 ];then
				manager::yum remove epel-release epel-next-release
			fi

			manager::yum installcheck remi
			if [ $? -eq 0 ];then
				manager::yum remove remi-release-9.4-2.el9.remi.noarch
			fi

			manager::yum installcheck elrepo
			if [ $? -eq 0 ];then
				manager::yum remove elrepo-release.noarch
			fi

			rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
			yum install https://mirrors.aliyun.com/epel/epel-release-latest-9.noarch.rpm https://mirrors.aliyun.com/epel/epel-next-release-latest-9.noarch.rpm https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm -y
			rm -rf /etc/yum.repos.d/epel-cisco-openh264.repo
			sed -e 's!^metalink=!#metalink=!g' \
			-e 's!^#baseurl=!baseurl=!g' \
			-e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.aliyun.com/epel!g' \
			-e 's!https\?://download\.example/pub/epel!https://mirrors.aliyun.com/epel!g' \
			-i /etc/yum.repos.d/epel{,*}.repo
			sed -e 's/http:\/\/elrepo.org\/linux/https:\/\/mirrors.aliyun.com\/elrepo/g' \
			    -e 's/mirrorlist=/#mirrorlist=/g' \
				-i /etc/yum.repos.d/elrepo.repo
			manager::yum install https://shell.nuoyis.net/download/remi-release-9.rpm
			sed -e 's|^mirrorlist=|#mirrorlist=|g' \
			-e 's|^#baseurl=http://rpms.remirepo.net|baseurl=http://mirrors.tuna.tsinghua.edu.cn/remi|g' \
			-e 's|^baseurl=http://rpms.remirepo.net|baseurl=http://mirrors.tuna.tsinghua.edu.cn/remi|g' \
			-i  /etc/yum.repos.d/remi*.repo
		else
			sed -i "s/http:\/\/repo.openeuler.org/https:\/\/mirrors.aliyun.com\/openeuler/g" /etc/yum.repos.d/openEuler.repo
		fi
	fi
	elif [ $PM = "apt" ];then
		# sudo sed -i -r 's#http://(archive|security).ubuntu.com#https://mirrors.aliyun.com#g' /etc/apt/sources.list && sudo apt-get update
		echo "正在进入第三方脚本，请注意版本安全"
		manager::download https://3lu.cn/main.sh
		source main.sh
		echo "yes"
	fi

	# 红帽系统特调
	if [ $system_name == "Red" ];then
		echo "正在对RHEL系统进行openssl系统特调"
		manager::yum remove subscription-manager-gnome     
		manager::yum remove subscription-manager-firstboot     
		manager::yum remove subscription-manager
		rpm -e --nodeps openssl-fips-provider
		rpm -e --nodeps redhat-logos
		rpm -e --nodeps redhat-release
		rpm --import https://shell.nuoyis.net/download/RPM-GPG-KEY-Rocky-9
		manager::download https://shell.nuoyis.net/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
		manager::download https://shell.nuoyis.net/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
		manager::download https://shell.nuoyis.net/download/rocky-repos-9.5-1.2.el9.noarch.rpm
		manager::download https://shell.nuoyis.net/download/rocky-release-9.5-1.2.el9.noarch.rpm
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
		# manager::yum install https://shell.nuoyis.net/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm https://shell.nuoyis.net/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
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
	fi

	echo "正在更新源"
	rm -rf /etc/yum.repods.d/*.rpmsave
	manager::yum clean
	manager::yum update
	manager::yum makecache
}

install::kernel(){
echo "内核更最新"
if [ $PM = "yum" ];then
manager::yum installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml.x86_64
manager::yum remove kernel-tools-libs.x86_64 kernel-tools.x86_64
manager::yum installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml-tools.x86_64
else
	# https://zichen.zone/archives/debian_linux_kernel_update.html
	manager::yum install linux-image-amd64 linux-headers-amd64
fi
cat > /nuoyis-server/shell/kernel-update.sh << EOF
#!/bin/bash
yum clean all;
yum upgrade -y;
yes | dnf --disablerepo=\* --enablerepo=elrepo-kernel update kernel-ml*;
yes | dnf remove --oldinstallonly --setopt installonly_limit=2 kernel;
# 0 0 * * 1 bash /nuoyis-server/shell/kernel-update.sh > /nuoyis-server/logs/update.log 2>&1;
EOF
cat >> /etc/crontab << EOF
0 0 * * 1 bash /nuoyis-server/shell/kernel-update.sh > /nuoyis-server/logs/update.log 2>&1;
EOF
}

install::main(){
echo "核心函数检查和安装"
echo "检测hostname是否设置"
HOSTNAME_CHECK=$(cat /etc/hostname)
if [ -z $HOSTNAME_CHECK ];then
	echo "当前主机名hostname为空，设置默认hostname"
	hostnamectl set-hostname $nuname-init-shell
fi

echo "正在检查版本是否支持"
if [ $PM == "yum" ] && [ $system_name != "openEuler" ];then
	if [ $system_version -lt 9 ];then
		echo "不受支持版本,正在检测你的系统"
		if [ $system_version -eq 8 ] && [ $system_name == "Rocky" ];then
			read -p "是否进行版本更新，否则只提供基础配置(y/n):" options_update
			if [ $options_update == "n" ];then
        		echo "正在退出脚本"
       	 		exit 0
			else
				echo -e "警告！！！"
				echo -e "请保证升级9之前，请先检查是否有重要备份数据，不过本脚本作者精心提醒:生产环境就不要执行脚本了，如果是云厂商只有8版本，且是空白面板可以执行"
				echo -e "重启后需要重新执行该命令操作下一步，如果同意更新请输入y,更新出现任何问题与作者无关"
				read -p "是否进行版本更新，反之退出脚本(y/n):" options_update_again
				if [ $options_update_again == "n" ];then
        			echo "正在退出脚本"
       	 			exit 0
				else
					options_source_installer
					# https://www.rockylinux.cn/notes/strong-rocky-linux-8-sheng-ji-zhi-rocky-linux-9-strong.html
					# 安装 epel 源
					manager::yum epel-release
					
					# 更新系统至最新版
					manager::yum update

					# 安装 rpmconf 和 yum-utils
					manager::yum rpmconf yum-utils
					
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
					manager::yum install kernel
					manager::yum install kernel-core
					manager::yum install shim
					
					# 安装基础环境
					manager::yum installfull group minimal-environment
					
					# 安装 rpmconf 和 yum-utils
					manager::yum install rpmconf yum-utils
					
					# 执行 rpmconf，根据提示一直输入 Y 和回车即可
					rpmconf -a
					
					# 设置采用最新内核引导
					export grubcfg=`find /boot/ -name rocky`
					grub2-mkconfig -o $grubcfg/grub.cfg
					
					# 更新系统
					manager::yum update
					
					# 重启系统
					reboot
				fi
			fi
		elif [ $system_version -eq 7 ] && [ $system_name == "Centos" ];then
			echo "等待更新"
		elif [ $system_version -eq 8 ] && [ $system_name == "Centos" ];then
			echo "等待更新"
		else
			echo "不受脚本支持的系统，请更换后再试"
			exit 1
		fi
	fi
fi

# 检查是否已有 swap 文件存在
swap_file=$(swapon --show=NAME | grep -E '/nuoyis-toolbox-swap')

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
        dd if=/dev/zero of=/nuoyis-toolbox-swap bs=1M count=$swapsize
        chmod 0600 /nuoyis-toolbox-swap
        mkswap -f /nuoyis-toolbox-swap
        swapon /nuoyis-toolbox-swap
        echo "/nuoyis-toolbox-swap    swap    swap    defaults    0 0" >> /etc/fstab
        mount -a
        sysctl -p
    fi
fi

echo "创建临时安装文件夹nuoyis-install"
mkdir -p /nuoyis-install
cd /nuoyis-install

echo "创建$nuname 服务核心文件夹"
mkdir -p /$nuname-server/{openssl,logs,shell}
# for i in 
# touch /$nuname-server/

echo "安装核心软件包"
manager::yum install dnf-plugins-core python3 pip bash-completion vim git wget net-tools tuned dos2unix gcc gcc-c++ make unzip perl perl-IPC-Cmd perl-Test-Simple pciutils
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

help::main(){
IFS=$'\n' read -r -d '' -a help_lines <<'EOF'
  -n, --name           yum name and folder name
  -host,--hostname     default is options_toolbox_init,so you have use this options before install
  -r,  --mirror        yum mirrors update,if you not used, it will not be executed. Options: edu aliyun other
  -ln, --lnmp          install nuoyis version lnmp. Options: gcc docker yum
  -bt, --btpanelenable install bt panel
  -tu, --tuning	       linux system tuning
  -ku, --kernelupdate  use elrepo to update kernel
  -sw, --swap          Swap allocation, when your memory is less than 1G, it is forced to be allocated, when it is greater than 1G, it can be allocated by yourself
  -mp, --mysqlpassword nuoyis-lnmp-np password set  
  -do, --dockerinstall install docker
  -doa, --dockerapp    install docker app (qinglong and alist ...)
  -na, --nas           install vsftpd nginx and nfs
  -oll, --ollama       install ollama
  -h,  --help          show shell help
EOF

echo "use: $0 [command]..."
echo
echo "command:"
# 遍历并输出
for line in "${help_lines[@]}"; do
    echo "$line"
done
exit 0
}

[ "$#" == "0" ] && help::main

# 参数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            nuname=$2
            shift 2
            ;;
        -host|--hostname)
            hostnamectl set-hostname $2
            shift 2
            ;;
        -r|--mirror)
            if [[ "$2" != "aliyun" && "$2" != "edu" && "$2" != "other" ]]; then
                echo "unknown volume: $2"
                help::main
                exit 1
            fi
            options_yum_install=$2
            options_yum=1
            # conf::yumsource
            shift 2
            ;;
        -ln|--lnmp)
            if [[ "$2" != "gcc" && "$2" != "docker" && "$2" != "yum" ]]; then
                echo "unknown volume: $2"
                help::main
                exit 1
            fi
            options_lnmp_value=$2
            options_lnmp=1
            # install::lnmp
            shift 2
            ;;
		-tu|--tuning)
			options_tuning=1
			shift
			;;
		-ku|--kernelupdate)
			options_kernel_update=1
			shift
			;;
        -sw|--swap)
            options_swap_value=$2
            options_swap=1
            shift 2
            ;;
        -mp|--mysqlpassword)
            options_mariadb_value=$2
            shift 2
            ;;
        -do|--dockerinstall)
            # install::docker
            options_docker=1
            shift
            ;;
        -doa|--dockerapp)
            # install::docker
            options_docker_app=1
            shift
            ;;
        -na|--nas)
            # install::nas
            options_nas=1
            shift
            ;;
        -oll|--ollama)
            options_ollama=1
            shift
            ;;
        -bt|--btpanelenable)
            options_bt=1
            shift
            ;;
        -h|--help)
            help::main
            ;;
        -*)
            echo "unknown command: $1"
            help::main
            ;;
        *)
            echo "unknown Options: $1"
            help::main
            ;;
    esac
done

# root判断
echo "检测是否是root用户"
if [ $whois != "root" ];then
	echo "非root用户，无法满足初始化需求"
	exit 1
fi

# 下面开始依据变量值执行函数
if [[ "${options_yum:-0}" -eq 1 ]]; then
  conf::yumsource
fi

install::main

if [[ "${options_bt:-0}" -eq 1 ]]; then
  install::bt
fi

if [[ "${options_kernel_update:-0}" -eq 1 ]]; then
  install::kernel
fi

if [[ "${options_tuning:-0}" -eq 1 ]]; then
  conf::tuning
fi

if [[ "${options_lnmp:-0}" -eq 1 ]]; then
  if [ $options_lnmp_value == "docker" ];then
	install::docker
  fi
  install::lnmp
fi

if [[ "${options_docker:-0}" -eq 1 ]]; then
  install::docker
fi

if [[ "${options_docker_app:-0}" -eq 1 ]]; then
  install::dockerapp
fi

if [[ "${options_nas:-0}" -eq 1 ]]; then
  if [ -z $options_lnmp ];then
  	options_lnmp_value=gcc
  	install::lnmp
  fi
  install::nas
fi

if [[ "${options_ollama:-0}" -eq 1 ]]; then
  install::ollama
fi