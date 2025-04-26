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

  安装方法

  ```
  curl -L -o /usr/bin/toolbox https://shell.nuoyis.net/nuoyis-linux-toolbox.sh
  chmod +x /usr/bin/toolbox
  ```

  部分使用案例(设置全局自定义名，设置主机名，使用阿里源，安装lnmp版本docker，安装docker常用的app, 更新最新内核并自动更新，调优)

  ```
  toolbox -n nuoyis -host nuoyis -r aliyun -ln docker -doa -ku -tu
  ```

  

3. Ubuntu root登录解锁脚本  
  一个解锁ubuntu root的小脚本  
  执行命令:  
```
curl -sSO https://shell.nuoyis.net/ubuntu-rootstart.sh;bash ubuntu-rootstart.sh
```

3. centos stream 9转rocky （国内机器优化版）

   ```
   curl -sSO https://shell.nuoyis.net/migrate2rocky9.sh;bash migrate2rocky9.sh -r
   ```

   
