---
title: "HTB Starting Point - Crocodile 渗透测试报告"
date: 2026-07-12T21:00:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Crocodile", "FTP", "目录枚举", "Web安全"]
---

## HTB Starting Point - Crocodile 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Starting Point / Tier 1 |
| 机器名 | Crocodile |
| 目标 IP | 10.129.142.129 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集（端口扫描）

```bash
nmap -sC -sV -T4 10.129.142.129
```

**扫描结果：**

```
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
80/tcp open  http    Apache httpd 2.4.41 ((Ubuntu))
```

**关键发现：** 21 端口 FTP + 80 端口 Web，两手入口。

---

#### 阶段 2：FTP 匿名登录

```bash
ftp 10.129.142.129
```

用户名 `anonymous`，密码空，直接登录。

```
ftp> ls
allowed.userlist
allowed.userlist.passwd
```

下载两个文件：

```bash
ftp> get allowed.userlist
ftp> get allowed.userlist.passwd
```

**文件内容：**

`allowed.userlist`：
```
aron
pwnmeow
egotisticalsw
admin
```

`allowed.userlist.passwd`：
```
root
Supersecretpassword1
@BaASD&9032123sADS
rKXM59ESxesUFHAd
```

两个文件按行一一对应，共 4 组凭据。

---

#### 阶段 3：目录枚举

使用 Gobuster 枚举 Web 目录：

```bash
gobuster dir -u http://10.129.142.129 -w 字典.txt -x php,html
```

发现 `login.php` 登录页面。

---

#### 阶段 4：Web 登录

从 FTP 泄露的凭据中逐组尝试，最后一组成功：

| 用户名 | 密码 | 结果 |
|--------|------|------|
| admin | rKXM59ESxesUFHAd | 登录成功 |

登录后跳转至 Dashboard，页面显示 flag：

```
c7110277ac44d78b6a9fff2232434d16
```

---

### 三、攻击链总结

```
nmap → 21/tcp FTP + 80/tcp HTTP
         │
         ▼
FTP anonymous 登录 → 下载 allowed.userlist 和 allowed.userlist.passwd
         │
         ▼
Gobuster → 枚举出 login.php
         │
         ▼
admin / rKXM59ESxesUFHAd → 登录成功 → flag
```

---

### 四、FTP 命令速查

| 命令 | 作用 |
|------|------|
| `ftp <IP>` | 连接 FTP 服务器 |
| `anonymous` | 匿名登录用户名 |
| `ls` / `dir` | 列出文件 |
| `get <文件>` | 下载单个文件 |
| `mget *` | 批量下载 |
| `bye` / `quit` | 断开连接 |

---

### 五、Gobuster 目录枚举

| 参数 | 含义 |
|------|------|
| `-u` | 目标 URL |
| `-w` | 字典文件路径 |
| `-x php,html` | 枚举指定后缀 |
| `dir` | 子命令：目录/文件扫描 |

Windows 无 Gobuster 时的替代方案：手动尝试常见路径（login.php、admin.php、dashboard.php 等）。

---

### 六、八台机器总览

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

Crocodile 是第一台"跨服务"的机器：FTP 拿到凭据，HTTP 端使用。真正的漏洞不在单一服务，而在**两个服务之间的信息链**。

---

### 七、修复建议

| 问题 | 建议 |
|------|------|
| FTP 匿名登录 | 关闭匿名访问，或限制目录为仅上传（write-only） |
| 凭证明文存储 | 密码应哈希存储，绝不能明文放 FTP 目录 |
| 登录页可枚举 | 添加速率限制、验证码保护 |
| FTP 与 Web 共享凭据 | 两服务使用独立认证系统 |
