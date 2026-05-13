---
title: 未命名
date: 2026-05-13T18:26:52+08:00
draft: false
categories:
tags:
---

一、YAML 模板是什么？

  简单类比： 模板就是一个「通缉令」。

  通缉令上写着:
    姓名: 张三
    特征: 左脸有痣、身高180、说四川话
    行动: 去火车站蹲守
    抓到后: 报告"抓获张三"

  Nuclei 模板就是给扫描器下的「漏洞通缉令」：

  id: 漏洞编号                  ← 通缉令编号

  info:
    name: 泛微OA OGNL注入       ← 漏洞名字
    severity: high              ← 危害等级

  http:                         ← 行动指令
    - method: GET
      path: /login.do?message=xxx    ← 去哪查、怎么查

  matchers:                     ← 确认特征
    - type: word
      words: ["计算结果的数字"]        ← 如果看到这个特征 → 通缉成功

  本质上，模板就是两句话：
  1. 往哪发请求（http.method + http.path）
  2. 看到什么算命中（matchers）

  ---
  二、五种匹配方式

  匹配 = 检查服务器的回包。五种方式是五种不同的「检查方法」。

  我先用你的本地 HTTP 服务实际返回内容当例子：

  服务器返回了:
  HTTP/1.0 200 OK                          ← 状态行
  Server: SimpleHTTP/0.6 Python/3.14.3    ← 响应头
  Content-Type: text/html; charset=utf-8

  <!DOCTYPE HTML>                          ← 开始响应体
  <html>
  <head>
  <title>Directory listing for /</title>
  </head>
  <body>
  <h1>Directory listing for /</h1>
  ...
  </body>
  </html>

  五种方式逐一看：

  1. word —— 关键词搜索

  就像在网页里按 Ctrl+F。

  matchers:
    - type: word
      part: body                    # 只在响应体里找
      words:
        - "Directory listing"       # 包含这个词 → 匹配成功

  Nuclei 收到上面的 HTML，一搜：Directory listing for / → 找到了 → 命中。

  2. regex —— 正则表达式

  不是搜固定文字，而是搜「像某种模式的东西」。

  matchers:
    - type: regex
      part: header                  # 在响应头里搜
      regex:
        - "Python/\\d+\\.\\d+\\.\\d+"   # 模式: Python/数字.数字.数字

  Nuclei 看到 Python/3.14.3 → 符合模式 → 命中。
  如果看到 Python/2.7.18 也命中。
  如果看到 Apache/2.4 不命中。

  3. status —— 只看状态码

  最简单的一种。

  matchers:
    - type: status
      status:
        - 200         # 服务器返回 200 → 命中
        - 301         # 或者返回 301 → 也命中

  不做任何内容检查，只看门牌号。

  4. dsl —— 自定义组合条件

  前面三种都太简单了？用 DSL 写逻辑。

  matchers:
    - type: dsl
      dsl:
        - "status_code == 200"           # 条件1: 状态码是200
        - "len(body) > 1000"             # 条件2: 页面内容比1000字节长
        - "contains(header, 'Server')"   # 条件3: 响应头里有Server字段
      condition: and                      # 三个条件全部满足才命中

  这相当于说：「不是简单看一个关键词，我要页面正常(200)、内容不少(>1000字节)、且确实有个 Server 头。」

  5. binary —— 二进制匹配

  跟 word 一样，但是给非文本文件用的（图片、exe 等）。你暂时用不到。

  ---
  三、一张图帮你记住

  Nuclei 发请求 ──► 服务器回包 ──► 5种方式检查回包
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                  │
                 word              regex              status
               "看有没有          "看有没有            "看门牌号
               这个词"            这个模式"           对不对"
                    │                 │                  │
                    └─────────────────┼──────────────────┘
                                      │
                                    dsl
                             "多条件自由组合"
                             status==200 AND
                             len(body)>1000 AND
                             contains(header,'Server')

  还有一个关键字段：part

  matchers:
    - type: word
      part: header    ← 去响应头里搜
      words: ["Python"]

    - type: word
      part: body      ← 去响应体(HTML)里搜
      words: ["Directory"]

  指定 part 就是告诉 Nuclei 去回包的哪个区域搜。