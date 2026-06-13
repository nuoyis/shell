# shell
诺依阁的Linux shell脚本库

# 命令执行介绍和方法  
1. Linux 初始化脚本  

  一个让Linux正确工作在多源环境下，快速初始化系统并填补系统缺失的环境。  
  目前主要适配RHEL9和rocky9和Centos stream 9,debian貌似不太适配，但是可以换源  
  执行命令:  

  ```
  curl -sSO https://shell.nuoyis.net/nuoyis-init.sh;bash nuoyis-init.sh
  ```
2. Linux toolbox

   一个linux工具箱(从初始化脚本独立出来的)  

   安装方法1

   ```
   curl -sSk -o /usr/bin/nuoyis-toolbox https://shell.nuoyis.net/nuoyis-linux-toolbox.sh
   chmod +x /usr/bin/nuoyis-toolbox
   ```

   安装方法2

   ``` 
   bash <(curl -sSLk https://shell.nuoyis.net/nuoyis-linux-toolbox.sh) -install
   ```

   

   部分使用案例(设置全局自定义名，设置主机名，使用阿里源，安装lnmp版本docker，安装docker常用的app, 更新最新内核并自动更新，调优)

     ```
   nuoyis-toolbox -n nuoyis -host nuoyis -r aliyun -ln docker -doa -ku -tu
     ```

   帮助菜单参考(英文版)

   ```
    [root@nuoyis-shanghai ~]# nuoyis-toolbox -help
    welcome to use nuoyis's toolbox
    Blog: https://blog.nuoyis.net
    use: /usr/bin/nuoyis-toolbox [command]...
    
    command:
      -install            install nuoyis toolbox and autoupdate
      -remove             remove nuoyis toolbox and autoupdate
      -ln, -lnmp          install nuoyis version lnmp. Options: gcc docker yum
      -do, -dockerinstall install docker
      -doa, -dockerapp    install docker app (qinglong and openlist ...)
      -na, -nas           install vsftpd nginx and nfs
      -oll, -ollama       install ollama
      -bt, -btpanel       install bt panel
      -k8s, -kubernetes   install kubernetes cluster (require -- sub options)
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
      exam1:           nuoyis-toolbox -n nuoyis -host nuoyis-shanghai-1 -r aliyun -ln docker -tu -mp 123456 -na
      exam2(overseas): nuoyis-toolbox -n nuoyis -host nuoyis-us-1 -r original -ln docker -tu -mp 123456 -na
      exam3(btpanel):  nuoyis-toolbox -n nuoyis -host nuoyis-us-1 -r aliyun -bt
      exam4(k8s multi): nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.35,192.168.20.36,192.168.20.37 --kn 192.168.20.38 --kk 192.168.20.40:16443 --ksk 24 --kp 1 --kd master --kv 1.32.2
      exam5(k8s single):nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.36 --kn 192.168.20.37 --kp 1 --kd master --kv 1.23.1
      exam6(k3s light): nuoyis-toolbox -k3s
    ```

   帮助菜单参考(中文版)

   ```
    [root@nuoyis-shanghai ~]# nuoyis-toolbox -help
    欢迎使用 nuoyis 工具箱
    博客：https://blog.nuoyis.net
    使用方法：/usr/bin/nuoyis-toolbox [命令]...
    
    命令：
    -install              安装 nuoyis-linux-toolbox 到 /usr/bin/toolbox 以及自动更新脚本(可在crontab内删除)
    -remove               卸载 nuoyis-linux-toolbox
    -ln, -lnmp            安装 nuoyis lnmp 版本。选项：gcc docker yum
    -do, -dockerinstall   安装 docker
    -doa, -dockerapp      安装 docker app（qinglong 和 openlist ...）
    -na, -nas             安装 vsftpd、nginx 和 nfs
    -oll, -ollama         安装 ollama
    -bt, -btpanelenable   安装 bt 面板
    -k8s, -kubernetes     安装 kubernetes 集群(需配合下方 --子参数)
    --kv,-k8sversion      设置 k8s 版本 (默认最新)
    --km,-k8smaster       设置 k8s master IP列表 (逗号分隔)
    --kn,-k8snode         设置 k8s node IP列表 (逗号分隔)
    --kk,-k8skeepalived   设置 k8s keepalived VIP:端口
    --ksk,-k8smask        设置 k8s 子网掩码
    --kp,-k8spassword     设置 k8s SSH密码
    --kd,-k8sdevice       设置 k8s 设备类型 (master/node)
    -k3s                  安装 k3s 轻量 kubernetes
    -ku, -kernelupdate    安装使用 elrepo 更新内核
    -n, -name             配置 yum 名称和文件夹名称
    -host,-hostname       配置默认为 options_toolbox_init，因此您必须在安装前使用此参数。
    -r, -mirror           配置 yum 镜像更新，如果您未使用此参数，则不会执行此操作。选项：edu aliyun original other(校园 阿里云 原版 其他)
    -tu, -tuning          配置 Linux 系统调优
    -sw, -swap            配置 Swap 分配，当你的内存小于 1G 时强制分配，大于 1G 时可自行分配
    -mp, -mysqlpassword   配置 nuoyis-lnmp-np 密码设置
    -h, -help             显示 shell 帮助
    -sha, -sha256sum      显示 shell 的 sha256sum
    使用示例：nuoyis-toolbox -n nuoyis -host nuoyis-us-1 -r original -ln docker -ku -tu -mp 123456
    k8s示例(多master)：nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.35,192.168.20.36,192.168.20.37 --kn 192.168.20.38 --kk 192.168.20.40:16443 --ksk 24 --kp 1 --kd master --kv 1.32.2
    k8s示例(单master)：nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.36 --kn 192.168.20.37 --kp 1 --kd master --kv 1.23.1
    k3s示例：nuoyis-toolbox -k3s
    ```

3. Ubuntu root登录解锁脚本  
   一个解锁ubuntu root的小脚本  
   执行命令:  

   ```
   curl -sSO https://shell.nuoyis.net/ubuntu-rootstart.sh;bash ubuntu-rootstart.sh
   ```

4. centos stream 9转rocky （国内机器优化版）

   ```
   curl -sSO https://shell.nuoyis.net/migrate2rocky9.sh;bash migrate2rocky9.sh -r
   ```

5. kubernetes docker/container原版安装

    依托于nuoyis-linux-toolbox初始化打造的项目部署脚本，降低学习时间成本，在测试/学习环境中快速部署kubernetes环境(你也不想看到环境炸了又要重新搭建的痛苦吧)。
    已融合至 nuoyis-toolbox，也可独立使用 k8s-install.sh。

    > 注：kubernetes 多master节点在openstack搭建需要额外步骤需要在controller节点上执行，执行步骤如下:
    >
    > ```
    > # 找到你的network id和subnet id
    > neutron net-list
    > # 输入vip地址 network id和subnet id
    > neutron port-create --fixed-ip subnet_id=1c355e9a-5eb1-46fb-80b3-95ae20d86b9e,ip_address=10.104.43.199 30662a9f-f11f-49fd-a360-b56d4f652996
    > # 根据虚拟机ip找到id号
    > neutron port-list |grep 10.104.43.239
    > neutron port-update 0d127c54-f80d-4198-8007-e2d4af291276 --allowed-address-pair ip_address=10.104.43.199
    > ```

    使用方法1 (nuoyis-toolbox 融合版):

    > 注: 
    >
    > 1. 1.24版本开始是container版本，1.23版本以及之前可以用docker,<1.24版本只能用centos 7.9.2009
    >
    > 2. 不可写错配置，不然执行一半报错，下面示例应该都懂，然后一定是在第一台master上运行，否则必出问题
    >
    > 3. --kd 必写，如果需要加入node节点可以写 --kd node。k8s子参数以 -- 开头，需配合 -k8s 使用
    >
    > 4. 国内公有云可能需要额外添加一个链接公网的虚拟网卡，下面是示例
    >
    >    ```
    >    cat > /etc/sysconfig/network-scripts/ifcfg-eth0:1 <<EOF
    >    DEVICE=eth0:1
    >    BOOTPROTO=static
    >    ONBOOT=yes
    >    IPADDR=公网地址
    >    NETMASK=255.255.255.0
    >    EOF
    >    ```
    >
    >    然后重启网卡
    >
    >    ```
    >    systemctl restart NetworkManager
    >    ```

    多master

    ```
    nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.35,192.168.20.36,192.168.20.37 --kn 192.168.20.38,192.168.20.39 --kk 192.168.20.40:16443 --ksk 24 --kp 1 --kd master --kv 1.32.2
    ```

    单master

    ```
    nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.36 --kn 192.168.20.37 --kp 1 --kd master --kv 1.23.1
    ```

    单master不部署node(云服务器已测试)

    ```
    nuoyis-toolbox -r aliyun -do -k8s --km 192.168.20.36 --kd master --kv 1.33.3
    ```

    k3s轻量版

    ```
    nuoyis-toolbox -k3s
    ```

    使用方法2 (k8s-install.sh 独立脚本):

    ```
    curl -sSO https://shell.nuoyis.net/k8s-install.sh
    ```

    多master

    ```
    bash k8s-install.sh --master 192.168.20.35,192.168.20.36,192.168.20.37 --node 192.168.20.38,192.168.20.39 --keepalived 192.168.20.40:16443 --mask 24 --password 1 --bashdevice master --version 1.32.2
    ```

    单master

    ```
    bash k8s-install.sh --master 192.168.20.36 --node 192.168.20.37 --password 1 --bashdevice master --version 1.23.1
    ```

    单master不部署node(云服务器已测试)

    ```
    bash k8s-install.sh --master 192.168.20.36 --bashdevice master --version 1.33.3
    ```

    
