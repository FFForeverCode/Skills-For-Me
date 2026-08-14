# Skills-For-Me

Personal skills repository for Codex / Claude / Agent-Skills style runtimes.

## Languages

- English: [`README.md`](./README.md), [`CLAUDE.md`](./CLAUDE.md), [`AGENTS.md`](./AGENTS.md), [`CONTEXT.md`](./CONTEXT.md)
- 中文: [`README.zh-CN.md`](./README.zh-CN.md), [`CLAUDE.zh-CN.md`](./CLAUDE.zh-CN.md), [`AGENTS.zh-CN.md`](./AGENTS.zh-CN.md), [`CONTEXT.zh-CN.md`](./CONTEXT.zh-CN.md)

## Project structure

- `skills/` — skill buckets and skill directories
- `skills/engineer/` — engineering-focused skill bucket
- `scripts/list-skills.sh` — discover all skills by scanning `SKILL.md`
- `scripts/link-skills.sh` — symlink install for local development
- `scripts/install-skills.sh` — copy install for isolated/runtime environments
- `scripts/uninstall-skills.sh` — uninstall installed skills by name
- `CLAUDE.md` / `AGENTS.md` / `CONTEXT.md` — repository conventions and vocabulary

## Installation

### Option A: Linked install (recommended for local editing)

```bash
npm run skills:link
```

Default destinations:

- `~/.codex/skills`
- `~/.agents/skills`
- `~/.claude/skills`

Install to a custom directory:

```bash
bash scripts/link-skills.sh ~/.codex/skills
```

### Option B: Copy install (recommended for isolation)

```bash
npm run skills:install
```

Default destination:

- `~/.codex/skills`

Install to a custom directory:

```bash
bash scripts/install-skills.sh ~/.agents/skills
```

### Option C: Install by chatting with an LLM

If you are using Codex / Claude / another terminal-capable agent, you can ask it in natural language to install skills from this repository.

Prompt example (linked install):

```text
Please run in /Skills-For-Me:
1) npm run skills:list
2) npm run skills:link
Then send me the command outputs.
```

Prompt example (copy install):

```text
Please run in /Skills-For-Me:
1) npm run skills:list
2) npm run skills:install
And confirm skills are installed to ~/.codex/skills.
```

Prompt example (custom destination):

```text
Please run in /Skills-For-Me:
bash scripts/install-skills.sh ~/.agents/skills
Then list newly added skill directories under ~/.agents/skills.
```

Tip: use `skills:link` during development for real-time updates, and `skills:install` for distribution or isolated environments.

### Option D: Install one specific skill

Use this when you only want one skill (for example: `code-review`).

1) Locate the skill source path:

```bash
npm run skills:list
```

2) Linked install (single skill, good for development):

```bash
mkdir -p ~/.codex/skills
ln -sfn \
  /Skills-For-Me/skills/engineer/code-review \
  ~/.codex/skills/code-review
```

3) Copy install (single skill, good for isolation):

```bash
mkdir -p ~/.codex/skills
rm -rf ~/.codex/skills/code-review
cp -R \
  /Skills-For-Me/skills/engineer/code-review \
  ~/.codex/skills/code-review
```

4) Verify:

```bash
ls -la ~/.codex/skills/code-review
```

## Uninstall

Default uninstall target is `~/.codex/skills`:

```bash
npm run skills:uninstall
```

Uninstall from one custom directory:

```bash
bash scripts/uninstall-skills.sh ~/.agents/skills
```

Uninstall from all common destinations:

```bash
bash scripts/uninstall-skills.sh --all-dests
```

### Uninstall one specific skill

Remove only one skill directory (for example: `code-review`):

```bash
rm -rf ~/.codex/skills/code-review
```

If needed, remove the same skill from other runtimes too:

```bash
rm -rf ~/.agents/skills/code-review
rm -rf ~/.claude/skills/code-review
```

## Usage

List all discoverable skills:

```bash
npm run skills:list
```

After adding/removing a skill, run:

```bash
npm run skills:list
npm run skills:link
```

## Engineer skills

- **[code-review](./skills/engineer/code-review/SKILL.md)**
- **[diagnosing-bugs](./skills/engineer/diagnosing-bugs/SKILL.md)**
- **[improve-codebase-architecture](./skills/engineer/improve-codebase-architecture/SKILL.md)**
- **[write-TRD](./skills/engineer/write-TRD/SKILL.md)**
- **[Karpathy-guidelines](./skills/engineer/Karpathy-guidelines/SKILL.md)**
- **[Mock-Interview](./skills/engineer/Mock-Interview/SKILL.md)**
- **[Mock-Interview-QuestionList-Generation](./skills/engineer/Mock-Interview-QuestionList-Generation/SKILL.md)**
- **[frontend-design](./skills/engineer/front/SKILL-CN.md)**

