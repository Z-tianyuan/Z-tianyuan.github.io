---
title: "NucleiAI 项目学习复盘 — 第二周 (2026-05-12 - 2026-05-18)"
date: 2026-05-18T20:00:00+08:00
draft: false
categories: ["项目实战"]
tags: ["NucleiAI", "Nuclei", "漏洞扫描", "AI过滤", "FastAPI", "报告生成", "指纹识别", "学习复盘"]
---

## 🎯 本周核心目标

将上周搭建的独立模块（AI 过滤、报告生成、指纹识别）串联到 Web 面板中，形成完整的扫描→分析→展示→报告链路。

---

## 📚 模块一：AI 过滤集成到 Web 面板

### 核心链路

```
用户输入 URL → Nuclei 扫描 → JSONL 解析
  → Ollama API 逐条分析 → AI 判定 + 自动修正
  → 分类输出 (确认/误报) → Web 表格渲染
```

### Web 面板新增功能

- **AI 判定列**：表格新增「AI判定」「置信度」「AI理由」三列
- **视觉区分**：绿色徽章=真实漏洞，红色=误报，蓝色=技术识别
- **置信度进度条**：0-100% 可视化，颜色随数值变化（绿≥70%，黄≥40%，红<40%）
- **AI 汇总卡片**：表格下方显示「确认真实漏洞/信息」和「判定误报」数量统计

### 优雅降级设计

当 Ollama 不可用时：
- 不阻塞扫描流程，显示黄色警告
- 表格自动隐藏 AI 列，展示原始扫描结果
- AI 过滤异常被单独 catch，不影响 Nuclei 扫描环节

### 关键踩坑

**问题**：扫描成功后页面显示 "All connection attempts failed"
**排查**：Nuclei 返回正常，但 `filter_results` 调用 `httpx` 连接 Ollama 时失败，异常被外层 `except Exception as e` 捕获，覆盖了整个扫描状态
**修复**：将 AI 过滤的异常处理独立 `try/except`，失败时设置 `ai_enabled=False` 而非 `error`

---

## 📚 模块二：中文漏洞报告生成

### 技术选型

原计划用 WeasyPrint 生成 PDF，但 Windows 缺少 GTK/Pango 系统库。改为 **HTML 报告 + 浏览器打印为 PDF**，对面试演示更实用。

### 报告结构

```
┌── 封面 ──────────────────────┐
│ NucleiAI 漏洞扫描报告          │
│ 目标/时间/引擎信息             │
├── AI 安全评估摘要 ────────────┤
│ [A] 整体评估简述              │
│ 严重度网格 (严重/高/中/低/信息) │
│ 优先修复事项 Top 3            │
├── AI 确认真实漏洞列表 ────────┤
│ 名称│严重度│类型│描述│置信度    │
├── AI 判定误报列表 ────────────┤
│ 名称│严重度│误报理由│标签      │
├── 页脚 ──────────────────────┤
│ [打印 / 保存为 PDF] 按钮      │
└──────────────────────────────┘
```

### 核心实现

- **`generate_llm_summary()`**：调用 Ollama 生成中文摘要（安全评级 A-F、严重度分布、Top 3 修复事项）
- **`_fallback_summary()`**：Ollama 不可用时基于规则自动生成摘要
- **`/report/{index}` 路由**：按 scan history 索引访问报告，LLM 摘要只生成一次并缓存
- **打印优化**：`@media print` + `@page { size: A4 }` 控制打印样式

---

## 📚 模块三：目标指纹识别

### 技术栈

使用 ProjectDiscovery **httpx**（Go 二进制）对目标进行技术栈探测，检测 Web Server、框架、语言版本等。

### 工作流程

```
httpx -tech-detect → JSON 解析
  → 提取 technologies / webserver / status_code / title
  → 技术栈标签展示在 Web UI
  → suggest_templates() 根据技术栈推荐 Nuclei 模板
```

### 实现细节

- **`_find_httpx()`**：自动搜索 httpx 二进制（PATH → ~/bin/）
- **版本号剥离**：httpx 返回 `Python:3.14.3`，通过 `split(":")[0]` 提取基础名匹配映射表
- **`TECH_TEMPLATE_MAP`**：覆盖 20+ 常见技术栈 → Nuclei 模板路径映射
- **Web 展示**：指纹信息卡位于扫描结果卡片顶部，显示状态码、服务器、标题、技术栈标签

### 实测结果

以本地 Python HTTP Server 为靶场：
- 状态码：200
- 服务器：SimpleHTTP/0.6 Python/3.14.3
- 技术栈：Python:3.14.3, SimpleHTTP:0.6

---

## 🔧 踩坑记录（第二周）

| 问题 | 原因 | 解决 |
|------|------|------|
| 扫描报 "All connection attempts failed" | Ollama 未启动，AI 过滤抛异常被外层 catch | 独立 try/except + 优雅降级 |
| WeasyPrint 导入失败 | Windows 缺少 GTK/Pango 库 | 改用 HTML 报告 + 浏览器打印 |
| 报告模板渲染 Internal Server Error | `generate_report_data` 返回 raw dict，模板访问了嵌套字段 | 新增 `_row()` 函数将 raw 转为平铺 display row |
| httpx 未安装 | 工具链不完整 | 从 GitHub Releases 下载到 `~/bin/` |
| 编辑代码时丢失 `raw_results =` 行 | 替换字符串匹配不完整 | 检查后补回 |
| MSYS2 grep 不支持 `-P` (Perl regex) | Windows locale 限制 | 用基础 regex 替代 |

---

## 📊 第二周数据

- **开发时间**：约 10 小时
- **产出**：AI 过滤 Web 集成 + 中文报告生成 + 指纹识别集成
- **新增依赖**：httpx (Go binary) 用于技术栈检测
- **端到端可用**：输入 URL → 指纹识别 → Nuclei 扫描 → AI 过滤 → 查看报告

---

## 🏗️ 当前架构总览

```
用户浏览器 (http://127.0.0.1:8000)
  │
  ├─ GET  /              → Dashboard (扫描表单 + 历史记录)
  ├─ POST /              → 扫描流程:
  │   ├─ fingerprint_target()    [httpx Go binary]
  │   ├─ run_nuclei_scan()       [Nuclei Go binary]
  │   └─ filter_results()        [Ollama qwen3:8b]
  └─ GET  /report/{id}  → HTML 报告 (含 LLM 摘要)
```

---

## 🎯 下周计划

- [ ] 部署更多类型漏洞模板（不只是 tech detection）
- [ ] 搭建 Docker 靶场或本地漏洞靶场
- [ ] 用真实漏洞场景测试 AI 过滤准确率
- [ ] 考虑 React 前端重构（可选）
