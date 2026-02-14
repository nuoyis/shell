#!/bin/bash
# 诺依阁-kubernetes初始化脚本
# Blog:https://blog.nuoyis.net
# 注：必须在第一台master节点上执行
# bash k8s-install.sh --master 192.168.20.35,192.168.20.36,192.168.20.37 --node 192.168.20.38,192.168.20.39 --keepalived 192.168.20.40:16443 --mask 24 --password 1 --bashdevice master --version 1.32.2
# bash k8s-install.sh --master 192.168.20.36 --node 192.168.20.37 --password 1 --bashdevice master --version 1.23.1
# openstack controller 需要放行vip ip
# neutron net-list
# neutron port-create --fixed-ip subnet_id=1c355e9a-5eb1-46fb-80b3-95ae20d86b9e,ip_address=10.104.43.199 30662a9f-f11f-49fd-a360-b56d4f652996
# neutron port-list |grep 10.104.43.239
# neutron port-update 0d127c54-f80d-4198-8007-e2d4af291276 --allowed-address-pair ip_address=10.104.43.199
networkname=$(ip route | grep default | awk '{print $5}')
current_kernel=$(uname -r | cut -d- -f1)
MIN_KERNEL_VERSION="4.15"
system_name=`head -n 1 /etc/os-release | grep -oP '(?<=NAME=").*(?=")' | awk '{print$1}'`
system_version=`cat /etc/os-release | grep -oP '(?<=VERSION_ID=").*(?=")'`
system_version=${system_version%.*}
keepalived="$(hostname -I | awk '{print $1}' | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)\..*/\1/').199:16443"
is_first_master=false
MIN_VERSION="1.19.0"
MAX_VERSION=$(curl -sk "https://version.nuoyis.net/json/kubernetes.json" | grep -o '"versions"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"//;s/"$//');
# 如果获取失败或为空，使用默认值
if [ -z "$MAX_VERSION" ]; then
    MAX_VERSION="1.34.0"
fi
k8sversion="$MAX_VERSION"
compare_versions() {
    local ver1=$(echo "$1" | sed 's/^v//' | cut -d'-' -f1 | cut -d'+' -f1)
    local ver2=$(echo "$2" | sed 's/^v//' | cut -d'-' -f1 | cut -d'+' -f1)

    local version1=$(echo "$ver1" | awk -F. '{printf("%03d%03d%03d\n", $1, $2, $3)}')
    local version2=$(echo "$ver2" | awk -F. '{printf("%03d%03d%03d\n", $1, $2, $3)}')

    if [ "$version1" -lt "$version2" ]; then
        echo -1
    elif [ "$version1" -gt "$version2" ]; then
        echo 1
    else
        echo 0
    fi
}

install::version() {
    # 输入版本，比如: 1.23.17 / v1.24.3 / 1.24-0 / 1.25
    local input="$1"

    # 去掉前缀 v 或 V
    input="${input#v}"
    input="${input#V}"

    # 去掉可能的 -rc / -beta / -anything
    input="${input%%-*}"
    # 去掉 +build 等
    input="${input%%+*}"

    # 只关心前两个字段 (主.次)
    # 如果没有次版本，补 0
    local major minor
    IFS='.' read -r major minor _ <<< "$input"
    [[ -z "$minor" ]] && minor=0

    # 确保是整数（非数字直接置 0，或你也可以选择报错）
    major=$(echo "$major" | sed 's/[^0-9].*//')
    minor=$(echo "$minor" | sed 's/[^0-9].*//')
    [[ -z "$major" ]] && major=0
    [[ -z "$minor" ]] && minor=0

    # 参考版本
    local ref_major=1
    local ref_minor=24

    # 比较：>=1.24 输出 1 (Containerd)，否则 0 (Docker)
    if (( major > ref_major )) || (( major == ref_major && minor >= ref_minor )); then
        echo "1"
    else
        echo "0"
    fi
}

install::kubernetes(){
    touch /etc/yum.repos.d/kubernetes.repo
    if [ $(install::version $k8sversion) -eq 0 ]; then
        cat > /etc/yum.repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF
    else
        cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v$(echo "$k8sversion" | cut -d'.' -f1,2)/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v$(echo "$k8sversion" | cut -d'.' -f1,2)/rpm/repodata/repomd.xml.key
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
    yum install -y kubelet-$k8sversion kubeadm-$k8sversion kubectl-$k8sversion
    systemctl enable --now kubelet
    cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
}

install::kernel(){
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

conf::kubernetes::join(){
    if [ $device == "master" ];then
        if ! $is_first_master; then
            source /kubernetes-master-join.sh
        fi
		rm -rf $HOME/.kube
        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
		sed -i '/KUBECONFIG/d' /etc/bashrc
        export KUBECONFIG=/etc/kubernetes/admin.conf
        echo "KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/bashrc
        if $is_first_master; then
            if [ "${#mastersip[@]}" -gt 1 ]; then
                systemctl enable --now nginx
            fi
        fi
    else
        source /kubernetes-node-join.sh
    fi
}

conf::kubernetes::docker::init(){
    kubeadm init --kubernetes-version=$k8sversion --apiserver-advertise-address=${mastersip[0]} --image-repository registry.aliyuncs.com/google_containers  --pod-network-cidr=10.223.0.0/16 --ignore-preflight-errors=SystemVerification --ignore-preflight-errors=Mem
}

conf::kubernetes::containerd::init(){
	mkdir -p /etc/systemd/system/kubelet.service.d/
    cat > /etc/systemd/system/kubelet.service.d/nuoyis-init.conf << 'EOF'
[Unit]
After=containerd.service
Requires=containerd.service

[Service]
ExecStartPre=/bin/bash -c '/usr/bin/crictl rm -f $(crictl ps -a -q)'
ExecStartPre=rm -rf /run/containerd/io.containerd.runtime.v2.task/k8s.io/*
ExecStartPre=rm -rf /run/containerd/io.containerd.metadata.v1.bolt/meta.db
EOF
    kubeadm config print init-defaults > kubeadm.yaml
    sed -i -e "s|  criSocket: unix:///var/run/containerd/containerd.sock|  criSocket: unix:///run/containerd/containerd.sock|g" \
           -e "s|imageRepository: registry.k8s.io|imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers|g" \
           -e "/serviceSubnet: 10.96.0.0\\/12/i \\  podSubnet: 10.223.0.0/16" kubeadm.yaml
    if [ "${#mastersip[@]}" -eq 1 ]; then
        sed -i -e "s|  advertiseAddress: 1.2.3.4|  advertiseAddress: ${mastersip[0]}|g" \
               -e "s|  name: node|  name: kubernetes-master1|g" kubeadm.yaml
    else
        sed -i -e "\|^localAPIEndpoint:|,\|^  bindPort:|s|^|# |" \
               -e "\|^[[:space:]]*name: node|s|^|# |" \
               -e "s|imageRepository: registry.k8s.io|imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers|g" \
               -e "\|^kubernetesVersion:|a\controlPlaneEndpoint: $keepalived" kubeadm.yaml
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

    for ip in "${mastersip[@]}"; do
        echo "    server $ip:6443 weight=5 max_fails=3 fail_timeout=30s;" >> /etc/nginx/nginx.conf
    done
    cat >> /etc/nginx/nginx.conf << EOF
    }
    server {
       listen $(echo $keepalived | cut -d':' -f2- | xargs);
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
    interface $networkname
    virtual_router_id 1
    priority 100
    advert_int 1
    authentication { 
        auth_type PASS
        auth_pass k8svip
    }
    virtual_ipaddress { 
        $(echo $keepalived | cut -d':' -f1 | xargs)/$mask
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
    for masterip in "${mastersip[@]:1}"; do
        sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no root@$masterip "mkdir -p /etc/kubernetes/pki/etcd && mkdir -p /root/.kube/"
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/ca.crt root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/ca.key root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/sa.key root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/sa.pub root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/front-proxy-ca.crt root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/front-proxy-ca.key root@$masterip:/etc/kubernetes/pki/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/etcd/ca.crt root@$masterip:/etc/kubernetes/pki/etcd/
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/etcd/ca.key root@$masterip:/etc/kubernetes/pki/etcd/
    done
}

conf::kubernetes(){
    if [[ "$device" == "master" && "$is_first_master" == true ]]; then
		# 重置防止重复安装
		kubeadm reset -f
        if [ $(install::version $k8sversion) -eq 0 ]; then
            conf::kubernetes::docker::init
        else
            conf::kubernetes::containerd::init
        fi
		conf::kubernetes::join
		# 等待配置生效
		sleep 5
		KUBE_MINOR=$(echo "$k8sversion" | awk -F. '{print $2}')
        if [ "$KUBE_MINOR" -lt 21 ]; then
            echo "Kubernetes $k8sversion (<1.21)，安装k8s后部署 Calico v3.19"
            wget -O calico.yaml "https://docs.projectcalico.org/archive/v3.19/manifests/calico.yaml"
			sed -i 's#docker.io/##g' calico.yaml
        else
            echo "Kubernetes $k8sversion (>=1.21)，安装k8s后部署最新 Calico"
			wget -O calico.yaml "https://ghfast.top/https://raw.githubusercontent.com/projectcalico/calico/refs/heads/master/manifests/calico.yaml"
			sed -i -e '/# - name: CALICO_IPV4POOL_CIDR/{
N
N
c\
            - name: CALICO_IPV4POOL_CIDR\
              value: "10.223.0.0/12"\
            - name: IP_AUTODETECTION_METHOD\
              value: "interface='"$networkname"'"
}' \
   			-e 's|docker.io|docker.m.daocloud.io|g' \
   			-e 's|quay.io|quay.dockerproxy.net|g' calico.yaml
        fi
        kubectl apply -f calico.yaml
        if [[ -n "${node_value}" ]]; then
            install::otherserver
        fi
	else
		conf::kubernetes::join
    fi
	sed -i '/kubectl completion bash/d' /etc/bashrc
    echo "source <(kubectl completion bash)" >> /etc/bashrc
    bash /etc/bashrc
}

install::otherserver(){
join_cmd=$(kubeadm token create --print-join-command | grep "kubeadm")
echo "$join_cmd" > kubernetes-node-join.sh
echo "$join_cmd --control-plane --ignore-preflight-errors=SystemVerification" > kubernetes-master-join.sh
all_ips=("${mastersip[@]:1}" "${nodesip[@]}")
nodenumber=1
vipid=90
for nodeip in "${all_ips[@]}"; do
    is_master=false
    for m_ip in "${mastersip[@]}"; do
        if [[ "$nodeip" == "$m_ip" ]]; then
            is_master=true
            break
        fi
    done

	sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no root@$nodeip "rm -rf /k8s-install.sh"
    sshpass -p "$passwd" scp -o StrictHostKeyChecking=no k8s-install.sh root@$nodeip:/
    if $is_master; then
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no kubernetes-master-join.sh root@$nodeip:/kubernetes-master-join.sh
    else
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no kubernetes-node-join.sh root@$nodeip:/kubernetes-node-join.sh
    fi

    kernel_version=$(sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no "root@$nodeip" "uname -r | cut -d- -f1")
    echo "当前部署节点 $nodenumber IP: $nodeip 当前内核版本: $kernel_version"

    if [ $(install::version $k8sversion) -eq 1 ]; then
        if printf "%s\n%s\n" "$MIN_KERNEL_VERSION" "$kernel_version" | sort -V -C; then
            echo "内核版本满足要求，开始安装"
        else
            echo "内核版本过低，开始升级并重启"
        fi
    fi
    sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no root@$nodeip "bash /k8s-install.sh --master $master_value --node $node_value --password $passwd --bashdevice $( $is_master && echo master || echo node ) --version $k8sversion"  
    if $is_master; then
        sshpass -p "$passwd" scp -o StrictHostKeyChecking=no /etc/nginx/nginx.conf root@$nodeip:/etc/nginx/nginx.conf
        sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no root@$nodeip "cat > /etc/keepalived/keepalived.conf << EOF
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
    interface $networkname
    virtual_router_id 1
    priority $vipid
    advert_int 1
    authentication { 
        auth_type PASS
        auth_pass k8svip
    }
    virtual_ipaddress {
        $(echo $keepalived | cut -d':' -f1 | xargs)/$mask
    }
}
EOF"
        sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no root@$nodeip "systemctl enable --now keepalived"
        vipid=$(($vipid-10))
    fi
    if [ $(install::version $k8sversion) -eq 1 ]; then
        if ! printf "%s\n%s\n" "$MIN_KERNEL_VERSION" "$kernel_version" | sort -V -C; then
            echo "等待 $nodeip 重启..."
            sleep 70
            while ! ping -c 1 -W 1 "$nodeip" >/dev/null 2>&1; do
                echo "等待 $nodeip 开机中..."
                sleep 3
            done
            echo "重新执行安装脚本"
            sshpass -p "$passwd" ssh -o StrictHostKeyChecking=no root@$nodeip "bash /k8s-install.sh --master $master_value --node $node_value --password $passwd --bashdevice $( $is_master && echo master || echo node ) --version $k8sversion"
        fi
    fi
    nodenumber=$((nodenumber + 1))
done
}

install::init(){
    systemctl disable --now firewalld
    setenforce 0
    swapoff -a
    yum install nginx keepalived nginx-mod-stream yum-utils device-mapper-persistent-data lvm2 wget bash* net-tools nfs-utils lrzsz gcc gcc-c++ make cmake openssl-devel curl curl-devel unzip sudo libaio-devel wget vim autoconf sshpass automake zlib-devel python-devel epel-release openssh-server chrony -y
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    sed -i '/^\s*server\s\+/d' /etc/chrony.conf
    sed -i '/kubernetes/d' /etc/hosts
    sed -i 's/.*swap.*/#&/' /etc/fstab
    echo "从swap服务层面绝对禁止swap防止k8s开机启动失败"
    systemctl mask swap.target
    sed -i '/^net.bridge.bridge-nf-call-ip6tables/d; /^net.bridge.bridge-nf-call-iptables/d; /^net.ipv4.ip_forward/d' /etc/sysctl.conf
    rm -rf /etc/sysctl.d/kubernetes.conf
    if [[ -n "${node_value}" ]]; then
        if [[ "$device" == "master" && "$is_first_master" == true ]]; then
            nodenumber=1
            for masterip in "${mastersip[@]}"; do
                sshpass -p $passwd ssh -o StrictHostKeyChecking=no root@$masterip "hostnamectl set-hostname kubernetes-master$nodenumber"
                nodenumber=$(($nodenumber+1))
            done
            nodenumber=1
            for nodeip in "${nodesip[@]}"; do
                sshpass -p $passwd ssh -o StrictHostKeyChecking=no root@$nodeip "hostnamectl set-hostname kubernetes-node$nodenumber"
                nodenumber=$(($nodenumber+1))
            done
        fi
        nodenumber=1
        for nodeip in "${nodesip[@]}"; do
            cat >> /etc/hosts << EOF
$nodeip kubernetes-node$nodenumber
EOF
            nodenumber=$(($nodenumber+1))
        done
    fi

    nodenumber=1
    for masterip in "${mastersip[@]}"; do
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

[ "$#" == "0" ] && exit 1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
           k8sversion=$2
           shift 2
           ;;
        -ma|--master)
            if [[ -z "$2" ]]; then
                echo "错误: master 未设置"
                exit 1
            fi
            IFS=',' read -ra mastersip <<< "$2"
            master_value=$2
            shift 2
            ;;
        -no|--node)
            if [[ -n "$2" ]]; then
                IFS=',' read -ra nodesip <<< "$2"
                node_value=$2
            fi
            shift 2
            ;;
        -kl|--keepalived)
            keepalived=$2
            shift 2
            ;;
        -ms|--mask)
            mask=$2
            shift 2
            ;;
        -p|--password)
            if [[ -z "$2" ]]; then
                echo "错误: passwd 未设置"
                exit 1
            fi
            passwd=$2
            shift 2
            ;;
        -bv|--bashdevice)
            if [[ -z "$2" ]]; then
                echo "错误: bashdevice 未设置"
                exit 1
            fi
            device=$2
            shift 2
            ;;
        -*)
            echo "unknown command: $1"
            ;;
        *)
            echo "unknown Options: $1"
    esac
done

if [ $(compare_versions $k8sversion $MIN_VERSION) -lt 0 ]; then
    echo "输入的版本 ($k8sversion) 低于最低支持版本 ($MIN_VERSION)。"
    exit 1
elif [ $(compare_versions $k8sversion $MAX_VERSION) -gt 0 ]; then
    echo "输入的版本 ($k8sversion) 高于最大支持版本 ($MAX_VERSION)。"
    exit 1
else
    if [ $(install::version $k8sversion) -eq 0 ]; then
        if [ $system_version -gt "8" ];then
            echo "8版本以上不支持docker版本"
            exit 1
        fi
    fi
    for ip in $(hostname -I); do
        if [[ "$ip" == "${mastersip[0]}" ]]; then
            is_first_master=true
        break
        fi
    done
    curl -sSk -o /usr/bin/nuoyis-toolbox https://shell.nuoyis.net/nuoyis-linux-toolbox.sh
    chmod +x /usr/bin/nuoyis-toolbox
    nuoyis-toolbox -r aliyun -do
    install::init
    if [ $(install::version $k8sversion) -eq 0 ]; then
        # 删除toolbox内下载的最新版本
        yum remove -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin -y
        yum install docker-ce-19.03.15 docker-ce-cli-19.03.15 -y
    fi
    install::kubernetes
    if [ $(install::version $k8sversion) -eq 1 ]; then
        if [ $system_version == "7" ];then
            echo "当前内核版本: $current_kernel"
            echo "Kubernetes 要求最低版本: $MIN_KERNEL_VERSION"
            if printf "%s\n%s\n" "$MIN_KERNEL_VERSION" "$current_kernel" | sort -V -C; then
                echo "当前内核版本满足 Kubernetes 要求,正在安装kubernetes"
            else
                echo "当前内核版本低于 Kubernetes 要求,需升级内核后重启"
                echo "正在升级内核，会自动重启"
                install::kernel
                exit 0
            fi
        fi
    fi
    conf::kubernetes
fi
