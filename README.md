# Capy Notes · AI 笔记

Markdown 笔记 + 内置 AI 知识库。所有笔记即知识库——提问时 AI 检索全部笔记，基于内容回答并给出引用来源。安卓优先（Flutter 跨平台），云端 AI 接入（DeepSeek / Qwen）。

## 定位

| 维度 | 选择 |
|---|---|
| 平台 | 安卓优先，Flutter 跨平台（一套代码覆盖 iOS） |
| 存储 | SQLite（Drift），主存 + 导出 .md |
| AI 接入 | 云端 API：Embedding = bge-m3 / Qwen-v4；LLM = DeepSeek（OpenAI 兼容） |
| 编辑器 | Markdown 源码 + 预览（P0），appflowy_editor 块级编辑器为演进路线 |
| 隐私 | `in_kb` 开关控制哪些笔记纳入知识库，笔记默认不出设备（仅 AI 调用时上传相关片段） |

## 核心能力

- **笔记**：Markdown 源码编辑 + 实时预览、文件夹/标签、FTS5 全文搜索
- **AI 知识库**：增量切块嵌入 → 混合检索（向量 + 关键词 + RRF 融合）→ 流式回答 + 引用跳转原文
- **成本可控**：增量嵌入（只处理变更）、`in_kb` 范围开关、可配置模型

## 仓库结构

```
├── README.md           # 本文件
├── architecture.md     # 系统架构：技术选型 / 数据模型 / RAG 流程 / 编辑器决策
├── roadmap.md          # 分阶段实施计划（P0 ~ P3）
└── client/             # Flutter App（P0 起）
    ├── lib/
    │   ├── core/           # 主题、路由、常量
    │   ├── data/           # drift 表 / DAO / 迁移 / 仓库
    │   ├── services/ai/    # ai_client / embedding / chat / rag / chunking
    │   └── features/       # notes / chat / settings
    └── android/            # Android 工程
```

## 本地开发

```bash
cd client && flutter run          # 需要 flutter 3.x + Android SDK
cd client && flutter test         # 单元测试
```

## 相关文档

- [architecture.md](architecture.md) — 架构与关键技术决策
- [roadmap.md](roadmap.md) — 分阶段实施计划
