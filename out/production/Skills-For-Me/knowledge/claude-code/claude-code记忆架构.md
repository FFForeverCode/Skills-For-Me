# Claude Code 记忆系统技术详解

## 1. 为什么 AI Agent 需要“记忆系统”？

普通 LLM 的一个基本特点是：

> 模型本身不会天然跨会话记住用户和项目的信息。

一次对话中，模型能够利用上下文：

```text
用户：
我们现在正在开发订单系统。

AI：
好的。

用户：
订单状态机这里使用 CAS。

AI：
明白。
```

但是当用户第二天重新开启一个 Session：

```text
用户：
继续昨天的订单系统开发。

AI：
……
```

如果没有额外的记忆机制，模型并不知道：

* 昨天讨论了什么；
* 项目的技术约定是什么；
* 用户喜欢什么样的代码风格；
* 之前用户纠正过模型什么；
* 当前项目有哪些长期目标；
* 上一次 Session 做到了什么阶段。

因此，一个真正成熟的 AI Coding Agent，需要解决的不只是：

> **“如何理解当前对话？”**

还需要解决：

> **“如何跨时间保存、检索、更新和遗忘信息？”**

Claude Code 的记忆系统正是围绕这个问题构建的。

原材料将其总结为六个维度：

```text
                    Claude Code Memory
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    指令记忆            短期/工作记忆         长期记忆
    CLAUDE.md          当前 Session         memdir
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                  ┌────────┴────────┐
                  │                 │
             Session Memory      AutoDream
             会话持续记忆          离线整合
                  │                 │
                  └────────┬────────┘
                           │
                      团队共享记忆
```

其核心目标主要有三个：

1. **解决长对话中的上下文遗忘问题**
2. **解决跨 Session、跨终端以及团队之间的知识同步问题**
3. **在有限 Token Budget 下提高上下文利用率**

---

# 2. 六维记忆体系总览

可以先从“记忆生命周期”理解整个架构。

| 记忆层次           | 解决的问题            | 典型载体                 |
| -------------- | ---------------- | -------------------- |
| 指令记忆           | 告诉 Agent 应该怎么做   | `CLAUDE.md`          |
| 短期记忆           | 当前对话发生了什么        | Conversation History |
| 工作记忆           | 当前任务做到哪里         | Task / Runtime State |
| 长期记忆           | 跨 Session 保存重要信息 | Markdown Memory      |
| Session Memory | 长对话压缩后保留什么       | `session-memory.md`  |
| AutoDream      | 定期整理长期记忆         | 后台整合任务               |

除此之外，还有：

* Team Memory：团队共享
* Agent Memory：不同 Agent 独立记忆
* Logs Mode：长生命周期 Agent 的追加日志
* Cache：降低记忆系统运行成本
* Feature Flag：动态控制记忆功能

因此，**Claude Code 的 Memory 并不是一个“memory.md 文件”这么简单，而是一整套 Memory Architecture。**

---

# 3. 第一层：指令记忆——CLAUDE.md

## 3.1 什么是指令记忆？

指令记忆可以理解成：

> **AI 的行为准则。**

它不是用来记录“昨天发生了什么”，而是告诉 AI：

```text
你应该怎么工作。
```

例如：

```markdown
# Project Rules

- 使用 Java 17
- 所有接口必须保证幂等
- Controller 不允许直接访问数据库
- Service 层负责业务逻辑
- 所有异常必须统一处理
```

这类信息属于：

> **规则，而不是经历。**

---

# 4. CLAUDE.md 的四层优先级

原材料将指令加载体系划分为四层，从低到高：

```text
Managed
   ↓
User
   ↓
Project
   ↓
Local
```

## 4.1 Managed

组织级别的全局规则。

可以理解为：

```text
/etc/claude-code/CLAUDE.md
```

主要由组织管理员制定。

例如：

```text
公司安全规范
公司代码规范
禁止提交敏感信息
必须使用统一的代码扫描工具
```

特点：

> 所有用户都应该遵守。

---

## 4.2 User

用户个人级别的全局规则。

例如：

```text
~/.claude/CLAUDE.md
```

它作用于：

> 当前用户的所有项目。

例如用户可以规定：

```markdown
# My Preferences

- Java 优先使用 Stream
- 默认使用中文回答
- 代码解释必须包含设计原因
```

---

## 4.3 Project

项目级规则。

通常放在项目根目录：

```text
project/
├── CLAUDE.md
├── src/
└── ...
```

适合存：

```text
项目架构
代码规范
开发流程
测试方式
项目约定
```

因为它进入代码仓库，所以：

> 可以和团队成员共享。

---

## 4.4 Local

本地项目私有规则。

它只对当前开发者生效，并且一般不会加入 Git。

适合保存：

```text
个人开发习惯
本机特殊环境
个人调试方式
临时约定
```

因此四层可以理解为：

```text
组织
 ↓
个人
 ↓
项目
 ↓
个人项目环境
```

越靠近当前开发目录，优先级越高。

---

# 5. 为什么采用“从根目录到当前目录”的加载顺序？

假设：

```text
project/
├── CLAUDE.md
└── src/
    ├── CLAUDE.md
    └── payment/
        └── CLAUDE.md
```

当前工作目录：

```text
src/payment/
```

系统实际上会形成：

```text
project/CLAUDE.md
        ↓
src/CLAUDE.md
        ↓
src/payment/CLAUDE.md
```

也就是说：

> **越靠近当前工作目录的规则，加载得越晚，因此优先级越高。**

这样设计有什么好处？

例如项目统一要求：

```text
所有代码必须使用 Java
```

但是：

```text
src/python-tool/
```

下面又规定：

```text
这里允许使用 Python。
```

那么局部规则就可以覆盖更高层的通用规则。

这实际上就是一种：

> **Hierarchical Configuration（层级配置）**

设计。

---

# 6. CLAUDE.md 的三个扩展机制

## 6.1 `@include` 递归包含

不需要把所有规则全部塞进一个文件。

例如：

```text
CLAUDE.md
```

里面引用：

```text
@docs/java.md
@docs/testing.md
@docs/security.md
```

形成：

```text
CLAUDE.md
   ├── java.md
   ├── testing.md
   └── security.md
```

原材料提到：

* 支持递归 Include
* 最大递归深度有限制
* 有循环检测

目的就是防止：

```text
A → B → C → A
```

导致无限递归。

---

# 7. 条件规则：按路径加载

另一个非常重要的设计是：

> **不是所有规则都必须永远加载。**

例如：

```text
.claude/rules/
├── java.md
├── react.md
└── database.md
```

可以通过路径匹配控制：

```text
src/components/**
```

才加载 React 相关规则。

于是：

```text
修改 Java Service
    ↓
加载 Java Rules

修改 React Component
    ↓
加载 React Rules
```

这实际上是一种：

> **按需上下文注入**

而不是：

> **启动时把所有规则全部塞进 Prompt。**

这样可以减少 Token 消耗。

---

# 8. 双轨注入机制

这是整个指令体系里一个非常值得关注的架构设计。

直觉上，我们可能认为：

```text
所有 Memory
     ↓
System Prompt
     ↓
LLM
```

但材料介绍的 Claude Code 并不是这么做的。

它实际上将：

```text
指令内容
```

和：

```text
Memory 行为规范
```

拆成两个注入通道。

---

## 8.1 Channel A：指令记忆

例如：

```text
CLAUDE.md
```

属于用户或者项目定义的规则。

它通过对话消息通道注入。

---

## 8.2 Channel B：Memory Behavior

这一部分负责告诉模型：

```text
什么东西应该保存？
什么时候保存？
如何召回？
如何更新？
哪些信息不能保存？
```

这属于系统自身的 Memory Protocol。

因此：

```text
          LLM
           ↑
     ┌─────┴─────┐
     │           │
 指令记忆      Memory Protocol
 CLAUDE.md      System Prompt
```

为什么要这么设计？

因为两者性质完全不同：

| 内容   | 指令    | Memory Protocol |
| ---- | ----- | --------------- |
| 来源   | 用户/项目 | 系统              |
| 变化频率 | 高     | 相对稳定            |
| 内容   | 具体规则  | 行为规范            |
| 缓存策略 | 独立    | 独立              |

这样可以实现：

> **不同内容不同缓存，不同内容不同 Token 管理策略。**

---

# 9. 第二层：短期记忆

短期记忆其实就是：

> **当前 Session 的完整对话历史。**

例如：

```text
User Message 1
Assistant Message 1

User Message 2
Assistant Message 2

Tool Call
Tool Result

User Message 3
Assistant Message 3
```

这些内容直接构成当前上下文。

特点是：

```text
准确
完整
但成本越来越高
```

因为：

```text
Conversation 越长
        ↓
Token 越多
        ↓
Context Window 压力越大
```

所以必须进一步引入：

> Session Memory + Compact

---

# 10. 第三层：工作记忆

工作记忆和长期记忆不同。

它主要保存：

> **当前任务执行过程中的临时状态。**

例如：

```text
当前正在修改 PaymentService
当前已经完成数据库层
下一步需要修改 Controller
当前工具调用处于某个状态
当前任务执行到了哪个阶段
```

可以把它理解成：

```text
Long-term Memory
= “我长期知道什么”

Working Memory
= “我现在正在干什么”
```

这对于 Agent 非常重要。

因为 Agent 不只是聊天，而是在执行任务。

---

# 11. 第四层：长期记忆——memdir

这是整个体系最核心的部分之一。

它本质上是：

> **基于磁盘 Markdown 文件构建的分层知识库。**

也就是说：

```text
Memory
   ↓
Markdown Files
   ↓
Index
   ↓
Relevant Retrieval
   ↓
Prompt
```

它不是简单：

```text
memory.txt
```

而是一套：

> **Storage + Index + Retrieval + Update**

系统。

---

# 12. 长期记忆到底应该保存什么？

这是 Memory System 最重要的问题之一：

> **什么信息值得长期记住？**

如果什么都记：

```text
今天修改了 UserService
昨天运行了 mvn test
刚才搜索了 Redis
……
```

最后 Memory 会变成：

> 垃圾场。

所以材料定义了四类值得保存的信息。

---

# 13. Memory Type 1：User

保存：

> 与用户长期相关的信息。

例如：

```text
用户的角色
用户的目标
用户的技能水平
用户的工作习惯
```

作用：

> 构建用户画像，实现个性化协作。

---

# 14. Memory Type 2：Feedback

保存：

> 用户对 Agent 行为的纠正和确认。

例如用户说：

```text
以后不要直接修改数据库表结构。
```

这是一条负反馈。

应该保存。

但一个非常重要的设计是：

> **不仅保存错误反馈，也保存正确反馈。**

例如：

```text
用户：
这次你采用 Redis + Lua 的方案是对的。
以后类似库存扣减问题继续采用这个思路。
```

这也值得记忆。

原因是：

如果系统只记录：

```text
错误
错误
错误
错误
```

Agent 会逐渐变得：

> 过度保守。

而保存正向反馈，可以强化：

```text
这种行为是正确的
        ↓
以后类似问题继续采用
```

这其实和强化学习中的：

> Positive Feedback

思想非常类似。

---

# 15. Memory Type 3：Project

保存：

> 无法单纯从代码推导出的项目上下文。

例如：

```text
项目截止时间
业务目标
团队协作约定
产品目标
架构决策背景
```

这里有一个非常重要的原则：

> **如果信息可以直接从代码中推导出来，就不应该重复保存。**

例如：

```text
项目使用 Redis
```

代码本身就能知道。

没必要保存。

但：

```text
这个 Redis 方案是因为 618 峰值流量而设计的
```

这属于代码无法完全推导出来的背景信息。

因此值得保存。

---

# 16. Memory Type 4：Reference

保存：

> 外部系统的引用。

例如：

```text
Linear Issue
Grafana Dashboard
Slack Channel
外部设计文档
```

它保存的是：

```text
Pointer
```

而不是完整内容。

也就是：

```text
Memory
  ↓
External Reference
  ↓
真正的数据
```

---

# 17. 什么东西不应该进入长期记忆？

这是 Memory System 很高级的一点。

以下内容通常不应该作为长期 Memory：

```text
代码模式
源码结构
文件路径
历史 Debug 方法
可以直接从代码推导出的信息
```

为什么？

因为：

> **代码本身才是 Source of Truth。**

如果 Memory 复制一份：

```text
代码
+
Memory 中的代码描述
```

随着代码变化：

```text
代码 → 新状态
Memory → 旧状态
```

最终就产生：

> **Stale Memory（过期记忆）**

甚至：

> **Memory / Code Contradiction**

所以长期记忆的原则应该是：

```text
无法从 Source of Truth 推导的信息
        ↓
保存

可以从 Source of Truth 推导的信息
        ↓
不要保存
```

这是整个记忆系统非常重要的设计原则。

---

# 18. Memory 的“两层存储结构”

长期记忆并不是把所有文件都直接加载进上下文。

它采用：

```text
Index
  ↓
具体 Memory
```

两层结构。

---

## 18.1 第一层：memory.md

它类似：

> **Memory Index**

例如：

```markdown
# Memory

- [User Profile](user/profile.md) - 用户开发偏好
- [Feedback](feedback/java.md) - Java 代码风格反馈
- [Project](project/payment.md) - 支付项目背景
```

它只负责：

> “告诉系统有哪些记忆。”

而不是：

> “把所有记忆内容都写出来。”

材料提到这个索引有大小限制，例如：

```text
200 行
约 25KB
```

每条索引带有简短摘要。

---

# 19. 第二层：具体 Memory 文件

例如：

```text
user/
    profile.md

feedback/
    java-style.md

project/
    payment.md

reference/
    grafana.md
```

具体内容保存在这些文件中。

所以：

```text
memory.md
```

更像：

```text
数据库索引
```

具体 Memory：

```text
数据库记录
```

---

# 20. 为什么不把所有 Memory 全部加载？

假设：

```text
Memory Files = 500
```

如果每个文件：

```text
2KB
```

那么：

```text
500 × 2KB = 1MB
```

全部放入 Context 显然不现实。

因此必须解决：

> **当前问题到底需要哪些 Memory？**

这就是：

# Dynamic Relevance Retrieval

---

# 21. Prefetch：异步预取机制

每轮对话开始时，系统会启动：

```text
Prefetch
```

它与主 Agent 响应并行执行。

也就是说：

```text
User Query
     │
     ├──────────────→ Main Agent
     │
     └──────────────→ Prefetch
                           │
                           ↓
                     Relevant Memory
```

重点是：

> **Memory Retrieval 不阻塞主流程。**

这样可以降低额外延迟。

---

# 22. Prefetch 是怎么工作的？

大致流程：

```text
扫描 Memory
      ↓
读取每个文件的 Metadata
      ↓
获得描述
      ↓
构造当前 Query Context
      ↓
轻量模型进行相关性判断
      ↓
选择最相关 Memory
      ↓
注入 Agent Context
```

这里有一个关键点：

> 它并不是传统的“关键词搜索”。

而是让一个模型负责：

> **判断哪些 Memory 与当前任务真正相关。**

---

# 23. 为什么不用传统关键词检索？

例如当前问题：

```text
为什么 Redis Lua 脚本这里要保证原子性？
```

传统关键词搜索：

```text
Redis
Lua
Atomic
```

可能召回：

```text
Redis 基础
Redis Cluster
Redis Cache
Redis Stream
Redis Lua
```

但真正有价值的可能只有：

```text
用户曾经确认：
库存扣减必须使用 Lua 保证原子性
```

因此这里需要的不是：

> “文本相似”

而是：

> “语义上是否对当前 Agent 有帮助”。

所以材料强调：

> 使用轻量模型作为独立的 Memory Selection Agent。

---

# 24. Memory Retrieval 的几个限制

为了避免 Memory 污染 Context，它还有一些限制。

例如：

```text
最多返回有限数量的 Memory
```

材料中给出的上限是：

```text
5 篇
```

同时：

```text
不确定 → 不召回
```

以及：

```text
已经展示过的 → 降低重复召回
```

还有：

```text
最近使用过的工具相关文档 → 降低优先级
```

避免：

> Tool Documentation 污染 Memory Context。

---

# 25. Memory Freshness：记忆的新鲜度

Memory 有一个天然的问题：

> **记忆不一定等于当前状态。**

例如：

```text
Memory：
项目使用 Redis Cluster。
```

但三个月之后：

```text
项目已经迁移到 Aerospike。
```

Memory 没有及时更新。

因此：

```text
Memory ≠ Reality
```

材料中特别强调：

> Memory 是一个时间快照，而不是实时状态。

因此系统会给召回的 Memory 增加时间信息。

例如：

```text
今天
昨天
47 天前
```

而不是只告诉模型：

```text
2026-02-14 10:30:00
```

这样模型更容易理解：

```text
这是一条比较旧的信息。
```

如果 Memory 超过一定时间，还会提醒：

> **引用之前需要验证。**

---

# 26. Memory 是怎么写进去的？

前面讲的是：

```text
如何存
如何查
```

现在来看：

> **如何产生 Memory。**

这里使用：

# Extract Memories

---

# 27. 为什么不让主 Agent 自己写 Memory？

假设主 Agent 正在：

```text
分析代码
 ↓
修改代码
 ↓
运行测试
 ↓
修复 Bug
```

突然让它：

```text
暂停
 ↓
总结 Memory
 ↓
修改 memory.md
 ↓
继续任务
```

会导致：

```text
主任务被打断
Token 消耗增加
Agent 行为变复杂
```

所以设计成：

```text
Main Agent
    │
    ├── 执行正常任务
    │
    └── Background Memory Agent
                ↓
           Extract Memory
```

即：

> **Memory Extraction 后台异步执行。**

用户不会感知明显延迟。

---

# 28. 主 Agent 和 Memory Agent 的互斥

这里存在一个典型并发问题：

```text
Main Agent → 写 Memory
Memory Agent → 同时写 Memory
```

可能产生：

```text
Race Condition
Lost Update
File Conflict
```

因此有一个非常重要的互斥设计：

如果主 Agent 最近已经直接修改过 Memory：

```text
Main Agent
    ↓
Memory Updated
```

那么：

```text
Memory Extraction Agent
```

这一次就：

> **不再提取，只推进 Cursor。**

避免双写冲突。

---

# 29. 两回合读写策略

Memory Agent 的一个重要设计是：

```text
Round 1
Read

Round 2
Write
```

而不是：

```text
Read A
Write A
Read B
Write B
Read C
Write C
```

为什么？

因为多个文件之间存在：

```text
Read → Write
```

依赖。

所以可以：

```text
第一轮：

Read A
Read B
Read C
Read D

第二轮：

Write A
Write B
Write C
Write D
```

这样可以最大化并行度。

本质上是：

> **把有依赖的 I/O 阶段分层并行。**

---

# 30. 为什么限制 Memory Agent 的能力？

Memory Agent 并不是一个完整 Agent。

它不应该：

```text
搜索整个互联网
分析整个代码库
获取各种 Lock
调用其他 Agent
调用 MCP
执行任意 Shell
```

因为它的目标非常明确：

> **提取 Memory。**

如果权限过大，它很容易出现：

```text
Memory Extraction
      ↓
发现一个问题
      ↓
开始调查
      ↓
搜索代码
      ↓
搜索文档
      ↓
调用工具
      ↓
陷入调查
```

最后变成：

> Agent 跑偏。

所以采用：

> **最小权限原则（Least Privilege）**

允许：

```text
Read
Search
Memory Directory Write
```

禁止：

```text
任意 Shell Write
MCP
Agent Spawn
```

这是一个非常典型的 Agent 安全设计。

---

# 31. AutoDream：为什么需要“睡眠”？

如果：

```text
Extract Memory
```

相当于：

> 每天记日记。

那么：

```text
AutoDream
```

就是：

> 定期整理日记。

例如：

```text
Day 1
→ Memory A

Day 2
→ Memory B

Day 3
→ Memory C

Day 4
→ Memory D
```

如果永远只增加：

```text
A
B
C
D
E
F
...
```

最终会：

```text
重复
矛盾
过时
碎片化
```

因此必须定期：

> **Consolidation（记忆整合）**

---

# 32. AutoDream 的双重触发门控

AutoDream 不是每轮 Session 都执行。

材料给出的默认触发条件是：

```text
距离上一次整合 ≥ 24 小时
```

并且：

```text
期间至少产生 5 个新的记忆
```

也就是：

```text
24h
 AND
5 Sessions / Drawings
```

两个条件都满足：

```text
        ↓
AutoDream
```

为什么？

因为 Memory Consolidation 是重量级操作：

```text
扫描 Memory
读取日志
检查冲突
合并重复
删除旧信息
更新索引
```

如果每次对话都做：

```text
成本高
延迟高
没有必要
```

所以采用：

> **Time Gate + Activity Gate**

这种思想在后台任务设计中非常常见。

---

# 33. AutoDream 四阶段

AutoDream 不是简单：

```text
LLM：
“帮我总结一下所有 Memory。”
```

而是分成四个阶段。

```text
Orient
  ↓
Gather
  ↓
Consolidate
  ↓
Prune & Index
```

---

## 33.1 Orient：定向

先了解：

```text
Memory Directory
Memory Index
当前有哪些主题
是否存在重复
```

目标：

> 建立全局认知。

---

## 33.2 Gather：收集

进一步查看：

```text
最近日志
相关 Memory
项目当前状态
```

寻找：

```text
新信息
冲突
变化
```

尤其检查：

> 旧 Memory 是否已经和当前代码状态冲突。

---

## 33.3 Consolidate：整合

把：

```text
新 Memory
+
旧 Memory
```

合并成：

```text
更稳定的 Memory
```

而不是：

```text
新建一个重复文件
```

例如：

```text
Redis方案-v1.md
Redis方案-v2.md
Redis方案-new.md
Redis方案-final.md
```

这种设计最终一定会失控。

更好的方式：

```text
Redis方案.md
```

不断更新。

---

# 34. 旧 Memory 怎么处理？

一个很重要的原则：

> **被推翻的旧信息应该删除。**

而不是：

```text
status: deprecated
```

然后永远留着。

原因是：

```text
旧 Memory
    ↓
未来可能被召回
    ↓
模型看到矛盾信息
    ↓
推理混乱
```

所以对于明确失效的信息：

```text
Delete
```

而不是无限堆积。

---

# 35. Prune & Index

最后进行：

```text
Prune
+
Index Update
```

例如：

```text
Memory Index ≤ 200 lines
```

并且：

```text
单条摘要长度受限
```

同时：

```text
删除失效 Pointer
压缩冗余描述
解决冲突
```

最终得到一个：

> **小而精的 Memory Index。**

---

# 36. AutoDream 的并发控制

如果用户同时打开：

```text
Claude Code Terminal A
Claude Code Terminal B
Claude Code Terminal C
```

三个实例都发现：

```text
AutoDream Triggered
```

怎么办？

如果三者同时修改 Memory：

```text
A ─┐
B ─┼→ Memory
C ─┘
```

就会产生竞争。

因此需要：

> **Distributed / Cross-Process Lock**

材料介绍的是基于 Lock File 的方案。

---

# 37. Lock File 的设计

Lock 文件：

```text
memory.lock
```

包含两个核心信息：

```text
mtime
PID
```

其中：

```text
mtime
=
上次整合时间

file content
=
持有者 PID
```

获取锁时：

```text
Write PID
    ↓
Read PID again
    ↓
Compare
```

如果：

```text
写入之后发现 PID 已经不是自己
```

说明：

> 发生并发竞争。

那么当前进程主动退出。

这是一种：

> **CAS-like Ownership Check**

思想。

---

# 38. Session Memory

现在来看另一个非常关键的问题：

> **一个 Session 如果聊了十几个小时怎么办？**

假设：

```text
Context = 100K Tokens
```

继续增加：

```text
110K
120K
150K
...
```

最终：

> Context Window 爆炸。

所以需要：

# Context Compaction

---

# 39. 传统 Compact 的问题

最简单的方法：

```text
旧消息
   ↓
LLM Summarize
   ↓
Summary
   ↓
删除旧消息
```

例如：

```text
100K Tokens
     ↓
摘要
     ↓
10K Tokens
```

看起来很好。

但问题是：

> **摘要是事后一次性生成的。**

LLM 很难在一个时刻准确压缩：

```text
100K Tokens
```

所有重要信息。

很容易丢：

```text
关键决策
错误原因
代码位置
工具执行结果
任务状态
```

---

# 40. Session Memory 的核心思想

它采用：

> **Progressive Memory**

不是：

```text
压缩时才总结
```

而是：

```text
对话过程中
      ↓
后台持续维护
      ↓
session-memory.md
```

因此：

```text
Conversation
   │
   ├── Main Agent
   │
   └── Session Memory Agent
            ↓
       session-memory.md
```

---

# 41. Session Memory 保存什么？

材料中提到固定章节，例如：

```text
Session Title
Current Work State
Task Specification
Key Files / Functions
Workflow Steps
Errors
Corrections
```

也就是说，它更像：

> **项目工作日志 + 当前任务状态快照。**

而不是普通摘要。

---

# 42. Session Memory 的价值

假设 Agent 做一个复杂任务：

```text
1. 找到 PaymentService
2. 修改状态机
3. 修改数据库
4. 修改 MQ
5. 测试失败
6. 定位 Bug
7. 修复
8. 当前正在进行压测
```

普通摘要可能只保留：

```text
已经完成支付状态机改造。
```

但 Session Memory 可以保存：

```text
当前已经完成：
- PaymentService
- DB
- MQ

测试：
- 第一次失败
- 原因是 CAS 条件错误

当前：
- 正在压测

下一步：
- 验证高并发场景
```

这对于 Agent 恢复任务非常重要。

---

# 43. Session Memory 的双阈值触发

它不会每一轮都更新。

需要同时满足：

```text
Context Token 达到一定规模
```

以及：

```text
距离上次更新产生了足够的新 Token / Tool Calls
```

即：

```text
Token Threshold
        AND
Activity Threshold
```

这样避免：

```text
每条消息都写磁盘
```

带来的：

```text
I/O
Token
Agent 调用
```

浪费。

---

# 44. Compact 时如何使用 Session Memory？

当真正发生：

```text
Compact
```

不再让 LLM：

```text
重新阅读整个历史
↓
重新生成 Summary
```

而是直接：

```text
session-memory.md
```

作为压缩后的核心上下文。

所以：

```text
渐进维护
    ↓
高质量 Session Memory
    ↓
Compact
    ↓
直接恢复
```

这比：

```text
临时总结
```

更加稳定。

---

# 45. Compact 的另一个难点：不能随便截断消息

这是非常重要的工程细节。

假设：

```text
Message 1
Message 2
Tool Call
Tool Result
Message 3
```

如果在：

```text
Tool Call
```

和：

```text
Tool Result
```

中间截断：

```text
Tool Call
    X
Tool Result
```

那么 API 可能认为：

> Tool Call 没有对应 Result。

于是请求直接失败。

因此 Compact 不是：

```text
messages[0:n]
```

这么简单。

---

# 46. Tool Call / Tool Result 完整性

系统需要保证：

```text
Tool Call
    ↓
Tool Result
```

必须成对出现。

因此：

```text
Compact Boundary
```

如果正好落在：

```text
Tool Call
```

中间：

```text
自动调整 Boundary
```

直到：

```text
Tool Call
+
Tool Result
```

完整保留。

这本质上是：

> **API Protocol Invariant Preservation**

---

# 47. Streaming Message 的完整性

同样的问题还存在于：

```text
Streaming Response
```

一个模型响应可能被拆成多个：

```text
Thinking Block
Text Block
Tool Block
```

Compact 时不能破坏它们之间的关联。

所以：

> Context Compaction 实际上是一个带协议约束的消息裁剪问题。

而不是简单：

> 删除前 N 条消息。

---

# 48. 团队共享 Memory

个人 Memory 解决：

> “AI 记住我。”

团队 Memory 解决：

> “AI 记住我们团队。”

例如：

```text
开发者 A
开发者 B
开发者 C
       ↓
Team Memory
       ↓
共享项目认知
```

典型内容：

```text
架构决策
团队规范
业务背景
设计约定
重要外部链接
```

---

# 49. Team Memory 的同步策略

材料描述的是：

```text
Pull
Push
```

机制。

核心思想：

> **Server First**

即：

```text
Pull
Server → Local
```

服务端内容优先。

而：

```text
Push
Local → Server
```

只上传变化的条目。

一个值得注意的设计：

> **删除不会传播。**

也就是说：

```text
本地删除
    ↓
Push
    ↓
不会删除 Server
```

下一次 Pull：

```text
Server Memory
    ↓
恢复
```

这样避免：

> 某个开发者误删团队 Memory，影响所有人。

---

# 50. Team Memory 的安全问题

团队 Memory 最大的问题之一：

> **共享范围更大。**

个人 Memory 泄漏：

```text
影响一个人
```

团队 Memory 泄漏：

```text
影响整个团队
```

所以需要更强的安全机制。

材料重点讲了两类：

```text
Path Security
+
Sensitive Data Detection
```

---

# 51. Symlink Escape：符号链接逃逸

假设：

```text
team-memory/
    malicious -> ~/.ssh/
```

如果系统直接：

```text
write(team-memory/malicious/config)
```

文件系统可能跟随：

```text
malicious
    ↓
~/.ssh/
```

最终写入：

```text
~/.ssh/config
```

这就是：

> **Symlink Escape**

属于典型的路径安全问题。

---

# 52. Path Resolve + Real Path

因此写入前需要做两层检查。

第一层：

```text
Path Resolve
```

解决：

```text
../
./
路径规范化
```

第二层：

```text
Real Path
```

检查：

> 实际文件系统路径到底指向哪里。

尤其需要处理：

```text
Symlink
Dangling Symlink
Encoded Path
Unicode Trick
```

原材料特别强调了：

> 悬空 Symlink 也不能简单放过。

---

# 53. Sensitive Data Detection

Team Memory 写入前还需要：

```text
Regex
+
Keyword Filter
```

检查敏感信息，例如：

```text
GitHub Token
AWS Credentials
API Key
Access Token
```

如果发现：

```text
敏感信息
    ↓
Reject
```

为什么？

因为：

```text
Team Memory
     ↓
所有协作者
```

一旦密钥被写入：

> 泄漏面非常大。

因此：

> **共享数据的安全等级必须高于个人数据。**

---

# 54. Agent Persistent Memory

Claude Code 还支持：

> **不同 Agent 拥有自己的长期记忆。**

例如：

```text
Code Review Agent
Test Agent
Debug Agent
Architecture Agent
```

它们不应该共享所有 Memory。

因为不同 Agent 的职责不同。

例如：

```text
Code Review Agent
    ↓
代码规范
Review 经验

Test Agent
    ↓
测试经验
Mock 经验
```

这样可以避免：

> 不同领域的知识相互污染。

---

# 55. Agent Memory 的三个 Scope

材料提到三种作用域：

```text
User
Project
Local
```

可以理解成：

```text
User
跨仓库

Project
团队项目共享

Local
当前机器私有
```

因此：

```text
Agent
  ├── User Memory
  ├── Project Memory
  └── Local Memory
```

可以组合使用。

---

# 56. Memory Snapshot

Agent Memory 还支持：

> **Snapshot**

即：

```text
Memory State
      ↓
Serialize
      ↓
JSON
```

这样就可以：

```text
保存
迁移
复制
模板化
恢复
```

这实际上类似：

> **Memory Checkpoint**

---

# 57. 长生命周期 Agent：Logs Mode

如果是普通 Coding Session：

```text
Memory.md
```

直接更新没问题。

但是如果是：

> 长时间运行的 Agent。

例如：

```text
24 × 7 AI Agent
```

它可能持续产生：

```text
Memory Update
Memory Update
Memory Update
```

如果一直修改：

```text
memory.md
```

就可能出现：

```text
高频写
并发冲突
索引竞争
锁竞争
```

因此引入：

# Logs Mode

---

# 58. Logs Mode 的核心思想

不再直接更新：

```text
memory.md
```

而是：

```text
logs/
    2026-08-20.md
    2026-08-21.md
    2026-08-22.md
```

采用：

> **Append-only Log**

新 Memory：

```text
直接追加日志
```

而：

```text
memory.md
```

变成：

> **只读索引**

然后：

```text
Nightly AutoDream
```

统一整理。

这其实就是典型的：

> **Write Log → Periodic Compaction**

思想。

和很多存储系统：

```text
WAL
LSM Tree
Event Log
```

有相似的工程思想。

---

# 59. 为什么 Prompt 不写死日期？

假设 Prompt 写：

```text
今天写入：

logs/2026-08-23.md
```

然后 Session 一直运行到：

```text
2026-08-24
```

问题来了：

> System Prompt 已经缓存。

如果 Prompt 包含：

```text
2026-08-23
```

那么午夜之后就需要重新计算 Prompt。

因此更好的方式：

```text
logs/YYYY-MM-DD.md
```

运行时：

```text
Context Date
    ↓
Resolve Path
```

这样：

```text
Prompt Cache
```

仍然有效。

这个设计体现的是：

> **缓存内容与动态变量解耦。**

---

# 60. 三层缓存体系

整个 Memory System 还有：

# Three-Level Cache

---

## 60.1 Cache 1：Memory Files Cache

缓存：

```text
Memory 文件解析结果
```

包括：

```text
File Read
Front Matter Parse
Include Processing
HTML Comment Removal
```

这些操作第一次比较昂贵。

因此缓存解析结果。

---

# 61. Cache 2：User Context Cache

缓存：

> 最终拼接出来的 User Context。

例如：

```text
CLAUDE.md
+
User Context
+
Current Date
```

形成：

```text
User Context Object
```

然后缓存。

---

# 62. Cache 3：System Prompt Section Cache

System Prompt 可以拆成多个：

```text
Section
```

例如：

```text
Memory Instructions
Tool Instructions
Agent Instructions
...
```

然后：

```text
Map<sectionName, cachedContent>
```

缓存每个 Section。

材料中提到：

> Memory Prompt 的计算结果可以在整个 Session 中复用。

---

# 63. 为什么三层 Cache 不一起失效？

因为：

> 不同 Cache 的数据生命周期不同。

例如：

```text
Memory Files Cache
```

变化了：

```text
Memory File
```

不代表：

```text
System Prompt
```

一定变化。

所以：

```text
Cache 1
Cache 2
Cache 3
```

采用：

> **独立失效策略。**

例如：

```text
clear
```

可能清：

```text
1 + 2 + 3
```

而：

```text
memory command
```

可能只清：

```text
Cache 1
```

这样可以减少无意义的重新计算。

---

# 64. 为什么不做 CLAUDE.md 热加载？

这是一个非常值得面试讲的设计取舍。

假设：

```text
Agent 正在生成回答
```

与此同时：

```text
用户修改 CLAUDE.md
```

如果立即热加载：

```text
Prompt Rules
     ↓
突然发生变化
```

那么 Agent：

```text
前半段按照规则 A
后半段按照规则 B
```

行为可能不可预测。

因此 Claude Code 更倾向于：

> **明确的 Cache Invalidation，而不是实时 Hot Reload。**

即：

```text
修改文件
   ↓
当前 Cache 不一定立即变化
   ↓
明确触发 Cache Clear
   ↓
下一次重新加载
```

这实际上是：

> **Consistency > Real-time**

的设计取舍。

材料也明确指出，项目根目录的 `CLAUDE.md` 并没有被文件 watcher 做实时热加载。

---

# 65. Feature Flag

最后一个非常重要的工程化设计：

> **Memory System 并不是所有功能永远打开。**

而是通过 Feature Flag 控制。

主要分三类。

---

# 66. 第一类：Remote Feature Flag

可以远程调整：

```text
AutoDream Trigger Interval
Session Memory Token Threshold
Extract Memory Throttling
```

优势：

```text
无需发版
      ↓
远程调整
      ↓
灰度
      ↓
A/B Test
      ↓
快速回滚
```

对于快速迭代中的 AI 产品尤其重要。

---

# 67. 第二类：Compile-time Flag

编译时决定：

```text
Team Memory
Logs Mode
Telemetry
```

特点：

> 运行时不能修改。

适合：

> 产品能力级别的总开关。

---

# 68. 第三类：Environment Variable

例如：

```text
CLAUDE_CODE_DISABLE_AUTO_MEMORY
```

或者：

```text
CLAUDE_CODE_MEMORY_PATH
```

可以在：

```text
部署环境
本地环境
特殊运行模式
```

中覆盖默认行为。

---

# 69. 为什么需要三级 Feature Flag？

可以总结为：

```text
Remote Flag
    ↓
运行期间动态控制

Compile Flag
    ↓
产品功能级控制

Environment Variable
    ↓
部署环境级覆盖
```

形成：

```text
                    Feature Flags
                         │
          ┌──────────────┼──────────────┐
          ↓              ↓              ↓
      Remote          Compile         Env
      动态灰度         功能开关        部署覆盖
```

这套设计适合：

> **快速迭代 + 灰度发布 + 实验性 AI 功能。**

---

# 70. 整套 Memory Architecture 串起来

现在把整个体系放在一起：

```text
                         Claude Code
                              │
              ┌───────────────┴───────────────┐
              │                               │
         Context Layer                    Memory Layer
              │                               │
      ┌───────┼───────┐             ┌─────────┼─────────┐
      │       │       │             │         │         │
   Short   Working  Session      Long-term  Team     Agent
   Memory  Memory   Memory       Memory     Memory   Memory
      │       │       │             │
      │       │       │         ┌───┴────┐
      │       │       │         │        │
      │       │       │       Index   Files
      │       │       │         │
      │       │       │      Retrieval
      │       │       │         │
      └───────┴───────┴─────────┴───────┐
                                         ↓
                                      Context
                                         ↓
                                        LLM
```

后台还有：

```text
Conversation
    ↓
Extract Memories
    ↓
Long-term Memory
    ↓
AutoDream
    ↓
Consolidation
```

以及：

```text
Long Conversation
       ↓
Session Memory
       ↓
Compact
       ↓
Compressed Context
```

---

# 71. 六维记忆的本质区别

可以用一个非常简单的表格理解：

| 类型                | 类比人类    |
| ----------------- | ------- |
| CLAUDE.md         | 规章制度    |
| Short-term Memory | 刚刚发生的对话 |
| Working Memory    | 正在做的事情  |
| Long-term Memory  | 长期经验    |
| Session Memory    | 今天工作的笔记 |
| AutoDream         | 睡觉时整理记忆 |
| Team Memory       | 团队知识库   |

所以它不是：

> “一个 Memory。”

而是：

> **多个不同生命周期、不同可靠性、不同作用域的 Memory System。**

---

# 72. 这套设计最核心的五个工程思想

如果你是从**后端 / AI Agent 面试**角度学习，这部分最值得记。

## 72.1 第一：不要什么都记

Memory 最大的问题不是：

> 存不下来。

而是：

> **存太多。**

所以必须定义：

```text
What to Remember
What NOT to Remember
```

最终形成：

> 高信噪比 Memory。

---

## 72.2 第二：Memory 不等于 Source of Truth

例如：

```text
代码
数据库
外部系统
```

可能才是真正的 Source of Truth。

Memory 只是：

> Context Snapshot。

所以：

```text
Memory
  ↓
帮助 Agent 理解上下文

而不是：

Memory
  ↓
替代真实数据
```

---

# 73. 第三：Memory Retrieval 应该独立于主任务

不要：

```text
Main Agent
    ↓
先找 Memory
    ↓
再干活
```

而是：

```text
                ┌→ Main Agent
User Query ─────┤
                └→ Memory Retrieval
```

二者并行。

这是：

> **Latency Optimization**

也是：

> **Control Plane / Data Plane Separation**

的一种体现。

---

# 74. 第四：Memory Update 应该异步

不要：

```text
用户每说一句
 ↓
立即写 Memory
```

而是：

```text
Conversation
      ↓
后台 Agent
      ↓
Extract
      ↓
Async Write
```

这样：

```text
主链路
低延迟

Memory
最终一致
```

这其实和后端系统中的：

```text
主业务
+
异步 MQ
```

思想非常相似。

---

# 75. 第五：长期记忆必须有生命周期

如果只有：

```text
Write
Read
```

没有：

```text
Update
Delete
Consolidate
```

Memory 最终一定会：

```text
膨胀
重复
矛盾
过期
```

所以完整 Memory Lifecycle 应该是：

```text
Extract
   ↓
Store
   ↓
Retrieve
   ↓
Use
   ↓
Update
   ↓
Consolidate
   ↓
Prune
   ↓
Delete
```

这才是真正成熟的：

> **Memory Lifecycle Management**

---

# 76. 如果让你自己设计一个 Agent Memory System

面试时可以直接按照下面的思路回答。

### 第一步：定义 Memory 类型

```text
User Memory
Project Memory
Feedback Memory
Reference Memory
Session Memory
```

### 第二步：定义 Scope

```text
User
Project
Local
Team
Agent
```

### 第三步：定义 Storage

```text
Index
+
Markdown / KV / DB
```

### 第四步：定义 Retrieval

```text
Current Context
      ↓
Candidate Memory
      ↓
Relevance Model
      ↓
Top-K
      ↓
Context Injection
```

### 第五步：定义 Write

```text
Conversation
      ↓
Async Extractor
      ↓
Memory Classification
      ↓
Validation
      ↓
Write
```

### 第六步：定义 Consolidation

```text
New Memory
+
Existing Memory
      ↓
Dedup
      ↓
Conflict Resolution
      ↓
Update
      ↓
Prune
```

### 第七步：定义安全

```text
Path Validation
Sensitive Data Detection
Least Privilege
Symlink Protection
```

### 第八步：定义缓存

```text
File Cache
Context Cache
Prompt Cache
```

### 第九步：定义 Feature Flag

```text
Remote
Compile
Environment
```

---

# 77. 一句话理解整个架构

如果面试官问：

> **“你怎么看 Claude Code 的 Memory Architecture？”**

可以这样回答：

> Claude Code 的记忆系统并不是简单保存历史对话，而是按照不同生命周期和作用域，将记忆拆分成指令记忆、短期/工作记忆、长期记忆、Session Memory 和 AutoDream 等多个层次。指令层通过层级化的 CLAUDE.md 管理行为规则；长期记忆通过结构化 Markdown 和索引实现持久化，并通过异步相关性召回控制 Token 成本；后台 Agent 负责异步提取记忆，AutoDream 则定期进行去重、冲突消解和索引压缩；对于超长 Session，则通过渐进式 Session Memory 辅助 Context Compaction，避免临时摘要丢失关键信息。同时，团队 Memory 通过路径安全和敏感数据检测控制共享风险，整个体系再结合多级缓存和 Feature Flag 做性能与工程化控制。**本质上，它解决的是 AI Agent 在有限 Context Window 下如何实现长期、可靠、可控记忆的问题。**

---

# 78. 最终架构图

```text
                         ┌──────────────────────┐
                         │       User Query     │
                         └──────────┬───────────┘
                                    │
                  ┌─────────────────┴─────────────────┐
                  │                                   │
                  ↓                                   ↓
          ┌───────────────┐                   ┌──────────────┐
          │   Main Agent  │                   │ Memory Layer │
          └───────┬───────┘                   └──────┬───────┘
                  │                                  │
                  │                     ┌────────────┼─────────────┐
                  │                     │            │             │
                  │                     ↓            ↓             ↓
                  │                  User       Project       Reference
                  │                  Memory      Memory        Memory
                  │                     │            │             │
                  │                     └────────────┼─────────────┘
                  │                                  │
                  │                           Relevance Model
                  │                                  │
                  │                               Top-K
                  │                                  │
                  └──────────────────┬───────────────┘
                                     ↓
                              Context Assembly
                                     │
                                     ↓
                                    LLM
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ↓                                 ↓
             Normal Response                  Background Agent
                                                      │
                                                      ↓
                                               Extract Memory
                                                      │
                                                      ↓
                                               Long-term Store
                                                      │
                                                      ↓
                                                 AutoDream
                                                      │
                                      ┌───────────────┼───────────────┐
                                      ↓               ↓               ↓
                                    Dedup          Conflict         Prune
                                      │               │               │
                                      └───────────────┼───────────────┘
                                                      ↓
                                                  Index Update
```

而长对话则走另一条链路：

```text
Long Conversation
        ↓
Token Threshold
        ↓
Session Memory
        ↓
Progressive Update
        ↓
Context Compact
        ↓
保留 Tool Call / Tool Result 完整性
        ↓
Compressed Context
        ↓
继续执行
```

**最终可以把整套设计概括成一句话：**

> **Claude Code 的 Memory Architecture = 分层记忆 + 按需召回 + 异步写入 + 定期整合 + 渐进式 Session 摘要 + 安全共享 + 多级缓存 + Feature Flag。**

这也是这份材料最值得学习的地方：它真正解决的不是“怎么让 LLM 记住东西”，而是**在信息会不断增长、Context 有上限、记忆会过期、多个 Agent/进程会并发操作、团队还需要共享的情况下，如何把 Memory 做成一个可靠的工程系统。**
