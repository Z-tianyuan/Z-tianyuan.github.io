---
title: github魔改
date: 2026-05-12T18:12:02+08:00
draft: false
categories:
tags:
---

第一周：环境搭建 + Nuclei 深入掌握

  - Fork Nuclei 仓库，精读 internal/runner/ 和 pkg/protocols/http/ 核心代码
  - 用 Nuclei 扫描 DVWA/OWASP Juice Shop 等靶场，跑通全协议（HTTP/DNS/TCP）
  - 理解 YAML 模板 DSL，手写 5 个自定义模板
  - 搭建 Python 项目骨架（FastAPI + SQLite + Docker）

  第二周：智能误报过滤引擎

  - 解析 Nuclei JSON 输出，设计结果数据结构
  - 用 LLM 对每条扫描结果做二次研判（请求/响应上下文 → 真漏洞/误报）
  - 实现批量过滤 pipeline（支持 Ollama 本地模型 + OpenAI API）
  - 在 DVWA 上做对照实验，统计误报率降低数据

  第三周：中文渗透测试报告生成

  - 设计报告模板（LaTeX/HTML → PDF），参考 GB/T 标准渗透报告格式
  - LLM 驱动的漏洞描述生成（技术细节 + 修复建议 + 风险评级）
  - 一键生成 PDF，包含：封面、目录、漏洞详情、统计图表、修复优先级

  第四周：Web 管理面板

  - FastAPI + Jinja2 搭建前端
  - 功能：新建扫描任务、历史结果列表、报告下载、仪表盘统计
  - 实时扫描进度展示（WebSocket）
  - Docker 一键部署脚本

  第五周：高级功能 + 优化

  - 智能扫描策略：自动指纹识别 → 选择最优模板组合
  - 自定义模板库：针对 OWASP Top 10 2025 编写 20+ 个高质量模板
  - 扫描结果对比：两次扫描的 diff 视图（漏洞修复验证）

  第六周：文档 + 演示准备

  - 录制 3 分钟功能演示视频
  - 编写中英文 README，配架构图
  - 写一篇技术博客（掘金/知乎）介绍项目
  - 准备面试话术：「这个项目解决了什么问题、我做了什么、效果如何」

  第七周：简历投递 + 迭代

  - 将项目添加到简历和 GitHub Profile
  - 在安全社区（T00ls、看雪、先知）发帖推广
  - 收集反馈，修复 bug
  - 陆续投递实习岗位

  ---
  简历上的写法（参考）

  ▎ NucleiAI - AI-Enhanced Vulnerability Management Platform
  ▎ 为 ProjectDiscovery Nuclei 构建的 AI 智能分析平台。核心贡献：① 基于 LLM 的误报过滤引擎，在 DVWA 测试中将误报率从 X%
  ▎ 降低至 Y%；② 一键生成符合 GB/T 标准的中文渗透测试报告（PDF）；③ FastAPI + Docker 构建的 Web
  ▎ 管理面板。技术栈：Python, FastAPI, Nuclei, LLM (OpenAI/Ollama), Docker。

  ---

  Read 1 file, recalled 1 memory, wrote 2 memories (ctrl+o to expand)

● ---
  总结： 推荐用 Python + Nuclei 做一个 AI 增强漏洞管理平台，而非硬改 Go 源码。你的 AI 能力是差异化武器，Nuclei
  是成熟的扫描引擎，两者结合刚好填补官方未覆盖的「智能分析」空白。7
  周时间从零到可演示，足够支撑暑期实习面试。需要我帮你搭建项目骨架的话，随时说。