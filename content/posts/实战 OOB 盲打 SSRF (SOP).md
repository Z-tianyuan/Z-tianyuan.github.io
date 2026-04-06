---
title: 实战 OOB 盲打 SSRF (SOP)
date: 2026-04-06T17:03:57+08:00
draft: false
categories:
  - 漏洞挖掘
tags:
  - 实战复现
  - Web安全
---

**实战 OOB 盲打 SOP（使用 webhook.site）：**

1. **备好监控器：** 浏览器打开 `https://webhook.site/`，复制它给你生成的那串唯一的 URL（比如 `https://webhook.site/1234abcd-56ef...`）。
    
2. **抓包换弹（对应教程第 1、2 步）：**
    
    - 拦截浏览“产品页面”的请求，送到 Repeater。
        
    - 找到 HTTP 头部的 `Referer` 字段（原本应该是类似 `Referer: https://0ab...web-security-academy.net/`）。
        
    - **把后面的网址全部删掉，贴上你的监控器地址！**
        
    - 修改后变成：`Referer: https://webhook.site/1234abcd-56ef...`
        
3. **发射与静默（对应教程第 3 步）：** 点击 Send 发送请求。Burp 的 Response 窗口会像往常一样返回一个正常的网页代码（盲 SSRF 的特点，不报错，不回显）。
    
4. **见证奇迹（对应教程第 4 步）：** 切回你的 `webhook.site` 网页。如果屏幕左侧突然多出了一条请求记录，点开一看，是从一台陌生的服务器 IP 发过来的 HTTP 请求——**绝杀！** 你成功证明了目标服务器存在严重的 SSRF 漏洞！