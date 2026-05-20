---
title: "NucleiAI 项目学习复盘 — 第一周 (2026-05-11 - 2026-05-17)"
date: 2026-05-18T12:00:00+08:00
draft: false
categories: ["项目实战"]
tags: ["NucleiAI", "Nuclei", "漏洞扫描", "AI过滤", "FastAPI", "学习复盘"]
---

## 🎯 项目概述

NucleiAI 是一个 AI 增强漏洞管理平台，在 ProjectDiscovery Nuclei 扫描引擎之上集成 Ollama 本地大模型进行智能误报过滤，并通过 Web 面板可视化呈现结果。

**技术栈**：Python + FastAPI + Jinja2 + Nuclei (Go) + Ollama (qwen3:8b)

---

## 📚 模块一：Nuclei 扫描引擎

### Nuclei 是什么

基于 YAML 模板的漏洞扫描器（Go 语言，28k+ GitHub Stars）。核心思路：**模板定义检测逻辑 → 引擎执行 HTTP 请求 → 匹配器判断是否命中**。

### YAML 模板结构

```yaml
id: template-unique-id           # 模板唯一标识
info:
  name: 模板名称
  author: 作者
  severity: info|low|medium|high|critical
  description: 检测描述
  tags: demo,tech                 # 标签（影响 AI 分类判断）
http:                             # HTTP 请求定义
  - method: GET
    path: ["{{BaseURL}}/"]
    matchers:                     # 匹配器（检测逻辑）
      - type: word
        part: body
        words: ["关键词"]
```

### 五种匹配器（Matchers）

| 类型 | 用途 | 示例 |
|------|------|------|
| **word** | 关键字匹配 | 响应体含 "Directory listing for" |
| **regex** | 正则提取 | `Python/\d+\.\d+\.\d+` 提取版本号 |
| **status** | HTTP 状态码 | `200` 表示页面存在 |
| **dsl** | 表达式组合 | `status_code==200 AND len(body)>1000` |
| **binary** | 二进制匹配 | 非文本文件特征检测 |

### 匹配逻辑进阶

- **condition: and/or** — 多条规则间的逻辑关系
- **part: header/body** — 指定匹配范围
- **stop-at-first-match: true** — 多路径扫描时首个命中即停止
- **matchers-condition** — 跨 matcher 组的组合条件

### 实测心得

- `-jsonl` 输出每行一条 JSON，适合程序化处理
- `-silent` 抑制 Nuclei 自身日志，只输出结果
- `-timeout` 设 30s 足够本地扫描
- 扫描外部目标需谨慎，先用本地靶场测试

---

## 🛠️ 模块二：自定义模板编写

本周编写了 5 个自定义模板：

| #   | 模板                    | 匹配类型               | 技法         |
| --- | --------------------- | ------------------ | ---------- |
| 1   | `01-simple-word.yaml` | word               | 基础关键字匹配    |
| 2   | `02-header-body.yaml` | word × 2 (AND)     | 多字段联合匹配    |
| 3   | `03-regex.yaml`       | regex              | 正则提取版本号    |
| 4   | `04-dsl-complex.yaml` | dsl (3条件 AND)      | DSL 表达式组合  |
| 5   | `05-multi-path.yaml`  | status + word (OR) | 多路径 + 首匹停止 |

所有模板的 `severity` 设为 `info` 或 `low`，`tags` 包含 `demo`，确保测试安全可控。

---

## 🧠 模块三：AI 误报过滤

### 核心链路

```
Nuclei 扫描 → JSONL 结果 → Ollama API → AI 分类 → 自动修正 → 分类输出
```

### Prompt 设计（迭代两版）

**V1 问题**：Prompt 只考虑了漏洞利用场景，所有技术识别类结果（如 "检测到 Python Server"）都被误判为误报。

**V2 改进**：三步分类法
1. **技术识别类**（tags 含 tech/discovery/detect）→ 只要响应包含对应特征就不是误报
2. **漏洞利用类**（tags 含 vuln/cve/rce 等）→ 真正的安全漏洞检测
3. **配置暴露类**（tags 含 exposure/misconfig）→ 敏感文件/面板暴露检测

### 混合防线：AI + 规则引擎

AI 输出后增加代码层硬规则兜底：
- `finding_type == "tech" AND is_false_positive == True` → **自动修正**为 False
- 理由自动替换为 `[自动修正] 技术识别类结果不标记为误报`

### 关键技术细节

- Ollama 运行在 `localhost:11434`，API 格式兼容 OpenAI Chat
- `qwen3:8b` 8.2B 参数，Q4_K_M 量化，5.2GB
- httpx 异步客户端，超时 120s（第一次推理需加载模型）
- JSON 提取用 `content.find("{")` + `content.rfind("}")` 容错解析

---

## 🌐 模块四：Web 面板

### 技术栈

- **FastAPI** — Python 异步 Web 框架
- **Jinja2** — 服务端模板渲染
- **深色主题** — 自写 CSS（参考安全工具面板风格）

### 页面结构

```
┌─────────────────────────────┐
│         NucleiAI            │
│   AI增强漏洞管理平台          │
├─────────────────────────────┤
│  ┌─── 新建扫描任务 ────────┐  │
│  │ [URL输入框] [开始扫描]  │  │
│  └────────────────────────┘  │
├─────────────────────────────┤
│  严重等级说明 | 标签说明     │
├─────────────────────────────┤
│  扫描结果表格               │
│  ┌─────────────────────────┐│
│  │名称│严重度│说明│标签│AI ││
│  │     │徽章  │    │    │判定││
│  └─────────────────────────┘│
│  AI 汇总: 确认真实 | 误报   │
└─────────────────────────────┘
```

### 数据流

```
用户输入 URL
  → POST /  (Form: target)
  → run_nuclei_scan(target)
  → filter_results(raw_results)  [async, Ollama API]
  → 存入 SCAN_HISTORY
  → Jinja2 渲染 index.html
```

### 优雅降级

当 Ollama 不可用时：
- 不阻塞扫描流程
- 显示黄色警告 `⚠ AI 过滤不可用`
- 表格自动隐藏 AI 列，展示原始扫描结果

---

## 🔧 踩坑记录

| 问题 | 原因 | 解决 |
|------|------|------|
| `UnicodeEncodeError` (GBK) | Windows 终端默认 GBK | `PYTHONIOENCODING=utf-8` |
| Nuclei `-json` 报错 | 正确参数是 `-jsonl` | 改用 `-jsonl` |
| AI 判定全误报 | Prompt 只覆盖漏洞场景 | 加入三步分类 + 代码自动修正 |
| 扫描报 "All connection attempts failed" | Ollama 未启动，AI 过滤抛异常被 catch | 启动 Ollama + 添加优雅降级 |
| MSYS2 bash 找不到 ollama | 路径含空格 `C:\Program Files\Ollama\` | 用 curl 调 HTTP API |

---

## 📊 第一周数据

- **开发时间**：约 12 小时
- **产出**：5 个自定义模板 + AI 过滤引擎 + Web 面板 + 端到端联调
- **模板覆盖**：word / regex / status / dsl / multi-path 五种匹配器
- **AI 准确率**：3/3 技术识别正确分类（本地测试）

---

## 🎯 下周计划

- [ ] 完成 AI 过滤效果测试（多种漏洞类型）
- [ ] 集成中文报告生成（report_generator.py）
- [ ] 添加目标指纹识别（fingerprint.py）
- [ ] Docker 靶场搭建（如无法连接外网则用本地替代）
