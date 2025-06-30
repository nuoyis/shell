#!/bin/bash
# 诺依阁-初始化脚本
# 脚本run --> 起始点

echo -e "=================================================================="
echo -e "     诺依阁服务器初始化脚本"
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
echo "环境配置问答"
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

shellinit="nuoyis-toolbox"
case $nuoyis_yum_install in
	1)
	shellinit+=" -r edu"
	;;
	2)
	shellinit+=" -r aliyun"
	;;
	3)
	shellinit+=" -r other"
	;;
	*)
    echo "error"
esac

# 安装宝塔
if [ $nuoyis_bt == "y" ];then
	shellinit+=" -bt"
fi

# 安装lnmp
if [ $nuoyis_lnmp == "y" ];then
	case $nuoyis_lnmp_install_yn in
		1)
		shellinit+=" -ln yum"
		;;
		2)
		shellinit+=" -ln gcc"
		;;
		3)
		shellinit+=" -ln docker"
		;;
		*)
        echo "error"
	esac
fi

# 安装nas环境
if [ $nuoyis_nas_go == "y" ];then
	shellinit+=" -na"
fi

# 安装docker
if [ $nuoyis_docker == "y" ];then
	shellinit+=" -do"
fi

echo "初始化命令(可保存): $shellinit"
echo "10秒后开始安装"
sleep 10
$shellinit
rm -rf ./nuoyis-init.sh
rm -rf /nuoyis-install
echo "安装完毕，向前出发吧"