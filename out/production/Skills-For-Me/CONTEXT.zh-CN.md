# Skills-For-Me Context

本仓库是一个面向编码代理的个人技能集合。

## 领域术语

- **Skill（技能）**：一个以 `SKILL.md` 作为根入口的能力包目录。
- **Bucket（分组）**：`skills/` 下的分类目录（当前为 `engineer/`）。
- **Linked install（软链接安装）**：基于符号链接的本地安装方式，适合迭代编辑。
- **Copy install（复制安装）**：基于文件复制的安装方式，适合隔离执行环境。

## 关系

- 一个 **Bucket** 包含多个 **Skill**。
- 当目录中存在 `SKILL.md` 时，该 **Skill** 可被发现。
- 安装脚本操作的对象是“可发现技能”的全集。
