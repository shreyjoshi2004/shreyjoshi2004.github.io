# shreyjoshi.com

Personal site for Shrey Joshi, built with Jekyll on the
[academic-homepage](https://github.com/luost26/academic-homepage) template.

## Running locally

```bash
bundle install
bundle exec jekyll serve
```

## Verifying

```bash
bin/verify.sh
```

Builds the site and asserts the pages render, the CNAME is intact, no
placeholder content leaked in, and every referenced local asset exists.

## Where content lives

| What | Where |
|---|---|
| Name, bio, education, experience, awards, socials | `_data/profile.yml` |
| Which homepage sections show | `_data/display.yml` |
| Navbar items | `_data/navigation.yml` |
| Publication author links | `_data/authors.yml` |
| Projects | `_projects/*.md` (front matter only; no detail pages) |
| Publications | `_publications/<year>/*.md` |
| Blog posts | `_posts/*.md` |
| Résumé source of truth | `assets/json/resume.json` (not built) |

Template syntax examples live in `docs/template-examples/`, excluded from the
build. Adding a project category means adding it to the `split` list at the top
of `projects.html`.

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which runs
`bundle exec jekyll build` and publishes to GitHub Pages. The custom build is
required because `jekyll-email-protect` is not on the GitHub Pages plugin
allowlist.
