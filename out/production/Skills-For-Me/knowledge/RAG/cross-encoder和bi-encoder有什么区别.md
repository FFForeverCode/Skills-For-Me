可以把两者理解成使用了**两类不同的模型**：

```text
Query
  ↓
Embedding Model
  ↓
向量
  ↓
Vector DB
  ↓
Top 50/100
  ↓
Rerank Model
  ↓
Top 5/10
  ↓
LLM
```

### 1. Recall 使用什么模型？

Recall 阶段通常使用 **Embedding Model（向量化模型）**。

它负责把：

```text
Query → 向量
Document → 向量
```

然后通过余弦相似度、内积等方式寻找最相似的文档。

例如：

```text
Query：
“如何解决 Redis 热点 Key？”

        ↓ Embedding Model

[0.12, -0.31, 0.72, ...]
```

知识库中的文档也提前做：

```text
Document → Embedding Model → Vector
```

然后：

```text
Query Vector
      ↓
Vector DB
      ↓
相似度计算
      ↓
Top 100
```

常见 Embedding 模型例如：

* OpenAI `text-embedding-3-large`
* BGE 系列：`bge-large-zh`、`bge-m3`
* Qwen Embedding 系列
* Jina Embeddings
* Voyage Embeddings

国内中文 RAG 场景里，**BGE、Qwen Embedding** 这类模型比较常见。

---

### 2. Rerank 使用什么模型？

Rerank 通常使用 **Reranker Model（重排序模型）**。

它和 Embedding 模型最大的区别是：

**Embedding：分别编码 Query 和 Document**

```text
Query ─────→ Vector
Document ──→ Vector

       ↓
similarity
```

而 Rerank 更像：

```text
Query + Document
       ↓
 Rerank Model
       ↓
 relevance score
```

例如：

```text
Query：
“Redis 热点 Key 怎么解决？”

Document A：
“可以通过本地缓存、Key 拆分等方式解决热点 Key……”

Document B：
“Redis 是一个基于内存的 KV 数据库……”

              ↓
         Rerank Model
              ↓

Document A → 0.96
Document B → 0.42
```

然后按照 score 排序。

常见 Rerank 模型：

* BGE Reranker
* Qwen Reranker
* Cohere Rerank
* Jina Reranker
* Voyage Rerank

---

## 3. 为什么不用同一个模型？

因为两个阶段的**计算目标不同**。

### Embedding

需要处理：

```text
100万 / 1000万 / 1亿 文档
```

所以必须：

> **快**

通常提前把所有 Document 向量化，然后利用向量数据库的 ANN 索引快速检索。

---

### Rerank

只需要处理：

```text
Top 50 / Top 100
```

所以可以使用计算成本更高、但理解能力更强的模型。

例如：

```text
1000万 Document
      ↓
Embedding + ANN
      ↓
Top 100
      ↓
Reranker
      ↓
Top 5
```

这就是为什么 RAG 要拆成两个模型。

---

## 4. 一句话区分

面试直接记这个：

> **Recall 使用 Embedding 模型，把 Query 和 Document 映射到向量空间，通过向量相似度快速召回候选集；Rerank 使用 Cross-Encoder/Reranker 模型，将 Query 和候选 Document 联合输入，直接计算相关性分数，对候选集重新排序。**

再进一步：

```text
Embedding
解决：这个文档“像不像”用户的问题？

Rerank
解决：这个文档“到底适不适合回答”用户的问题？
```

这也是为什么你之前 **ACE 反作弊智能助手** 的 `Hybrid Recall → Rerank` 是非常典型的 RAG 架构。


可以把它放到你刚才的 **RAG Recall → Rerank** 链路里理解，这是最容易记住的方式：

> **Bi-Encoder 负责“快速找候选”，Cross-Encoder 负责“精确判断候选”。**

---

# 1. 先看两者最核心的区别

假设用户 Query：

> “Redis 热点 Key 怎么解决？”

候选文档：

> “可以通过本地缓存、Key 拆分、读写分离等方式解决 Redis 热点 Key……”

### Bi-Encoder

把两边**分别编码**：

```text
Query
  │
  ▼
Encoder
  │
  ▼
Query Vector ─────┐
                  │
                  ▼
              Similarity
                  ▲
                  │
Document Vector ──┘
  ▲
  │
Encoder
  │
  │
Document
```

即：

```text
Query    → Encoder → Q向量
Document → Encoder → D向量

score = similarity(Q向量, D向量)
```

---

### Cross-Encoder

把 Query 和 Document **拼在一起**送进模型：

```text
Query + Document
       │
       ▼
 Cross Encoder
       │
       ▼
 relevance score
```

例如：

```text
[CLS]
Redis热点Key怎么解决？
[SEP]
可以通过本地缓存、Key拆分……
[SEP]
       ↓
Cross-Encoder
       ↓
0.96
```

所以最本质的区别：

> **Bi-Encoder：Query 和 Document 分开编码。**
>
> **Cross-Encoder：Query 和 Document 放在一起联合编码。**

---

# 2. 为什么 Bi-Encoder 特别适合 RAG Recall？

因为 Document 可以**提前计算向量**。

假设你的知识库有：

```text
1000万篇 Document
```

我们可以提前：

```text
Document 1 → Embedding → Vector 1
Document 2 → Embedding → Vector 2
...
Document 1000万 → Embedding → Vector 1000万
```

然后全部存到：

```text
Milvus / Elasticsearch / pgvector / FAISS / VectorDB
```

用户来了一个 Query：

```text
“Redis热点Key怎么解决？”
        ↓
Embedding
        ↓
Query Vector
        ↓
ANN
        ↓
Top 100
```

这里最关键的是：

**1000 万个 Document 不需要在用户请求的时候重新计算。**

---

# 3. Cross-Encoder 为什么不能直接拿来做 Recall？

假设有：

```text
1000万篇 Document
```

用户来了一个 Query：

```text
Q
```

如果使用 Cross-Encoder：

```text
Q + Document1 → Model → Score
Q + Document2 → Model → Score
Q + Document3 → Model → Score
...
Q + Document1000万 → Model → Score
```

意味着一次 Query：

> **要跑 1000 万次模型推理。**

这显然无法接受。

所以 Cross-Encoder 更适合：

```text
1000万
  ↓
Bi-Encoder / BM25
  ↓
Top 100
  ↓
Cross-Encoder
  ↓
Top 5
```

这就是 RAG 两阶段检索。

---

# 4. 为什么 Cross-Encoder 更准确？

这是最值得理解的地方。

假设：

```text
Query：
“Redis 如何解决缓存击穿？”

Document A：
“Redis 可以通过互斥锁、逻辑过期等方式解决缓存击穿问题。”

Document B：
“Redis 是一个基于内存的高性能 Key-Value 数据库。”
```

### Bi-Encoder

分别生成：

```text
Q → [0.12, 0.52, ...]
A → [0.15, 0.48, ...]
B → [0.13, 0.46, ...]
```

然后：

```text
similarity(Q,A) = 0.91
similarity(Q,B) = 0.86
```

它知道：

> A 和 Q 很像。

但这种判断本质上还是：

> **两个独立向量之间的距离。**

---

### Cross-Encoder

直接：

```text
[CLS]
Redis如何解决缓存击穿？
[SEP]
Redis可以通过互斥锁、逻辑过期等方式解决缓存击穿问题。
[SEP]
```

Transformer 的 Self-Attention 可以让 Query 中的词和 Document 中的词**直接产生交互**。

例如：

```text
“缓存击穿”
      ↕
“互斥锁、逻辑过期”
```

模型可以更细粒度地判断：

> Document A 是否真的回答了 Query？

最终得到：

```text
A → 0.97
B → 0.32
```

所以 Cross-Encoder 通常排序准确率更高。

---

# 5. 从 Transformer 结构理解

这个区别会让你面试的时候显得比较深入。

## Bi-Encoder

一般是：

```text
                Transformer
                    │
         ┌──────────┴──────────┐
         ↓                     ↓
      Query                  Document
         ↓                     ↓
      Vector Q               Vector D
         └──────────┬──────────┘
                    ↓
                 Similarity
```

Query 和 Document **没有在 Transformer 内部直接交互**。

最后才：

```text
Q vector ↔ D vector
```

做相似度计算。

---

## Cross-Encoder

则是：

```text
Query
  +
Document
  │
  ▼
Tokenizer
  │
  ▼
Transformer
  │
  │ Self-Attention
  │
  │ Query token ↔ Document token
  │
  ▼
Score
```

所以：

> **Cross-Encoder 的优势就在于 Query Token 和 Document Token 可以在 Transformer 的 Attention 层中直接交互。**

这也是它为什么更准确，但更慢。

---

# 6. 一个非常形象的类比

假设你要找一个适合回答问题的人。

### Bi-Encoder

先给每个人做一个“能力画像”：

```text
张三：
Redis 0.9
Java 0.8
MySQL 0.7
AI 0.3
```

用户问题：

```text
Redis热点Key怎么解决？
```

也做一个画像：

```text
Redis 0.95
缓存 0.9
Java 0.3
```

然后比较：

```text
问题画像 ↔ 人的画像
```

快速找到 Top 100。

---

### Cross-Encoder

直接把问题拿给候选人：

> “Redis 热点 Key 怎么解决？”

然后让候选人回答。

再由评委判断：

> **这个人的回答到底好不好？**

所以：

```text
Bi-Encoder
= 快速筛简历

Cross-Encoder
= 面试
```

这就是为什么：

> **Bi-Encoder 适合 Recall，Cross-Encoder 适合 Rerank。**

---

# 7. 两者最大的工程区别

|                   | Bi-Encoder        | Cross-Encoder     |
| ----------------- | ----------------- | ----------------- |
| 输入                | Query、Document 分开 | Query + Document  |
| 编码                | 独立编码              | 联合编码              |
| Query/Doc 是否交互    | 最后才交互             | Transformer 内部就交互 |
| 输出                | Embedding Vector  | Relevance Score   |
| 是否可以提前计算 Document | ✅                 | ❌                 |
| 是否适合向量数据库         | ✅                 | ❌                 |
| 检索速度              | 快                 | 慢                 |
| 精度                | 较高                | 通常更高              |
| 适合候选数量            | 百万/千万             | 几十/几百             |
| RAG阶段             | Recall            | Rerank            |

---

# 8. 为什么叫 Bi-Encoder 和 Cross-Encoder？

名字其实也很好理解。

### Bi = 两个

```text
Query → Encoder
Document → Encoder
```

两个输入分别走 Encoder。

所以：

> **Bi-Encoder**

---

### Cross = 跨越交互

```text
Query Token
     ↕
Document Token
     ↕
Attention
```

Query 和 Document 的 Token 在同一个 Transformer 中进行跨序列交互。

所以：

> **Cross-Encoder**

---

# 9. 放到完整 RAG 里

你可以把整个链路理解成：

```text
                         离线阶段
                            │
                    ┌───────▼───────┐
                    │  Document     │
                    └───────┬───────┘
                            │
                       Bi-Encoder
                            │
                            ▼
                       Vector DB
                            │
                            │
                         在线阶段
                            │
                            ▼
                          Query
                            │
                       Bi-Encoder
                            │
                            ▼
                       Query Vector
                            │
                            ▼
                    Vector Search / BM25
                            │
                            ▼
                       Top 50~100
                            │
                            ▼
                    ┌───────────────┐
                    │ Cross-Encoder │
                    └───────┬───────┘
                            │
                     relevance score
                            │
                            ▼
                          Top 5
                            │
                            ▼
                           LLM
                            │
                            ▼
                           Answer
```

所以你之前问的：

> **“为什么 RAG 要 Rerank？”**

现在可以进一步解释成：

> **因为第一阶段使用 Bi-Encoder 可以通过预计算 Document Embedding + ANN，在海量数据中快速完成粗排；但 Bi-Encoder 的 Query 和 Document 是独立编码的，交互能力有限，因此需要第二阶段使用 Cross-Encoder 对 TopK 候选进行联合编码和精细相关性判断，从而提高最终送入 LLM 的上下文质量。**

---

## 10. 面试最后可以再补一句

如果面试官继续问：

> “那是不是 Cross-Encoder 一定比 Bi-Encoder 好？”

你可以回答：

> **不是简单的谁替代谁，而是精度和效率的权衡。Bi-Encoder 适合大规模召回，Cross-Encoder 适合小规模精排。实际 RAG 通常采用级联架构，让 Bi-Encoder 负责从百万级甚至千万级文档中快速召回候选，再让 Cross-Encoder 对几十到几百个候选进行精确排序。**

这句话基本就把 **Embedding → ANN Recall → Rerank → LLM** 整条链路串起来了。
