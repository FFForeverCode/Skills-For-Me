Skills 按分组组织在 `skills/` 目录下。

- `engineer/`：用于编码、设计、调试等工程场景的技能分组。

## 仓库约定

- 每个技能目录必须包含主入口 `SKILL.md`。
- 可选的双语文档可与主文档并存（如 `SKILL-EN.md`、`SKILL-CN.md`），但发现脚本只以 `SKILL.md` 作为标准入口。
- 每个分组建议维护自己的 `README.md`，列出分组下全部技能。
- 顶层 `README.md` 应链接所有对外启用的主分组技能。

## 安装 / 使用模型

- 本地开发使用 `scripts/link-skills.sh` 做软链接安装。
- 分发或隔离环境使用 `scripts/install-skills.sh` 做复制安装。
- 卸载使用 `scripts/uninstall-skills.sh`。

新增/删除/重命名技能后，建议重新执行：

- `npm run skills:list`
- `npm run skills:link`（如果你使用的是本地软链接安装）
