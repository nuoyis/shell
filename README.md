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
2. Ubuntu root登录解锁脚本  
一个解锁ubuntu root的小脚本  
执行命令:  
```
curl -sSO https://shell.nuoyis.net/ubuntu-rootstart.sh;bash ubuntu-rootstart.sh
```

3. centos stream 9转rocky （国内机器优化版）

   ```
   curl -sSO https://shell.nuoyis.net/migrate2rocky9.sh;bash migrate2rocky9.sh -r
   ```

   
