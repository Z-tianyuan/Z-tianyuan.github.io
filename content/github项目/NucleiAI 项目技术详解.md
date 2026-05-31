---
title: "NucleiAI：给自动化扫描器装上 AI 大脑"
date: 2026-05-26T22:00:00+08:00
draft: false
categories:
  - 安全工具
tags:
  - NucleiAI
  - Nuclei
  - AI安全
  - 误报过滤
  - Prompt工程
  - 开源项目
---

## 一、问题的起点

如果你做过安全扫描，你一定经历过这个场景：

> Nuclei 跑完一轮，输出 50 条告警。其中 15 条是"技术识别"（检测到目标用了 Nginx），10 条是误报（教程页的代码示例触发了 XSS 规则），真正需要看的漏洞只有 5 条。

自动化扫描器的最大痛点是**高误报率**。Nuclei 作为优秀的开源扫描引擎，只做规则匹配不做分析——它告诉你"匹配到了关键词"，但不关心这是真实漏洞还是教学代码。

这就是 NucleiAI 要解决的问题：**在 Nuclei 之上构建一个 AI 分析层，自动区分真实漏洞和误报。**

---

## 二、架构概览

```
用户浏览器
  │
  ├─ GET  /              → Dashboard（含 AI 判定 + 置信度 + 理由）
  ├─ POST /              → 全流程:
  │   ├─ fingerprint_target()    [httpx → 技术栈探测]
  │   ├─ run_nuclei_scan()       [Nuclei → 20 个模板扫描 + 指纹智能选模]
  │   ├─ filter_results()        [Ollama 批量 AI → 5 条硬规则修正]
  │   └─ scan_result_to_row()    [数据处理]
  ├─ GET  /report/{id}  → HTML 报告（含 AI 安全摘要）
  └─ GET  /compare      → 两次扫描 Diff 对比

靶场：vuln_server.py (14 漏洞 + 6 干扰项 = 20 端点)
模板库：5 demo + 15 vuln = 20 个模板
核心防线：AI 语义分析 + 硬规则确定性修正
```

技术栈：**Python FastAPI** 后端 + **Jinja2** 前端 + **Nuclei** (Go) 扫描引擎 + **Ollama** 本地 LLM。

---

## 三、AI 误报过滤：三个关键设计

### 3.1 从串行到批量：5 分钟 → 1 分钟

第一版逐条调用 Ollama——9 条扫描结果，每条 30 秒，总共 5 分钟。这在真实场景中不可接受。

**批量方案**：把全部结果拼成一个 Prompt，单次 LLM 推理返回 JSON 数组：

```
输入: {count} 条扫描结果的摘要列表
输出: [{finding_type, is_false_positive, confidence, reason}, ...]
```

性能从 5 分钟降到 1 分钟（5x 提升）。更意外的是，**准确率也提升了**——LLM 看到全部上下文后，能更好地判断"哪些是真正的漏洞 vs 哪些只是信息提示"。

### 3.2 Prompt 工程：场景化 > 抽象规则

经过 5 轮迭代，我学到的最重要一课：

| 抽象规则 | 场景化指引 |
|---------|----------|
| "区分教育内容和漏洞" | "标题含'教程''入门'的页面通常是教学文章，代码标签出现在教学示例中而非用户输入回显" |
| "检测输入是否被转义" | "用户输入已被 HTML 实体编码（如 `&lt;script&gt;`），没有真正的脚本执行点" |

**URL 路径是关键上下文**：`/blog/xss-tutorial` 和 `/search?q=` 的语义差别，对 LLM 判断帮助巨大。

### 3.3 混合防线：AI + 硬规则

8B 量化模型（qwen3:8b Q4_K_M）存在固有的一致性问题——同一数据多次测试，准确率在 75%-100% 波动。单纯依赖 AI 无法保证可靠性。

设计了 5 条硬规则自动修正：

| 规则 | 触发条件 | 动作 |
|------|---------|------|
| 技术识别保护 | 标签为 tech 类型 | 永不标误报 |
| XSS 转义检测 | body 含 `&lt;script&gt;` 且无真实 `<script>` | 自动标误报 |
| 内部重定向 | Location 头为内部路径 | 自动标误报 |
| 调试已关闭 | body 含 "Debug Mode: OFF" 或 "redacted" | 自动标误报 |
| Git 文字提及 | 提及 git 但无文件链接 | 自动标误报 |

这就像**自动驾驶的感知模型 + 规则引擎**——AI 处理模糊判断，规则保证安全底线。

---

## 四、一个致命 Bug 的教训

排查了两天，AI 判定质量一直很差。

最后发现 `_summarize_result()` 函数里用 `response.split("\r\n\r\n")[0]` 提取响应预览——这是 **HTTP 头部**，不是正文。AI 在做判定时根本看不到页面实际内容，只能盲猜。

```python
# 修复前：AI 只看到 HTTP 头
response_preview = response.split("\r\n\r\n")[0][:400]

# 修复后：AI 能看到头 + 正文
parts = response.split("\r\n\r\n", 1)
headers = parts[0][:200]
body = parts[1][:600]
response_preview = f"{headers}\n\n--- response body ---\n{body}"
```

**教训**：AI 应用的质量瓶颈往往不在模型本身，而在**喂给模型的数据质量**。Garbage in, garbage out.

---

## 五、测试数据

自建漏洞靶场：14 个真实漏洞 + 6 个误报干扰项 = 20 个端点，触发 26 条检测结果。

| 分类 | 准确率 |
|------|:------:|
| 真实漏洞正确确认 | 100% |
| 误报正确过滤 | 100% |
| 综合准确率（最终轮） | 100% |
| 稳态准确率（混合防线保证） | 90%+ |

模型：qwen3:8b (Q4_K_M)，批量分析（BATCH_SIZE=5），5 条硬规则兜底。

---

## 六、项目亮点总结

1. **全栈能力**：Python 后端 + Jinja2 前端 + AI 集成 + Go 工具链（2000+ 行代码）
2. **AI 应用深度**：不只是"调 API"，而是 Prompt 工程 5 轮迭代 + 混合防线设计 + 模型选型
3. **安全理解**：独立编写 14 个漏洞端点 + 6 个干扰场景 + 20 个检测模板
4. **工程化思维**：性能优化（5min→1min）+ 优雅降级（AI 不可用时仍可用）+ 扫描 Diff 对比

---

## 七、后续方向

- 接入更大模型（qwen3:32b 或云端 API）验证准确率上限
- 前端重构为 React/Vue
- 增加更多漏洞类型（文件上传漏洞、XXE、反序列化）
- CI/CD 集成（GitHub Actions 触发扫描）
- 支持 Nuclei 官方全量模板库

---

项目地址：[github.com/Z-tianyuan/NucleiAI](https://github.com/Z-tianyuan/NucleiAI)
