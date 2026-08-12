---
name: karpathy-guidelines-installer
description: 安装并接入开源 karpathy-guidelines Skill，用于约束 AI 写代码时避免过度设计、偏离业务目标。
---

# Karpathy Guidelines Installer

用于将开源 `karpathy-guidelines` 安装到 Codex 与 Claude Code 的全局 skills 目录，并可选接入 `AGENTS.md`，确保编码任务默认遵循“少过度设计、强业务对齐”的工作方式。

## 适用场景

- 用户明确要求安装 `karpathy-guidelines`。
- 需要给 Codex / Claude Code 增加统一编码规约。
- 需要在仓库 `AGENTS.md` 中强制启用该规约。

## 目标目录

- Codex: `~/.codex/skills/karpathy-guidelines/SKILL.md`
- Claude Code: `~/.claude/skills/karpathy-guidelines/SKILL.md`

目录结构应为：

```text
skills
└── karpathy-guidelines
    └── SKILL.md
```

## 推荐下载地址

- 原仓库页面：`https://github.com/forrestchang/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md`
- 机器可直接下载地址（raw）：`https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/skills/karpathy-guidelines/SKILL.md`

## 安装步骤

### 1) 安装到 Codex

```bash
mkdir -p ~/.codex/skills/karpathy-guidelines
curl -fsSL \
  https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/skills/karpathy-guidelines/SKILL.md \
  -o ~/.codex/skills/karpathy-guidelines/SKILL.md
```

### 2) 安装到 Claude Code

```bash
mkdir -p ~/.claude/skills/karpathy-guidelines
curl -fsSL \
  https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/skills/karpathy-guidelines/SKILL.md \
  -o ~/.claude/skills/karpathy-guidelines/SKILL.md
```

### 3) 验证安装

```bash
ls -la ~/.codex/skills/karpathy-guidelines/SKILL.md
ls -la ~/.claude/skills/karpathy-guidelines/SKILL.md
```

## 可选：接入仓库 AGENTS.md

如果希望“写代码默认带上该规约”，可以在仓库 `AGENTS.md` 增加类似内容：

```md
Coding policy: Always apply karpathy-guidelines for implementation tasks.
Skill path priority:
- ~/.codex/skills/karpathy-guidelines/SKILL.md
- ~/.claude/skills/karpathy-guidelines/SKILL.md
```

## 可直接发给模型的安装指令

### Codex 安装指令

```text
Install karpathy-guidelines: download the https://github.com/forrestchang/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md to ~/.codex/skills/karpathy-guidelines or update AGENTS.md.
```

### Claude Code 安装指令

```text
Install karpathy-guidelines: download the https://github.com/forrestchang/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md to ~/.claude/skills/karpathy-guidelines or update AGENTS.md.
```

## 执行约束

- 只新增/覆盖 `karpathy-guidelines/SKILL.md`，不修改其他第三方技能内容。
- 如果目标目录不存在，先 `mkdir -p`。
- 下载失败时，返回明确错误与重试建议（网络、权限、路径）。
