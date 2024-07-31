
# V2Ray 安装和配置脚本

这是一个用于在AlmaLinux 8上安装和配置V2Ray的脚本。该脚本将禁用SELinux，放开指定端口的防火墙规则，安装V2Ray，并配置其使用SOCKS5代理并启用用户名和密码验证。

## 使用方法

您可以通过以下命令运行该脚本：

```bash
curl -sL https://raw.githubusercontent.com/Ediful9/almalinux_socsd/main/V2Ray.sh | sh -s -- --port <PORT> --user <USERNAME> --password <PASSWORD>
```

### 参数说明

- `--port <PORT>`：指定V2Ray使用的端口。
- `--user <USERNAME>`：指定SOCKS5代理的用户名。
- `--password <PASSWORD>`：指定SOCKS5代理的密码。

例如：

```bash
curl -sL https://raw.githubusercontent.com/Ediful9/almalinux_socsd/main/V2Ray.sh | sh -s -- --port 1080 --user myusername --password mypassword
```

## 功能

1. **禁用SELinux**：暂时和永久禁用SELinux以避免对V2Ray的限制。
2. **放开防火墙端口**：使用 `firewall-cmd` 命令放开指定的端口，以允许通过该端口的流量。
3. **安装V2Ray**：下载并安装V2Ray，包括其依赖项和系统服务配置。
4. **配置V2Ray**：编辑 `/usr/local/etc/v2ray/config.json` 文件，设置V2Ray的端口、协议、认证方式和用户信息。
5. **启动V2Ray服务**：启动并使V2Ray服务随系统启动自动运行。

## 验证安装

### 检查V2Ray服务状态

运行以下命令以检查V2Ray服务的状态：

```bash
systemctl status v2ray
```

### 测试SOCKS5代理

使用 `curl` 命令测试SOCKS5代理是否正常工作：

```bash
curl -x socks5://<USERNAME>:<PASSWORD>@127.0.0.1:<PORT> https://www.google.com
```

如果看到返回的HTML内容或Google主页的片段，说明SOCKS5代理配置成功。

## 修改用户

### 修改现有用户的用户名和密码

1. 打开配置文件：

   ```bash
   sudo vi /usr/local/etc/v2ray/config.json
   ```

2. 找到 `accounts` 部分，修改用户名和密码：

   ```json
   "accounts": [
       {
           "user": "newusername",
           "pass": "newpassword"
       }
   ]
   ```

3. 保存文件并退出编辑器。

4. 重启V2Ray服务：

   ```bash
   sudo systemctl restart v2ray
   ```

### 添加用户

1. 打开配置文件：

   ```bash
   sudo vi /usr/local/etc/v2ray/config.json
   ```

2. 在 `accounts` 部分添加新用户：

   ```json
   "accounts": [
       {
           "user": "existinguser",
           "pass": "existingpassword"
       },
       {
           "user": "newuser",
           "pass": "newpassword"
       }
   ]
   ```

3. 保存文件并退出编辑器。

4. 重启V2Ray服务：

   ```bash
   sudo systemctl restart v2ray
   ```

### 删除用户

1. 打开配置文件：

   ```bash
   sudo vi /usr/local/etc/v2ray/config.json
   ```

2. 删除不需要的用户：

   ```json
   "accounts": [
       {
           "user": "remaininguser",
           "pass": "remainingpassword"
       }
   ]
   ```

3. 保存文件并退出编辑器。

4. 重启V2Ray服务：

   ```bash
   sudo systemctl restart v2ray
   ```

## 注意事项

- 确保 `/usr/local/etc/v2ray/config.json` 是服务启动时使用的配置文件路径。
- 每次修改配置文件后，请务必重启V2Ray服务以应用更改。
- 请定期备份您的配置文件以防止意外修改或损坏。

## 许可证

该脚本遵循MIT许可证。

---
