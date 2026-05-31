---
title: github魔改
date: 2026-05-12T18:12:02+08:00
draft: false
categories:
tags:
---

第一周：环境搭建 + Nuclei 深入掌握 ✅

  - [x] Fork Nuclei 仓库，精读 internal/runner/ 和 pkg/protocols/http/ 核心代码
  - [x] 用 Nuclei 扫描 DVWA/OWASP Juice Shop 等靶场，跑通全协议（HTTP/DNS/TCP）
  - [x] 理解 YAML 模板 DSL，手写 5 个自定义模板
  - [x] 搭建 Python 项目骨架（FastAPI + Jinja2）

  第二周：智能误报过滤引擎 ✅

  - [x] 解析 Nuclei JSON 输出，设计结果数据结构
  - [x] 用 LLM 对每条扫描结果做二次研判（请求/响应上下文 → 真漏洞/误报）
  - [x] 实现批量过滤 pipeline（支持 Ollama 本地模型）
  - [x] 在自建靶场上做对照实验，统计准确率数据

  第三周：中文渗透测试报告生成 ✅

  - [x] 设计报告模板（HTML），AI 生成安全摘要
  - [x] LLM 驱动的漏洞描述生成（技术细节 + 修复建议 + 风险评级）
  - [x] 一键生成报告，包含：严重度分布、统计、修复优先级
  - [x] 自建漏洞靶场（8 个漏洞端点）

  第四周：误报过滤验证 + 混合防线 ✅

  - [x] 6 个误报干扰项页面 + 4 个模板路径扩展
  - [x] AI 过滤器 5 轮 Prompt 优化 + 响应预览 Bug 修复
  - [x] 5 条硬规则混合防线设计
  - [x] 最终准确率：100%（16/16，AI + 硬规则协同）

  第五周：高级功能 + 优化 ✅

  - [x] 智能扫描策略：指纹识别 → 自动选择最优模板组合
  - [x] 模板库扩展：新增 6 个漏洞类型 → 总计 20 个模板（5 demo + 15 vuln）
  - [x] 扫描结果对比：两次扫描 Diff 视图（Fixed/New/Persistent）

  第六周：文档 + 演示准备 🔄

  - [x] 中英文 README + 架构图
  - [x] 技术博客一篇
  - [x] 面试话术准备（STAR 法则）
  - [ ] 录制 3 分钟功能演示视频（脚本已写好）
  - [ ] 在掘金/知乎发布博客

  第七周：简历投递 + 迭代 🔄

  - [x] 简历项目描述（中英文3版）+ 技能标签建议
  - [x] GitHub Profile README 模板
  - [x] 实习申请邮件/自我介绍模板 + 面试 Checklist
  - [x] 安全社区推广帖模板
  - [x] requirements.txt 清理（移除无用依赖）
  - [ ] 将项目推送到 GitHub 并设为公开
  - [ ] 在安全社区（T00ls、看雪、先知）发帖推广
  - [ ] 陆续投递实习岗位

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