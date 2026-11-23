# shreyjoshi.com

Rails app (single page, no database use) exported to static files and served by GitHub Pages at https://shreyjoshi.com.

- Local dev: `bin/rails server`
- Static build: `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile static:build` → `dist/`
- Deploy: pushing to `main` runs `.github/workflows/pages.yml`, which builds `dist/` and publishes it. Pages source must be "GitHub Actions".
- Custom domain: `public/CNAME` (copied into `dist/`).
