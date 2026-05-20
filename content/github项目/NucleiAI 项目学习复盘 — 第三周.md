---
title: NucleiAI 项目学习复盘 — 第三周 (2026-05-16 - 2026-05-20)
date: 2026-05-20T22:00:00+08:00
draft: false
categories:
  - 项目实战
tags:
  - NucleiAI
  - Nuclei
  - 漏洞挖掘
  - AI过滤
  - 靶场搭建
  - 性能优化
  - 学习复盘
---

## 🎯 本周核心目标

补齐项目最大短板——**用真实漏洞数据验证 AI 过滤有效性**。前两周只有 5 个技术识别模板，AI 从未见过真正的漏洞，无法证明其核心价值。

---

## 📚 模块一：自建漏洞靶场

### 为什么不用 Docker

Docker Desktop 在 Windows 11 Home China 环境下多次启动失败，且 Docker Hub 被墙。**塞翁失马——自建靶场反而更有面试价值**：可以同时展示"靶场设计能力"和"扫描检测能力"。

### 靶场设计

使用 Python 内置 `http.server` 模块（零额外依赖），创建 `vuln_server.py`，监听 `127.0.0.1:9999`。

**植入的 8 个漏洞/弱点：**

| 端点 | 漏洞类型 | 严重度 | 面试表述 |
|------|---------|:------:|---------|
| `/search?q=<script>...` | Reflected XSS | medium | 输入未做 HTML 实体编码 |
| `/redirect?url=http://evil.com` | Open Redirect | medium | 302 跳转到任意外部 URL |
| `/debug` | Debug Endpoint Exposure | medium | 泄露 Python 版本/环境变量/PID |
| `/.git/` | Git Directory Exposure | high | 源码库可通过 Web 访问 |
| `/error` | Stack Trace Leak | low | 500 错误页暴露数据库连接地址 |
| `/admin` | Admin Panel Exposure | medium | 未授权即可访问管理后台 |
| `/login` | Credentials in Comments | medium | HTML 注释含测试账号密码 |
| 响应头 | Server Version Disclosure | info | 泄露 Apache 版本及操作系统 |

### 安全考量

- 监听地址严格限制为 `127.0.0.1`，局域网和互联网均不可达
- 所有"漏洞"均为静态 HTML 字符串模拟，无真实数据库、无命令执行、无文件操作
- 关闭服务器后不留任何痕迹

---

## 📚 模块二：漏洞检测模板编写

### 新增 7 个模板

| 模板文件 | 检测类型 | 匹配逻辑 |
|---------|---------|---------|
| `vuln-xss-reflected.yaml` | XSS | word: `<script>alert('XSS')</script>` |
| `vuln-open-redirect.yaml` | Open Redirect | status:302 + header:"Location: http://evil.com" |
| `vuln-debug-exposure.yaml` | Debug 暴露 | word: "Debug Information" AND "python_version" |
| `vuln-git-exposure.yaml` | .git 泄露 | word: "Index of /.git" |
| `vuln-stacktrace-leak.yaml` | 栈跟踪泄露 | word: "Traceback" AND "DatabaseError" |
| `vuln-credentials-comment.yaml` | 凭证泄露 | word: "test credentials" AND "admin" |
| `vuln-admin-exposure.yaml` | 后台暴露 | word: "Admin Panel" |

### 模板编写心得

- 漏洞模板的 `severity` 要按照 CVSS 实际评估，不能全标 info
- `tags` 字段直接影响 AI 三步分类（tech/vuln/exposure），必须准确
- 匹配词要选**特征性强的**，避免和正常页面撞车导致误报

---

## 📚 模块三：AI 过滤性能优化

### 从 5 分钟到 1 分钟

| 迭代  | 方案                |     耗时     | 问题               |
| :-: | ----------------- | :--------: | ---------------- |
| V1  | 逐条调用（串行）          |   ~5 min   | 9 条结果 × 30s/条    |
| V2  | 并行调用（Semaphore=4） |   ~4 min   | Ollama 内部排队，并行无效 |
| V3  | **批量分析**          | **~1 min** | ✅ 1 次推理分析全部 9 条  |
|     |                   |            |                  |

### 批量方案实现

将 9 条扫描结果拼成一个 Prompt，LLM 一次返回 JSON 数组：

```
输入: {count} 条扫描结果的摘要列表
输出: [{finding_type, is_false_positive, confidence, reason}, ...]
```

关键改动：`ai_filter.py` 从 `for + await filter_result` 改为 `_summarize_result × N → 单次 API 调用 → json.loads 数组`

### 意外收获：准确率提升

批量分析让 LLM 看到**全部结果的上下文**，相对判断更准确：

| 判定项 | 逐条 V1 | 批量 V3 |
|--------|:------:|:------:|
| Reflected XSS | ❌ 误报 | ✅ 真实漏洞 |
| Open Redirect | ❌ 技术识别 | ✅ 真实漏洞 |
| Git 泄露 | 不稳定 | ✅ 稳定正确 |

**原因**：LLM 看到全部 9 条结果后，能更好地判断"哪些是真正的漏洞"vs"哪些只是信息提示"。

---

## 📊 AI 过滤准确率数据

### 测试环境

- 靶场：`vuln_server.py` 8 漏洞 + 1 技术识别模板
- 模型：qwen3:8b (Q4_K_M)
- 方式：批量分析

### 判定结果

| 检测项 | 严重度 | 标签类型 | AI 判定 | 置信度 | 正确？ |
|--------|:------:|---------|:------:|:------:|:------:|
| Admin Panel Exposure | medium | vuln | 真实漏洞 | 95% | ✅ |
| Debug Endpoint Exposure | medium | vuln | 真实漏洞 | 95% | ✅ |
| Git Directory Exposure | high | vuln | 真实漏洞 | 95% | ✅ |
| Stack Trace Leak | low | vuln | 真实漏洞 | 95% | ✅ |
| Credentials in Comments | medium | vuln | 真实漏洞 | 95% | ✅ |
| Reflected XSS | medium | vuln | 真实漏洞 | 95% | ✅ |
| Open Redirect | medium | vuln | 真实漏洞 | 95% | ✅ |
| Server Version Disclosure | info | tech | 真实漏洞 | 95% | ⚠️ |
| Multi-Path Detection | info | demo | 技术识别 | 95% | ✅ |

### 关键指标

| 指标        |     数值      |
| --------- | :---------: |
| 总扫描结果     |      9      |
| AI 确认真实漏洞 |      8      |
| AI 判定误报   |      0      |
| 类型分类准确率   |  8/9 (89%)  |
| 误报检测准确率   | 9/9 (100%)* |

*注：测试集不含真误报，AI 正确识别了所有存在的漏洞。真误报测试需要搭建含有干扰项的靶场。

---

## 🔧 踩坑记录（第三周）

| 问题 | 原因 | 解决 |
|------|------|------|
| Docker Desktop 无法启动 | WSL2 环境问题 + daemon.json 含失效镜像地址 | 还原配置，放弃 Docker |
| AI 分析耗时过长（5 min） | 9 条结果串行调 Ollama | 改为批量分析，单次 API 调用 |
| Ollama 内部排队并行无效 | Ollama 服务端串行处理请求 | 确认批量方案为最优解 |
| XSS 被误判为误报（V1） | 逐条分析缺乏上下文对比 | 批量分析自带上下文，问题消失 |
| 漏洞模板匹配覆盖不到部分端点 | 路径或关键词不够精确 | 逐个测试验证，调整匹配词 |

---

## 📊 第三周数据

- **开发时间**：约 8 小时
- **产出**：1 个漏洞靶场 + 7 个漏洞模板 + AI 批量分析优化
- **性能提升**：扫描耗时从 5 分钟降至 1 分钟（3-5x）
- **AI 准确率**：漏洞确认率 100%，类型分类 89%

---

## 🏗️ 三周后项目架构

```
用户浏览器
  │
  ├─ GET  /              → Dashboard
  ├─ POST /              → 全流程:
  │   ├─ fingerprint_target()    [httpx → 技术栈探测]
  │   ├─ run_nuclei_scan()       [Nuclei → 12 个模板扫描]
  │   ├─ filter_results()        [Ollama → 批量 AI 分析]
  │   └─ scan_result_to_row()    [数据处理]
  └─ GET  /report/{id}  → HTML 报告（含 AI 摘要）

靶场：vuln_server.py (8 漏洞)
模板库：5 demo + 7 vuln = 12 个模板
核心链路耗时：~1 分钟
```

---

## 🎯 后续计划

- [ ] 项目 GitHub README + 演示脚本
- [ ] 添加真误报场景测试（干扰项）
- [ ] 面试话术准备（STAR 法则描述项目）
- [ ] 可选：React 前端重构
