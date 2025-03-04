# !/bin/sh
# 诺依阁-初始化脚本
LANG=en_US.UTF-8
#变量定义区域
#手动变量定义区域
auth="nuoyis"
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
		setenforce 0
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
	fi
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
			for nuoyis_start in ${@:2}
			do
				systemctl enable --now $nuoyis_start
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

# 源安装/更新函数
nuoyis_install_manger(){
	case $1 in
		"remove")
			# 移除指定的软件包
			yes | $PM autoremove $2 -y
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

# nas配置类
nuoyis_nas_install(){
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
useradd nuoyis-file
mkdir -p /nuoyis-server/sharefile
chown -R nuoyis-file:nuoyis-file /nuoyis-server/sharefile
chown root:nuoyis-file /nuoyis-server/sharefile
chmod -R 775 /nuoyis-server/sharefile
# chmod g+s /nuoyis-server/sharefile
# 额外配置
nuoyis_install_manger install vsftpd samba*

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
anon_root=/nuoyis-server/sharefile
chown_uploads=YES
chown_username=nuoyis-file

# 系统用户登录
local_enable=YES
local_umask=022
local_root=/nuoyis-server/sharefile
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
        path = /nuoyis-server/sharefile
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
echo "#  Welcome  to  nuoyis's  NAS  #"
echo "################################"
EOF

cat > /$auth-server/nginx/conf/default.conf << EOF
server {
		listen 80;
       	# listen [::]:80;
		# listen 443 ssl;
		server_name localhost;
		#charset koi8-r;
		charset utf-8;
	location /nuoyisnb {
                alias /nuoyis-server/sharefile;
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
        
        #      aio on;                               # 启用异步传输
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
nuoyis_systemctl_manger start vsftpd smb nmb
}

# lnmp安装类
nuoyis_lnmp_install(){
	echo "安装lnmp"
	echo "正在测试中，请晚些时候再执行"
	sleep 30
	if [ $PM = "yum" ];then
	    if [ $nuoyis_lnmp_install_yn -ne "3" ];then
		nuoyis_install_manger install pcre pcre-devel zlib zlib-devel libxml2 libxml2-devel readline readline-devel ncurses ncerses-devel perl-devel perl-ExtUtils-Embed
		aboutserver=`systemctl is-active firewalld`
		if [ $aboutserver == "inactive" ];then
			nuoyis_systemctl_manger start firewalld
		fi
		firewall-cmd --set-default-zone=public
		firewall-cmd --zone=public --add-service=http --per
		firewall-cmd --zone=public --add-port=3306/tcp --per
		firewall-cmd --reload
		fi
		if [ $nuoyis_lnmp_install_yn = "1" ];then
			# 快速安装
			yes | dnf module reset php
			yes | dnf module install php:remi-8.2
			nuoyis_install_manger install nginx* php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-redis mariadb-server
			nuoyis_systemctl_manger start nginx php-fpm mariadb
			# ln -sf 
		elif [ $nuoyis_lnmp_install_yn = "2" ];then
			# 编译安装
			echo "创建lnmp基础文件夹"
			mkdir -p /$auth-server/{logs/nginx,nginx/{webside,server,conf},php/{server,conf},mysql}
			touch /nuoyis-server/logs/nginx/nginx.pid
			id -u nuoyis_web >/dev/null 2>&1
			if [ $? -eq 1 ];then
				useradd nuoyis_web -s /sbin/nologin -M
			fi;
			echo "安装依赖项"
			nuoyis_install_manger install gd gd-devel.x86_64 bzip2 bzip2-devel libcurl libcurl-devel* libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel gmp gmp-devel readline readline-devel libxslt libxslt-devel net-snmp-devel* libtool sqlite-devel* make expat-devel autoconf automake libxml* sqlite* bzip2-devel libcurl* net*
			# --with-openssl=${nuoyis_openssl}
			nuoyis_download_manager https://mirrors.huaweicloud.com/nginx/nginx-1.27.0.tar.gz
			nuoyis_download_manager https://alist.nuoyis.net/d/blog/linux%E8%BD%AF%E4%BB%B6%E5%8C%85%E5%8A%A0%E9%80%9F/php/php-8.4.2.tar.gz
			tar -xzvf nginx-1.27.0.tar.gz
			tar -xzvf php-8.4.2.tar.gz
			cd nginx-1.27.0
			sed -i 's/#define NGINX_VERSION\s\+".*"/#define NGINX_VERSION      "1.27.0"/g' ./src/core/nginx.h
            sed -i 's/"nginx\/" NGINX_VERSION/"nuoyis server"/g' ./src/core/nginx.h
            sed -i 's/Server: nginx/Server: nuoyis server/g' ./src/http/ngx_http_header_filter_module.c
            sed -i 's/"Server: " NGINX_VER CRLF/"Server: nuoyis server" CRLF/g' ./src/http/ngx_http_header_filter_module.c
            sed -i 's/"Server: " NGINX_VER_BUILD CRLF/"Server: nuoyis server" CRLF/g' ./src/http/ngx_http_header_filter_module.c
            ./configure --prefix=/nuoyis-web/nginx/server/1.27.0 \
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
			chmod +x /nuoyis-server/nginx/server/sbin/nginx
			cd ../php-8.4.2
			./configure --prefix=/nuoyis-web/php/8.4.2/ \
                --enable-static \
                --disable-shared \
                --with-config-file-path=/nuoyis-web/php/8.4.2/etc/ \
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
                --enable-static \
                --enable-ctype \
                --enable-mysqlnd \
                --enable-session
		    make -j$(nproc) && make install
			cd ..
			touch /$auth-server/logs/nginx/{error.log,nginx.pid}
			# rm -rf ./nginx-1.27.0
			# rm -rf ./nginx-1.27.0.tar.gz
			cat > /$auth-server/nginx/server/conf/nginx.conf << EOF
	worker_processes  1;

	error_log  /nuoyis-server/logs/nginx/error.log;

	pid        /nuoyis-server/logs/nginx/nginx.pid;


	events {
		worker_connections  1024;
	}


	http {
		include       mime.types;
		default_type  application/octet-stream;

		log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
		                  '\$status \$body_bytes_sent "\$http_referer" '
		                  '"\$http_user_agent" "\$http_x_forwarded_for"';

		access_log  /nuoyis-server/logs/access.log  main;

		sendfile        on;
		tcp_nopush     on;

		# keepalive_timeout  0;
		keepalive_timeout  65;
		# type_hash_max_size 4096;
		
		gzip on;
		include /$auth-server/nginx/conf/*.conf;
	}
EOF

	cat > /$auth-server/nginx/conf/default.conf << EOF
	server {
		listen 80;
        # listen [::]:80;
		# listen 443 ssl;
		server_name _;

		#charset koi8-r;
		charset utf-8;
		#access_log  logs/host.access.log  main;

		location / {
			root   /$auth-server/nginx/webside/default;
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

curl -L -o /nuoyis-web/nginx/server/1.27.0/conf/nginx.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/nginx.conf.txt && \
curl -L -o /nuoyis-web/nginx/webside/default/index.html https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/index.html && \
curl -L -o /nuoyis-web/nginx/server/1.27.0/conf/ssl/default.pem https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/ssl/default.pem && \
curl -L -o /nuoyis-web/nginx/server/1.27.0/conf/ssl/default.key https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/ssl/default.key && \
curl -L -o /nuoyis-web/nginx/server/1.27.0/conf/start-php-84.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/start-php-84.conf.txt && \
curl -L -o /nuoyis-web/nginx/server/1.27.0/conf/path.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/path.conf.txt && \
curl -L -o /nuoyis-web/nginx/server/1.27.0/conf/start-php-81.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/start-php-81.conf.txt && \
curl -L -o /nuoyis-web/php/8.4.2/etc/php.ini https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/84php.ini.txt && \
curl -L -o /nuoyis-web/php/8.4.2/etc/php-fpm.d/fpm.conf https://alist.nuoyis.net/d/blog/nuoyis-lnmp-np/%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6/v1.30/fpm-84.conf.txt && \

ln -s /$auth-server/nginx/server/sbin/nginx /usr/local/bin/
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
		nuoyis_systemctl_manger start nginx

		else
		   mkdir -p /nuoyis-server/web/{docker-yaml,nginx/{conf,webside/default,ssl},mariadb/{init,server,import,config}}
           nuoyis_docker_install
		   useradd -M -s /sbin/nologin nuoyis-web
		   read -p "请输入mariadb root密码:" nuoyis_docker_install_mariadb
		   cat > /nuoyis-server/web/docker-compose.yaml << EOF
version: '2.2.2'
services:
  nuoyis-lnmp-np:
    container_name: nuoyis-lnmp-np
    image: swr.cn-north-4.myhuaweicloud.com/nuoyis/nuoyis-lnp:v1.32
    networks: 
      nuoyis-net:
        aliases:
          - nuoyis-lnp
    ports:
      - 80:80
      - 443:443
    volumes:
      - /nuoyis-server/web/nginx/conf:/nuoyis-web/nginx/conf
      - /nuoyis-server/web/nginx/webside:/nuoyis-web/nginx/webside
      - /nuoyis-server/web/nginx/ssl:/nuoyis-web/nginx/ssl
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
    image: mariadb:latest
    networks: 
      nuoyis-net:
        aliases:
          - nuoyis-mariadb
    environment:
      TIME_ZONE: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: "$nuoyis_docker_install_mariadb"
    volumes:
      - /nuoyis-server/web/mariadb/init/init.sql:/docker-entrypoint-initdb.d/init.sql
      - /nuoyis-server/web/mariadb/server:/var/lib/mysql
      - /nuoyis-server/web/mariadb/import:/nuoyis-web/mariadb/import
      - /nuoyis-server/web/mariadb/config/my.cnf:/etc/mysql/my.cnf
    ports:
      - 3306:3306
    healthcheck:
      test: ["CMD", "sh", "-c", "mariadb -u root -p$\$MYSQL_ROOT_PASSWORD -e 'SELECT 1 FROM information_schema.tables LIMIT 1;'"]
      interval: 30s
      retries: 3
      start_period: 10s
      timeout: 10s
    restart: always
  nuoyis-lnmp-autoheal:
    container_name: nuoyis-lnmp-autoheal
    image: willfarrell/autoheal
    environment:
      - AUTOHEAL_CONTAINER_LABEL=all
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
networks:
  nuoyis-net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.223.0/24
          gateway: 192.168.223.1
EOF
cat > /nuoyis-server/web/nginx/webside/default/index.html << EOF
welcome to nuoyis's server
EOF
cat > /nuoyis-server/web/mariadb/config/my.cnf << EOF
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_format=ROW
slave_skip_errors=1062
EOF
    docker rm -f nuoyis-lnmp-np
	docker rm -f nuoyis-lnmp-mariadb
	docker rm -f nuoyis-lnmp-autoheal
    docker-compose -f /nuoyis-server/web/docker-compose.yaml up -d
    	fi
	else
		nuoyis_install_manger install apt-transport-https dirmngr software-properties-common ca-certificates libgd-dev libgd2-xpm-dev nginx mariadb-server mariadb-client php8.2 php8.2-mysql php8.2-fpm php8.2-gd php8.2-xmlrpc php8.2-curl php8.2-intl php8.2-mbstring php8.2-soap php8.2-zip php8.2-ldap php8.2-xsl php8.2-opcache php8.2-cli php8.2-xml php8.2-common
	fi
}

# docker安装类
nuoyis_docker_install(){
	echo "安装Docker"
	if [ $PM = "yum" ];then
	nuoyis_install_manger install yum-utils device-mapper-persistent-data lvm2
	nuoyis_install_manger repoadd https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	fi
	sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
	if [ $system_name == "openEuler" ];then
		sed -i 's+$releasever+8+'  /etc/yum.repos.d/docker-ce.repo
	fi
	nuoyis_install_manger makecache
	nuoyis_install_manger install docker-ce docker-ce-cli containerd.io docker-compose-plugin
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
	nuoyis_systemctl_manger start docker
	curl -L "https://hub.gitmirror.com/https://github.com/docker/compose/releases/download/v2.32.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose && chmod +x /usr/bin/docker-compose
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

	# 判断源站
	if [ "$nuoyis_yum_install" -ne 1 ] && [ "$nuoyis_yum_install" -ne 2 ]; then
		nuoyis_download_manager https://3lu.cn/main.sh
		source main.sh
		echo "yes"
	else
		if [ $system_name != "openEuler" ];then
			if [ ! -d /etc/yum.repos.d/bak ];then
				mkdir -p /etc/yum.repos.d/bak
			fi
			mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null
			mv -f /etc/yum.repos.d/*.repo.* /etc/yum.repos.d/bak/ 2>/dev/null
			if [ $nuoyis_yum_install -eq 1 ];then
				yumurl="mirrors.jcut.edu.cn"
				if [ $system_name = "Rocky" ]; then
					osname="rocky"
				fi
			else
				yumurl="mirrors.aliyun.com"
				if [ $system_name = "Rocky" ]; then
					osname="rockylinux"
				fi
			fi
				cat > /etc/yum.repos.d/$auth.repo << EOF
[${auth}-BaseOS]
name=${auth} - BaseOS
baseurl=https://${yumurl}/${osname}/${osversion}/BaseOS/\$basearch/os/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-baseos-debuginfo]
name=${auth} - BaseOS - Debug
baseurl=https://${yumurl}/${osname}/${osversion}/BaseOS/\$basearch/debug/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-baseos-source]
name=${auth} - BaseOS - Source
baseurl=https://${yumurl}/${osname}/${osversion}/BaseOS/source/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-appstream]
name=${auth} - AppStream
baseurl=https://${yumurl}/${osname}/${osversion}/AppStream/\$basearch/os/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-appstream-debuginfo]
name=${auth} - AppStream - Debug
baseurl=https://${yumurl}/${osname}/${osversion}/AppStream/\$basearch/debug/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-appstream-source]
name=${auth} - AppStream - Source
baseurl=https://${yumurl}/${osname}/${osversion}/AppStream/source/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-crb]
name=${auth} - CRB
baseurl=https://${yumurl}/${osname}/${osversion}/CRB/\$basearch/os/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-crb-debuginfo]
name=${auth} - CRB - Debug
baseurl=https://${yumurl}/${osname}/${osversion}/CRB/\$basearch/debug/tree/
gpgcheck=1
gpgkey=https://${yumurl}/${osname}/RPM-GPG-KEY-${system_name}-\$releasever
enabled=1
countme=1
metadata_expire=6h
priority=1

[${auth}-crb-source]
name=${auth} - CRB - Source
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

			rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
			yum install https://mirrors.aliyun.com/epel/epel-release-latest-9.noarch.rpm https://mirrors.aliyun.com/epel/epel-next-release-latest-9.noarch.rpm https://mirrors.cernet.edu.cn/elrepo/elrepo/el9/x86_64/RPMS/elrepo-release-9.0-1.el9.elrepo.noarch.rpm -y
			rm -rf /etc/yum.repos.d/epel-cisco-openh264.repo
			sed -e 's!^metalink=!#metalink=!g' \
			-e 's!^#baseurl=!baseurl=!g' \
			-e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.aliyun.com/epel!g' \
			-e 's!https\?://download\.example/pub/epel!https://mirrors.aliyun.com/epel!g' \
			-i /etc/yum.repos.d/epel{,*}.repo
			sed -e 's/http:\/\/elrepo.org\/linux/https:\/\/mirrors.aliyun.com\/elrepo/g' \
			    -e 's/mirrorlist=/#mirrorlist=/g' \
				-i /etc/yum.repos.d/elrepo.repo
			nuoyis_install_manger install https://shell.nuoyis.net/download/remi-release-9.rpm
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
		nuoyis_download_manager https://3lu.cn/main.sh
		source main.sh
		echo "yes"
	fi
	

	# 红帽系统特调
	if [ $system_name == "Red" ];then
		echo "正在对RHEL系统进行openssl系统特调"
		nuoyis_install_manger remove subscription-manager-gnome     
		nuoyis_install_manger remove subscription-manager-firstboot     
		nuoyis_install_manger remove subscription-manager
		rpm -e --nodeps openssl-fips-provider
		rpm -e --nodeps redhat-logos
		rpm -e --nodeps redhat-release
		rpm --import https://shell.nuoyis.net/download/RPM-GPG-KEY-Rocky-9
		nuoyis_download_manager https://shell.nuoyis.net/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm
		nuoyis_download_manager https://shell.nuoyis.net/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
		nuoyis_download_manager https://shell.nuoyis.net/download/rocky-repos-9.5-1.2.el9.noarch.rpm
		nuoyis_download_manager https://shell.nuoyis.net/download/rocky-release-9.5-1.2.el9.noarch.rpm
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
		# nuoyis_install_manger install https://shell.nuoyis.net/download/openssl-devel-3.0.7-27.el9.0.2.x86_64.rpm https://shell.nuoyis.net/download/openssl-libs-3.0.7-27.el9.0.2.x86_64.rpm
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
	nuoyis_install_manger clean
	nuoyis_install_manger update                              
	nuoyis_install_manger makecache
	# fi
}


# 脚本run --> 起始点

echo -e "=================================================================="
echo -e "     诺依阁服务器初始化脚本V4.0"
echo -e "     更新时间:2025.02.22"
echo -e "     博客地址:https://blog.nuoyis.net"
echo -e "     \e[31m\e[1m注意1:执行本脚本即同意作者方不承担执行脚本的后果 \e[0m"
echo -e "     \e[31m\e[1m注意2:当前脚本pid为$$,如果卡死请执行kill -9 $$ \e[0m"
echo -e "=================================================================="
# 获取命令行参数
nuoyis_go=$1
nuoyis_yum_install=$2
nuoyis_bt=$3
nuoyis_nas_go=$4
nuoyis_lnmp=$5
nuoyis_lnmp_install_yn=$6
nuoyis_docker_install=$7
if [ -z "$nuoyis_go" ];then
   read -p "是否继续执行(y/n):" nuoyis_go
fi
if [ $nuoyis_go == "n" ];then
        echo "正在退出脚本"
        exit 0
fi

echo "创建临时文件夹"
mkdir -p /nuoyis-install
cd /nuoyis-install

echo "检测是否是root用户"
if [ $whois != "root" ];then
	echo "非root用户，无法满足初始化需求"
	exit 1
fi

# 检查是否已有 swap 文件存在
swap_file=$(swapon --show=NAME | grep -E '/nuoyis-swap')

if [ -n "$swap_file" ];then
	echo "虚拟内存已存在"
else
	echo "设置虚拟内存"
	memory=`free -m | awk '/^Mem:/ {print $2}'`
	if [ $memory -lt 2048 ];then
		if [ $memory -lt 1024 ];then
			memory=1024
		else
			memory=2048
		fi
		swapsize=$[memory*2];
		cat > /etc/sysctl.conf << EOF
	$(egrep -v '^vm.swappiness' /etc/sysctl.conf)
EOF
		echo "vm.swappiness=60" >> /etc/sysctl.conf
	else
		swapsize=4096;
	fi
	dd if=/dev/zero of=/nuoyis-swap bs=1M count=$swapsize
	chmod 0600 /nuoyis-swap
	mkswap -f /nuoyis-swap
	swapon /nuoyis-swap
	echo "/nuoyis-swap    swap    swap    defaults    0 0" >> /etc/fstab
	mount -a
	sysctl -p
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
if [ $PM == "yum" ] && [ $system_name != "openEuler" ];then
	if [ $system_version -lt 9 ];then
		echo "不受支持版本,正在检测你的系统"
		if [ $system_version -eq 8 ] && [ $system_name == "Rocky" ];then
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
					nuoyis_install_manger epel-release
					
					# 更新系统至最新版
					nuoyis_install_manger update

					# 安装 rpmconf 和 yum-utils
					nuoyis_install_manger rpmconf yum-utils
					
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
					nuoyis_install_manger install kernel
					nuoyis_install_manger install kernel-core
					nuoyis_install_manger install shim
					
					# 安装基础环境
					nuoyis_install_manger installfull group minimal-environment
					
					# 安装 rpmconf 和 yum-utils
					nuoyis_install_manger install rpmconf yum-utils
					
					# 执行 rpmconf，根据提示一直输入 Y 和回车即可
					rpmconf -a
					
					# 设置采用最新内核引导
					export grubcfg=`find /boot/ -name rocky`
					grub2-mkconfig -o $grubcfg/grub.cfg
					
					# 更新系统
					nuoyis_install_manger update
					
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

echo "环境提前配置问答"
case $system_name in
	"openEuler")
		nuoyis_yum_install=2
	;;
	"Ubuntu")
		nuoyis_yum_install=3
	;;
	"Debian")
		nuoyis_yum_install=3
	;;
	*)
	    if [ -z "$nuoyis_yum_install" ]; then
		read -p "必选项:配置校园镜像站还是阿里源还是第三方配源(1校园，2阿里，3三方)：" nuoyis_yum_install
        fi
		# 验证输入是否合法
		while [[ ! "$nuoyis_yum_install" =~ ^[1-3]$ ]]; do
			echo "无效输入，请输入 1、2 或 3 作为有效选项。"
			read -p "必选项:配置校园镜像站还是阿里源还是第三方配源 (1校园，2阿里，3三方): " nuoyis_yum_install
		done
		;;
esac

if [ -z "$nuoyis_bt" ];then
   read -p "附加项:是否安装/重装宝塔面板(y/n):" nuoyis_bt
fi
if [ $nuoyis_bt == "y" ];then
	echo "宝塔启动安装后，则请在宝塔内安装其他附加环境,将不再提醒其他环境"
	echo -e "\e[31m\e[1m注意:国内版宝塔安装完毕后，请执行bt 输入5修改密码，6修改用户名,bt命令后14查看默认信息\e[0m"
	read -p "请按任意键继续" nuoyis_go
	nuoyis_lnmp=n
	nuoyis_docker=n
	nuoyis_nas_go=n
else
    if [ -z "$nuoyis_nas_go" ];then
	read -p "附加项:是否安装NAS配套环境:" nuoyis_nas_go
	fi
	if  [ $nuoyis_nas_go == "y" ];then
		echo -e "\e[31m\e[1m注意:建议局域网使用，NAS系统安装vsftpd,lnmp环境,docker环境以及samba.目录将配置为:/nuoyis-server/sharefile\e[0m"
		read -p "请按任意键继续" nuoyis_go
		nuoyis_lnmp=y
		nuoyis_lnmp_install_yn=2
		nuoyis_docker=y
	else
	    if [ -z "$nuoyis_lnmp" ];then
		   read -p "附加项:是否安装LNMP环境(y/n):" nuoyis_lnmp
		fi
		if [ $nuoyis_lnmp == "y" ];then
		    if [ -z "$nuoyis_lnmp_install_yn" ];then
			   read -p "请输入是1.快速安装 2.编译安装 3.容器安装 (请输入数字):" nuoyis_lnmp_install_yn
		    fi
			# 验证输入是否合法
			while [[ ! "$nuoyis_lnmp_install_yn" =~ ^[1-3]$ ]]; do
				echo "无效输入，请输入 1、2 或 3 作为有效选项。"
				read -p "请输入安装方式: 1.快速安装 2.编译安装 3.容器安装 (请输入数字): " nuoyis_lnmp_install_yn
			done
		else
		    nuoyis_lnmp_install_yn=0
		fi
		if [ $nuoyis_lnmp_install_yn -ne "3" ];then
		    if [ -z "$nuoyis_docker" ];then
			    read -p "附加项:是否安装Docker(y/n):" nuoyis_docker
			fi
		else
		    nuoyis_docker=n
		fi
	fi
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
nuoyis_install_manger install dnf-plugins-core python3 pip bash-completion vim git wget net-tools tuned dos2unix gcc gcc-c++ make unzip perl perl-IPC-Cmd perl-Test-Simple pciutils

# 来自https://www.rockylinux.cn

echo "正在对系统进行调优"

if [ $PM = "yum" ];then
nuoyis_install_manger installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml.x86_64
nuoyis_install_manger remove kernel-tools-libs.x86_64 kernel-tools.x86_64
nuoyis_install_manger installfull --disablerepo=\* --enablerepo=elrepo-kernel kernel-ml-tools.x86_64
else
	# https://zichen.zone/archives/debian_linux_kernel_update.html
	nuoyis_install_manger install linux-image-amd64 linux-headers-amd64
fi

nuoyis_systemctl_manger start tuned.service
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

# kernel-Version=yum info kernel-ml-tools | grep Version | awk '{print $3}'

# 安装宝塔
if [ $nuoyis_bt == "y" ];then
	nuoyis_bt_install
fi

# 安装lnmp
if [ $nuoyis_lnmp == "y" ];then
	nuoyis_lnmp_install
fi

# 安装nas环境
if [ $nuoyis_nas_go == "y" ];then
	nuoyis_nas_install
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


endTime=`date +%Y%m%d-%H:%M:%S`
endTime_s=`date +%s`
 
sumTime=$[ $endTime_s - $startTime_s ]

# 时间统计作者链接：https://blog.csdn.net/bandaoyu/article/details/115525067
echo "执行完毕，执行时长:$sumTime seconds"                 
cd
rm -rf /nuoyis-install
echo "安装完毕，向前出发吧"