# Skills-For-Me

面向 Codex / Claude / Agent-Skills 运行时的个人技能仓库。

## 文档语言

- English: [`README.md`](./README.md), [`CLAUDE.md`](./CLAUDE.md), [`AGENTS.md`](./AGENTS.md), [`CONTEXT.md`](./CONTEXT.md)
- 中文: [`README.zh-CN.md`](./README.zh-CN.md), [`CLAUDE.zh-CN.md`](./CLAUDE.zh-CN.md), [`AGENTS.zh-CN.md`](./AGENTS.zh-CN.md), [`CONTEXT.zh-CN.md`](./CONTEXT.zh-CN.md)

## 项目结构

- `skills/`：技能分组目录和技能目录
- `skills/engineer/`：工程类技能分组
- `scripts/list-skills.sh`：扫描 `SKILL.md` 发现全部技能
- `scripts/link-skills.sh`：用于本地开发的软链接安装
- `scripts/install-skills.sh`：用于隔离/运行环境的复制安装
- `scripts/uninstall-skills.sh`：按技能名卸载已安装技能
- `CLAUDE.md` / `AGENTS.md` / `CONTEXT.md`：仓库约定与术语说明

## 安装

### 方式 A：软链接安装（推荐本地编辑）

```bash
npm run skills:link
```

默认安装目标：

- `~/.codex/skills`
- `~/.agents/skills`
- `~/.claude/skills`

安装到自定义目录：

```bash
bash scripts/link-skills.sh ~/.codex/skills
```

### 方式 B：复制安装（推荐隔离环境）

```bash
npm run skills:install
```

默认安装目标：

- `~/.codex/skills`

安装到自定义目录：

```bash
bash scripts/install-skills.sh ~/.agents/skills
```

### 方式 C：通过和大模型对话安装

如果你使用 Codex / Claude / 其他可执行终端命令的代理，也可以通过自然语言让它安装本仓库技能。

提示词示例（软链接安装）：

```text
请在 /Skills-For-Me 目录执行：
1) npm run skills:list
2) npm run skills:link
执行完成后把输出结果发给我。
```

提示词示例（复制安装）：

```text
请在 /Skills-For-Me 目录执行：
1) npm run skills:list
2) npm run skills:install
并确认已安装到 ~/.codex/skills。
```

提示词示例（自定义目录）：

```text
请在 /Skills-For-Me 目录执行：
bash scripts/install-skills.sh ~/.agents/skills
然后列出 ~/.agents/skills 下新增的技能目录。
```

建议：开发阶段优先用 `skills:link`（实时生效），分发或隔离环境优先用 `skills:install`。

### 方式 D：安装单个指定 Skill

当你只想安装某一个技能（例如：`code-review`）时，使用以下方式。

1) 先确认技能路径：

```bash
npm run skills:list
```

2) 软链接安装（单个技能，适合开发调试）：

```bash
mkdir -p ~/.codex/skills
ln -sfn \
  /Skills-For-Me/skills/engineer/code-review \
  ~/.codex/skills/code-review
```

3) 复制安装（单个技能，适合隔离环境）：

```bash
mkdir -p ~/.codex/skills
rm -rf ~/.codex/skills/code-review
cp -R \
  /Skills-For-Me/skills/engineer/code-review \
  ~/.codex/skills/code-review
```

4) 验证安装：

```bash
ls -la ~/.codex/skills/code-review
```

## 卸载

默认从 `~/.codex/skills` 卸载：

```bash
npm run skills:uninstall
```

从指定目录卸载：

```bash
bash scripts/uninstall-skills.sh ~/.agents/skills
```

从常见目录全部卸载：

```bash
bash scripts/uninstall-skills.sh --all-dests
```

### 卸载单个指定 Skill

仅删除一个技能目录（例如：`code-review`）：

```bash
rm -rf ~/.codex/skills/code-review
```

如有需要，也可同时从其他运行时目录删除同名技能：

```bash
rm -rf ~/.agents/skills/code-review
rm -rf ~/.claude/skills/code-review
```

## 使用

列出仓库中可发现的技能：

```bash
npm run skills:list
```

新增/删除技能后建议执行：

```bash
npm run skills:list
npm run skills:link
```

## Engineer 分组技能

- **[code-review](./skills/engineer/code-review/SKILL.md)**
- **[diagnosing-bugs](./skills/engineer/diagnosing-bugs/SKILL.md)**
- **[improve-codebase-architecture](./skills/engineer/improve-codebase-architecture/SKILL.md)**
- **[write-TRD](./skills/engineer/write-TRD/SKILL.md)**
- **[Mock-Interview](./skills/engineer/Mock-Interview/SKILL.md)**
- **[Mock-Interview-QuestionList-Generation](./skills/engineer/Mock-Interview-QuestionList-Generation/SKILL.md)**
