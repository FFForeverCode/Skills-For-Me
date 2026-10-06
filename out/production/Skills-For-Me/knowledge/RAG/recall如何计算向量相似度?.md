这个问题正好是 **RAG Recall 的核心**。

假设我们已经通过 Embedding 模型把用户 Query 和文档转换成向量：

```text
用户问题：
“Redis 如何解决缓存击穿？”

        ↓ Embedding Model

Q = [0.2, 0.5, -0.1, 0.8]
```

文档：

```text
“可以通过互斥锁、逻辑过期等方式解决缓存击穿……”

        ↓ Embedding Model

D = [0.3, 0.4, -0.2, 0.7]
```

接下来就是计算 **Q 和 D 的相似度**。

最常见的有三种方法：

1. **余弦相似度 Cosine Similarity**
2. **点积 Dot Product**
3. **欧氏距离 Euclidean Distance**

RAG 中最常见的是前两种。

---

# 1. 余弦相似度

最经典的公式：

[
\text{cosine}(Q,D)=
\frac{Q\cdot D}{|Q||D|}
]

其中：

* (Q)：Query 向量
* (D)：Document 向量
* (Q\cdot D)：向量点积
* (|Q|)：Q 的模长
* (|D|)：D 的模长

它实际上衡量的是：

> **两个向量的夹角有多接近。**

---

## 举个简单例子

为了方便计算，我们使用二维向量：

```text
Q = [1, 2]

D = [2, 4]
```

### 第一步：计算点积

[
Q\cdot D
=1\times2+2\times4
=10
]

### 第二步：计算向量长度

[
|Q|=\sqrt{1^2+2^2}=\sqrt5
]

[
|D|=\sqrt{2^2+4^2}=\sqrt{20}
]

### 第三步

[
cos(Q,D)
========

\frac{10}{\sqrt5\sqrt{20}}
=1
]

结果：

```text
1
```

说明两个向量方向完全一致。

也就是说：

```text
[1,2]
   ↗
  /
 /
[2,4]
```

虽然长度不同，但是方向完全一样。

---

# 2. 为什么余弦相似度可以表示语义相似度？

Embedding 模型训练的目标之一，就是让：

> **语义相近的文本 → 向量空间中距离更近**

例如：

```text
“如何解决 Redis 缓存击穿？”
```

和：

```text
“Redis 缓存击穿有哪些解决方案？”
```

Embedding 后可能：

```text
Q1 → [0.21, 0.52, -0.13, ...]
Q2 → [0.20, 0.51, -0.12, ...]
```

两个向量方向非常接近。

所以：

```text
cosine(Q1,Q2) ≈ 0.98
```

而：

```text
“今天天气怎么样？”
```

可能得到：

```text
Q3 → [-0.62, 0.11, 0.73, ...]
```

那么：

```text
cosine(Q1,Q3) ≈ 0.12
```

于是就可以通过相似度进行排序：

```text
Document A → 0.95
Document B → 0.87
Document C → 0.41
Document D → 0.12
```

然后取 Top K。

---

# 3. 实际 RAG 并不会遍历所有文档吗？

如果只有：

```text
1000篇
```

当然可以：

```text
Query
 ↓
Embedding
 ↓
和1000个Document Vector分别计算相似度
 ↓
排序
 ↓
Top 10
```

但如果有：

```text
1000万
```

甚至：

```text
10亿
```

就不能简单地：

```text
for document in documents:
    calculateSimilarity(query, document)
```

因为计算量太大。

所以实际 RAG 通常使用：

> **ANN（Approximate Nearest Neighbor，近似最近邻搜索）**

例如：

* HNSW
* IVF
* PQ
* FAISS
* Milvus
* Elasticsearch Vector Search
* pgvector

---

# 4. HNSW 是怎么加速的？

例如我们有：

```text
100万个向量
```

如果暴力搜索：

```text
Query
 ↓
计算 100万个相似度
 ↓
排序
 ↓
Top 10
```

复杂度接近：

[
O(N)
]

HNSW 会构建一个类似“高速公路”的多层图结构。

简单理解：

```text
Layer 2：

A ──────── D
           │
           │
Layer 1：

A ─ B ─ C ─ D ─ E ─ F
    │       │
    G ─ H ─ I
```

查询的时候不是把所有节点都算一遍，而是：

```text
Query
 ↓
找到一个比较接近的点
 ↓
沿着图不断寻找更近的点
 ↓
最终得到 Top K
```

因此可以大幅减少需要计算的向量数量。

---

# 5. Dot Product 又是什么？

点积：

[
Q\cdot D
========

\sum_i Q_iD_i
]

例如：

```text
Q = [1,2]

D = [2,4]
```

那么：

[
Q\cdot D=1\times2+2\times4=10
]

---

## Cosine 和 Dot Product 的关系

如果 Query 和 Document 都进行了 **L2 Normalize**：

[
|Q|=1
]

[
|D|=1
]

那么：

[
cos(Q,D)=Q\cdot D
]

所以很多向量数据库可以直接使用：

> **Inner Product / Dot Product**

来实现余弦相似度。

这也是工程中很常见的优化。

---

# 6. Euclidean Distance 呢？

欧氏距离：

[
d(Q,D)=
\sqrt{\sum_i(Q_i-D_i)^2}
]

距离越小：

> 越相似。

例如：

```text
Q = [1,2]

D1 = [2,4]
D2 = [10,20]
```

如果直接看欧氏距离：

```text
Q-D1
```

可能比：

```text
Q-D2
```

小很多。

但是实际上：

```text
[1,2]
[2,4]
[10,20]
```

三个向量方向都是一样的。

所以对于很多文本 Embedding 场景：

> **Cosine Similarity 往往比单纯的 Euclidean Distance 更符合语义相似度的直觉。**

不过具体使用什么距离，取决于 Embedding 模型的训练方式和向量数据库配置。

---

# 7. 放回 RAG 整个过程

现在你就可以把 Recall 阶段完整串起来：

```text
                    离线阶段

Document
   ↓
Embedding Model
   ↓
Document Vector
   ↓
Vector DB
   ↓
建立 HNSW / IVF 等索引


                    在线阶段

User Query
   ↓
Embedding Model
   ↓
Query Vector
   ↓
Vector DB
   ↓
ANN Search
   ↓
Cosine / Dot Product
   ↓
Top 50
   ↓
Rerank
   ↓
Top 5
   ↓
LLM
```

所以你面试时可以这样回答：

> **RAG 的向量召回首先通过 Embedding 模型分别将 Query 和 Document 转换成向量，然后通过余弦相似度或者点积计算 Query 与 Document 的向量相似程度。对于大规模知识库，不会暴力遍历所有向量，而是通过 HNSW、IVF 等 ANN 索引快速找到 TopK 相似向量。召回出来的候选文档再交给 Reranker 做精排。**

其中最关键的关系可以记成：

```text
Embedding
    ↓
文本 → 向量
    ↓
Similarity
    ↓
向量 → 相似度
    ↓
ANN
    ↓
大规模快速检索
```

**Embedding 决定“怎么表示语义”，Similarity 决定“两个语义有多接近”，ANN 决定“怎么快速找到最接近的那些”。**
