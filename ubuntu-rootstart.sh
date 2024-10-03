#!/bin/bash
clear
echo "欢迎使用ubuntu切换root登陆程序"
echo "博客:<a href="<a href="<a href="https://www.nuoyis.net"""" title="https://www.nuoyis.net"""">https://www.nuoyis.net"""</a> title="<a href="https://www.nuoyis.net""">https://www.nuoyis.net""" title="https://www.nuoyis.net""">https://www.nuoyis.net""">https://www.nuoyis.net""">https://www.nuoyis.net""</a></a> title="<a href="<a href="https://www.nuoyis.net"">https://www.nuoyis.net""" title="https://www.nuoyis.net"">https://www.nuoyis.net""">https://www.nuoyis.net"">https://www.nuoyis.net""</a> title="<a href="https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"" title="https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"">https://www.nuoyis.net"</a></a></a>
if [ "$(whoami)" != "root" ]; then
echo -e "\033[31m 未切换root用户模式 \033[0m"
echo -e "\033[34m 如果是第一次请先执行sudo passwd root ，然后执行su root\033[0m"
else
echo "开始执行，执行完成出现一个done"
cd /etc/ssh
echo "PermitRootLogin yes" >> sshd_config
echo "PermitEmptyPasswords no" >> sshd_config
echo -e "\033[32m done \033[0m"
systemctl restart ssh
fi
