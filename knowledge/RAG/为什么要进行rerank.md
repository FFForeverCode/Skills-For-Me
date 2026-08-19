RAG 里做 **Rerank（重排序）**，核心是解决一个问题：

> **“召回阶段追求不漏，Rerank 阶段追求精准。”**

典型链路：

```text
用户 Query
   ↓
Query Rewrite / HyDE
   ↓
向量召回 + BM25
   ↓
Top 50 / Top 100 候选文档
   ↓
       Rerank
   ↓
Top 5 / Top 10 高相关文档
   ↓
LLM
   ↓
最终回答
```

### 1. 为什么召回之后还需要 Rerank？

因为**向量召回的目标不是精准排序，而是尽可能把相关文档捞进来**。

比如用户问：

> “Spotify 兑换码库存不足时，系统怎么处理？”

向量召回可能得到：

```text
Top 1：Spotify 兑换码库存设计
Top 2：Redis 库存扣减方案
Top 3：Spotify 会员兑换流程
Top 4：Redis 分布式锁设计
Top 5：RocketMQ 异步补偿机制
Top 6：库存不足异常处理
Top 7：会员权益系统设计
...
```

这些文档**语义上都相关**，但真正对这个问题最有价值的可能是：

```text
库存不足异常处理
Spotify 兑换码库存设计
Redis 库存扣减方案
```

向量模型很难准确判断：

> “这个文档到底是不是最适合回答当前 Query？”

所以需要第二阶段 Rerank。

---

## 2. Recall 和 Rerank 的目标不同

这是面试里非常重要的一句话：

### Recall：宁可多，不要漏

例如：

```text
10000 篇文档
    ↓
向量 / BM25 / Hybrid Recall
    ↓
Top 100
```

召回阶段主要关注：

> **Recall@K**

也就是：

> 真正相关的文档，有多少被我召回了？

因此召回模型一般会比较“宽松”。

---

### Rerank：宁可准，不要杂

然后：

```text
Top 100
   ↓
Rerank
   ↓
Top 5
```

Rerank 关注的是：

> **这些候选文档中，哪些最值得交给 LLM？**

所以它更加关注：

> Precision / Relevance

---

# 3. Rerank 为什么比向量相似度更准确？

核心原因是：

**向量召回通常是“两阶段表示”，而 Rerank 可以直接对 Query 和 Document 做联合建模。**

比如：

```text
Query：
“库存不足时如何防止兑换码超卖？”

Document A：
“系统采用 Redis Lua 原子操作扣减库存……”

Document B：
“Redis 是一个高性能内存数据库……”
```

向量模型主要把：

```text
Query → Vector
Document → Vector
```

然后计算：

```text
similarity(QueryVector, DocumentVector)
```

而 Rerank 模型通常可以直接输入：

```text
[Query] + [Document]
```

让模型判断：

> **这个 Document 到底能不能很好地回答这个 Query？**

因此它可以理解更加细粒度的：

* 关键词匹配
* 语义关系
* 上下文
* Query 与 Document 的具体关联
* 文档是否真正回答了问题

所以通常：

```text
向量召回
    ↓
速度快
    ↓
适合大规模候选集

Rerank
    ↓
精度高
    ↓
适合几十/几百个候选集
```

---

# 4. 为什么不直接用 Rerank？

因为 **Rerank 比向量召回贵得多**。

假设知识库有：

```text
1000万篇文档
```

如果直接：

```text
Query
 ↓
Rerank 1000万篇
```

计算成本会非常恐怖。

所以采用：

```text
1000万
  ↓
Embedding / BM25
  ↓
100
  ↓
Rerank
  ↓
10
  ↓
LLM
```

这就是典型的 **Two-Stage Retrieval（两阶段检索）**。

---

# 5. 为什么 Rerank 能提高 LLM 最终回答质量？

因为 LLM 的上下文窗口并不是无限的，而且：

> **给 LLM 太多低相关文档，反而可能降低回答质量。**

例如：

```text
召回 Top 20

真正相关：5
一般相关：7
无关：8
```

全部塞给 LLM：

```text
Query
+
20个Document
        ↓
       LLM
```

LLM 可能会：

* 被无关信息干扰
* 找错答案
* 出现信息冲突
* 增加 Prompt Token
* 增加推理成本
* 增加延迟

经过 Rerank：

```text
Top 20
  ↓
Rerank
  ↓
Top 5
  ↓
LLM
```

变成：

```text
Query
+
最相关的5个Document
        ↓
       LLM
```

因此最终：

**上下文质量 ↑ → LLM 回答质量 ↑**

同时：

**Token ↓ → 成本 ↓ → 延迟 ↓**

---

# 6. 结合你之前的 RAG 项目，可以这样理解

你之前的链路是：

```text
Query Rewrite
      ↓
HyDE
      ↓
Hybrid Recall
      ↓
Rerank
      ↓
LLM
```

每一层实际上解决不同问题：

| 模块            | 解决的问题                |
| ------------- | -------------------- |
| Query Rewrite | 用户问题表达不清             |
| HyDE          | Query 和知识库文本存在语义空间差异 |
| Hybrid Recall | 单一召回方式容易漏召回          |
| Rerank        | 召回结果不够精准             |
| LLM           | 基于高质量上下文生成答案         |

所以整个思路可以总结成：

```text
                    ┌─ Vector Recall ─┐
Query → Query处理 → │                 │ → Top 100 → Rerank → Top 5 → LLM
                    └─ BM25 Recall ───┘
```

**Recall 负责“找全”，Rerank 负责“排准”，LLM 负责“回答”。**

---

### 面试可以直接这么回答

> **RAG 中引入 Rerank 主要是因为召回和排序的目标不同。召回阶段通常采用向量检索、BM25 或 Hybrid Search，重点是保证 Recall，尽可能把相关文档召回，但 TopK 中可能存在大量弱相关文档。Rerank 会对召回出的几十到几百个候选文档，结合 Query 和 Document 做更精细的相关性判断，重新排序并截取 TopN，再交给 LLM。这样可以减少无关上下文对 LLM 的干扰，同时降低 Token 消耗和推理成本。因此典型 RAG 是“两阶段检索”：第一阶段追求召回率，第二阶段追求相关性和精确度。**
