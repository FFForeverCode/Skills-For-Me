Skills are organized under `skills/` by bucket.

- `engineer/` — engineering-focused skills used for coding/design/debugging work.

## Repository conventions

- Every skill directory must contain a primary `SKILL.md` file.
- Optional bilingual docs can coexist (for example `SKILL-EN.md`, `SKILL-CN.md`), but `SKILL.md` is the canonical entry for discovery scripts.
- Each bucket should have its own `README.md` listing all skills in that bucket.
- Top-level `README.md` should link to every active skill in promoted buckets.

## Install / usage model

- Local development install uses symlinks via `scripts/link-skills.sh`.
- Distribution or isolated environments use copy install via `scripts/install-skills.sh`.
- Removal uses `scripts/uninstall-skills.sh`.

After adding/removing/renaming a skill, re-run:

- `npm run skills:list`
- `npm run skills:link` (if you use local linked installs)

