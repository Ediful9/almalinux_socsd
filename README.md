# SOCKS5 代理服务器

这个项目是 Alma Linux 9 的 SOCKS5 代理服务器。

## 功能

## 安装和使用

### 一键安装

你可以使用以下命令通过 `curl` 或 `wget` 安装并运行脚本：

使用 `curl`:

```bash
curl -sL https://raw.githubusercontent.com/Ediful9/almalinux_socsd/main/install.sh | sh -s -- --port 1080
```

使用 wget:

```bash

wget -qO- https://raw.githubusercontent.com/Ediful9/almalinux_socsd/main/install.sh | sh

```

## 配置

# 安装

初次直接运行 ./install

指定端口 ./install --port=1080 指定端口后,需要运行 dante-manage restart 生效

# 创建用户

dante-manage adduser 用户名 密码 
例如: dante-manage adduser testuser ispassword

*注意*: 创建的用户是 linux 上的系统用户,所以无法看到密码,如果需要知道有多少个用户可以执行
ls -l /home 

重启、关闭

dante-manage restart  或 dante-manage stop

# 查看信息

dante-manage status 或 dante-manage stats

# 其他

Socks 服务器配置文件: /etc/sockd.conf


永久禁用SELinux
编辑/etc/selinux/config文件，将SELINUX的值改为disabled：
```bash
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

```





