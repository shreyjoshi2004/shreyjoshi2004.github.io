# Agent notes

Jekyll site on the academic-homepage template. See `README.md` for structure.

## Rules

- Never modify files under `_includes/widgets/` or `_layouts/`. They are upstream
  template files and the repo is kept mergeable with upstream. If a widget appears
  to need changing, change the data feeding it instead.
- Run `bin/verify.sh` before committing. It must exit 0.
- `baseurl` is empty — this is a user site on a custom domain. Never set it.
- `CNAME` must always contain `shreyjoshi.com`.
- Content goes in `_data/profile.yml`, `_projects/`, `_publications/`, `_posts/`.
- No placeholder or lorem content may reach the build; `bin/verify.sh` enforces this.
