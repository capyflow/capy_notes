# Capy Notes · 系统架构

> 现状：项目立项，进入 P0 实施前。
> 本文定义：**整体架构、技术选型、数据模型、RAG 流程、编辑器决策**——是后续所有实现的上游依据。

## 1. 定位与边界

**本地优先的 Markdown 笔记**，AI 知识库是核心差异化能力。

| 能力 | 归属 | 是否依赖网络 |
|---|---|---|
| 笔记编辑、文件夹/标签、FTS5 搜索 | 客户端 | 否 |
| AI 知识库问答（RAG） | 客户端 + 云端 API | 是 |
| 笔记纳入知识库范围 | 客户端（`in_kb` 开关） | 否 |
| 多端同步（后期） | 客户端 + WebDAV/坚果云 | 是（可选） |

**隐私原则：笔记默认只存在设备本地。** AI 调用时仅上传"被检索命中的相关片段"用于生成回答；用户可用 `in_kb` 控制哪些笔记进入知识库，全程不依赖用户上传全部笔记。

## 2. 总体架构

```
┌────────────────────────────────────────────────┐
│                 Flutter UI（Riverpod）          │
│    笔记列表 │ Markdown 编辑器 │ AI 对话页(流式)   │
├────────────────────────────────────────────────┤
│                 应用层 / 业务逻辑                │
│   NoteRepository │ RAGService │ ChatService     │
│   ChunkingService（增量切块） │ 引用跳转         │
├────────────────────────────────────────────────┤
│             数据层（Drift / SQLite）             │
│   notes 表 │ chunks 表 │ FTS5 全文索引          │
│   sqlite-vec 向量索引（同库，无额外服务）         │
├────────────────────────────────────────────────┤
│             AI 服务层（OpenAI 兼容 API）         │
│   Embedding：bge-m3（SiliconFlow）或 Qwen-v4    │
│   LLM：DeepSeek deepseek-chat（流式 SSE）       │
└────────────────────────────────────────────────┘
```

## 3. 技术选型

| 模块 | 选型 | 理由 |
|---|---|---|
| 框架 | Flutter（stable）+ Dart 3 | 一套代码覆盖安卓+iOS |
| 状态管理 | Riverpod 3.x（含 generator） | 响应式，适合多数据源联动（笔记 ↔ 对话） |
| 数据库 | **Drift**（SQLite） | 原生 FTS5、响应式查询流、迁移工具链成熟 |
| 向量检索 | **sqlite-vec**（本地扩展） | 与 SQLite 同库，无额外部署，移动端可用 |
| 编辑器 | Markdown 源码 + `markdown` 包预览（P0） | 保真 100%，AI 侧零转换损失（见 §6） |
| 网络 | dio + SSE 流式解析 | 轻量，流式打字机效果 |
| Embedding | **bge-m3**（SiliconFlow）或 Qwen text-embedding-v4 | 中文强，1024 维 |
| LLM | **DeepSeek deepseek-chat** | 中文强、便宜、快；Qwen3 备选 |
| 路由/模型 | go_router + freezed | 常规标配 |

> **关键坑**：DeepSeek 官方**没有 embedding API**，嵌入走 Qwen/SiliconFlow，问答走 DeepSeek。两者均为 OpenAI 兼容格式，统一封装为 `AiClient`。

**排除项**：Isar（停止维护）、Hive（无查询能力）、本地 Ollama（移动端体验差）。

## 4. 数据模型（Drift / SQLite）

```sql
-- 笔记主体
CREATE TABLE notes (
  id          TEXT PRIMARY KEY,           -- UUID
  title       TEXT NOT NULL,
  content     TEXT NOT NULL,              -- Markdown 源码
  folder      TEXT NOT NULL DEFAULT '',
  tags        TEXT NOT NULL DEFAULT '',   -- 逗号分隔
  in_kb       INTEGER NOT NULL DEFAULT 1, -- 是否纳入知识库（隐私/成本开关）
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

-- RAG 切块（增量维护，带来源与顺序）
CREATE TABLE chunks (
  id          TEXT PRIMARY KEY,           -- UUID
  note_id     TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  seq         INTEGER NOT NULL,           -- 块内顺序
  content     TEXT NOT NULL,
  embedding   BLOB                        -- 1024 维 float32（sqlite-vec 向量列）
);

-- 全文索引
CREATE VIRTUAL TABLE notes_fts USING fts5(content, content='notes', content_rowid=rowid);
-- 通过触发器与 notes 保持同步

-- 配置
CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- api_key / base_url / llm_model / embedding_model / kb_scope ...
```

## 5. RAG 核心流程

```
写入/编辑笔记
   → 增量 Chunking（只处理变更块，防重复嵌入，省成本）
   → bge-m3 向量化 → upsert 到 chunks 表

用户提问
   → 双路检索（并行）:
      ① 向量检索：sqlite-vec cosine top-20
      ② 关键词检索：FTS5 top-20（人名/API 名/术语靠这路）
   → RRF 融合排序 → 取 top 8~12 块
   → 组装 Prompt（system + 带来源标注的检索块 + 问题）
   → DeepSeek 流式生成
   → 回复内嵌引用 [笔记标题]，点击跳转原文高亮
```

**为什么混合检索而非纯向量**：笔记里大量专有名词（函数名、书名、人名），纯向量对精确词召回差，FTS5 补齐，RRF 融合是 RAG 笔记类应用的标准做法。

**切块策略**：按标题/段落切，目标 500~800 token，相邻块重叠 ~10% 保证语义连续；代码块/表格整体保留不拆分。

**成本控制**：
- 增量嵌入：仅变更块重新嵌入（`updated_at` 比对）
- `in_kb` 开关：未纳入的笔记不切块、不嵌入、不参与检索
- 可配置模型与 top-k，控制单次调用 token

## 6. 编辑器决策（重要）

**问题**：Flutter 原生富文本编辑能力弱（与 Web/原生生态差距最大的领域）。

**结论：P0 不做 WYSIWYG，用 Markdown 源码 + 预览。**

| 方案 | 实现 | 优点 | 缺点 | 状态 |
|---|---|---|---|---|
| A. 源码 + 预览 | `TextField` 多行 + `markdown` 包渲染 | Markdown 100% 保真；AI 侧零转换损失；IME 兼容最好；实现简单 | 非所见即所得 | **P0 采用** |
| B. 块级编辑器 | `appflowy_editor`（AppFlowy 的编辑器） | Flutter 生态最强富文本；块级、Markdown 快捷输入、IME 支持好 | 文档模型是 JSON，转 Markdown 有转换层；集成成本高 | 演进路线 |
| C. WebView + CodeMirror | `flutter_inappwebview` + 内置 JS 编辑器 | 编辑体验天花板（Obsidian 同款）；Markdown 保真 + 高亮 + 快捷键 | 性能开销；离线 JS 包管理复杂；双端行为不一致 | 后期兜底 |

**理由**：
1. AI 知识库直接受益于干净 Markdown——RAG 切块、代码块、表格解析，处理源码比处理 WYSIWYG 文档模型可靠得多
2. WYSIWYG 的文档模型 → Markdown 是"有损转换"，表格/脚注/嵌套列表易变形——双输：保真受损 + 检索质量受损
3. 手机编辑场景以碎片记录为主，源码 + 预览足够；Obsidian / Joplin 均为此路线

**明确排除 flutter_quill**：Delta 模型转 Markdown 有损、Android IME 组合问题历史包袱多、表格支持差。

## 7. 项目结构（client/）

```
client/lib/
├── main.dart
├── core/            # 主题、路由（go_router）、常量
├── data/
│   ├── database/    # drift 表、DAOs、migrations
│   ├── models/      # freezed 实体
│   └── repositories/ # note_repository, chunk_repository
├── services/
│   └── ai/          # ai_client(统一封装), embedding_service,
│                    # chat_service(SSE), rag_service, chunking_service
└── features/
    ├── notes/       # 列表、编辑器、搜索
    ├── chat/        # AI 对话页
    └── settings/    # API 配置、知识库范围管理
```

## 8. 待定决策（P3 前敲定）

- [ ] 笔记主存 SQLite + 导出 .md（当前方案） vs 纯文件存储（Obsidian 式）
- [ ] 多端同步：WebDAV / 坚果云 / 自建后端
- [ ] 引用精确到块 vs 精确到笔记（当前：精确到笔记 + 块序号）
