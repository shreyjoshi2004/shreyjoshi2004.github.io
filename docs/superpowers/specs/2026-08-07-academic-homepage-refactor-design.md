# Refactor shreyjoshi.com from al-folio to academic-homepage

**Date:** 2026-08-07
**Status:** Approved design, pending implementation plan
**Branch:** `refactor/academic-homepage`

## Problem

`shreyjoshi2004.github.io` runs [al-folio](https://github.com/alshedivat/al-folio): ~25 Jekyll plugins, a
Docker toolchain, an npm/purgecss build step, and 17 GitHub Actions workflows. Almost none of that
serves the site's actual content, which is thin — 13 projects, a `resume.json`, and a portrait. The
about page, news, blog posts, bookshelf, bibliography, and `_data/cv.yml` are all still upstream
Einstein/lorem boilerplate.

Replace it with [academic-homepage](https://github.com/luost26/academic-homepage): one plugin, no
build toolchain, and a structure that matches what the site actually contains.

## Goals

- Serve real content only. No lorem, no Einstein, no placeholder people on the live domain.
- Shed the al-folio toolchain entirely — Docker, npm, purgecss, and 16 of 17 workflows.
- Keep git history and the `shreyjoshi.com` CNAME.
- Stay mergeable with upstream academic-homepage: no forked or rewritten template widgets.

## Non-goals

- Redesigning the template's visual language.
- Preserving al-folio features with no real content behind them: bookshelf, teaching, repositories,
  the `_bibliography` BibTeX pipeline, and the rendercv CV page.
- Rendering `resume.json` into an on-site CV. It stays in the repo as the source of truth for
  `profile.yml`, but nothing renders it and no `cv_link` is set.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Projects container | New `_projects` collection + `projects.html` | Template has no projects concept; this is the only real content on the site |
| Projects rendering | Reuse `widgets/publication_item.html` **unchanged** | Zero template divergence; upstream updates stay mergeable |
| Sections | Home, Projects, Publications, Blog | Showcase dropped — Projects supersedes it |
| Homepage layout | Layout 2 (full-width `profile_card.html`) | User preference |
| GLAS placement | Both Publications (canonical) and Projects | It is genuinely both; Projects is thin without it |
| Project detail pages | None (`output: false`) | 12 of 13 descriptions are 1–4 sentences and fit inline |
| Template examples | Moved to build-excluded `docs/template-examples/` | Reference value without publishing lorem to the live domain |
| Deploy | One Actions workflow running `bundle exec jekyll build` | `jekyll-email-protect` is not on GitHub Pages' plugin allowlist |
| CV | Dropped | No rendered CV PDF exists in the repo |
| `positions` on profile card | Omitted | UTD ended May 2026; current role unknown |

## Architecture

### File disposition

**Deleted (al-folio):**

```
_layouts/  _includes/  _sass/  _plugins/  _scripts/  bin/  _data/  _pages/
_posts/  _news/  _projects/  _books/  _teachings/  _bibliography/
assets/css/  assets/js/  assets/libs/
Dockerfile  docker-compose.yml  docker-compose-slim.yml  .dockerignore
package.json  package-lock.json  purgecss.config.js  requirements.txt
.devcontainer/  .pre-commit-config.yaml  .prettierrc  .prettierignore
lighthouse_results/  readme_preview/  .all-contributorsrc  .lycheeignore
.git-blame-ignore-revs  .gitattributes
ANALYTICS.md  CONTRIBUTING.md  CUSTOMIZE.md  FAQ.md  INSTALL.md
QUICKSTART.md  SEO.md  TROUBLESHOOTING.md  README.md
.github/workflows/  (all 17)
Gemfile  Gemfile.lock  _config.yml
```

**Retained from the current repo:**

```
.git/                      history
CNAME                      shreyjoshi.com
LICENSE                    MIT, still applicable
CLAUDE.md  AGENTS.md       agent instructions (rewritten for the new stack)
assets/json/resume.json    source of truth for profile.yml
```

**Copied from academic-homepage:**

```
_layouts/  _includes/  _data/
assets/css/                              includes css/images/loading.gif
assets/js/
assets/images/empty_300x200.png          lazyload placeholder, referenced by widgets
publications.html  blog.html  404.html
Gemfile  .gitignore  _config.yml
index_layout2.html  ->  index.html       (Layout 2 chosen)
```

Not copied: `index.html` (Layout 1), `showcase.html`, `_showcase/`, `README.md`,
`.github/ISSUE_TEMPLATE/`, and the template's demo imagery — `assets/images/covers/cover{1,2,3}.jpg`,
`etc/` (cat photos, `tim_the_beaver.png`, `preview.png`), `photos/portrait.jpg`, and `badges/`
(MIT/PKU logos). `assets/images/covers/` is reused for Shrey's own project thumbnails.

A new short `README.md` is written describing the site, its stack, and how to run it locally —
replacing both al-folio's and the template's.

### `_config.yml`

Template's config with three edits:

```yaml
baseurl: ""            # user site on a custom domain, not a project site
collections:
  - publications
  - news
  - posts
  - projects           # added
exclude:
  - docs/              # specs + template-examples must not be built
  - assets/json/       # resume.json is a data source, not a page
```

The template declares collections in Jekyll's sequence form, under which `output` defaults to
`false`. `_projects` therefore generates no per-project pages without any extra configuration, and
the sequence form is retained rather than converting to the mapping form. Verification step 5
asserts this rather than assuming it.

### Projects page

`projects.html` mirrors `publications.html` but groups by `category` rather than year, and sorts
within each group by `importance` ascending:

Group order is **work, then fun**, stated explicitly rather than left to `group_by`'s
first-appearance ordering:

```liquid
{% assign categories = "work,fun" | split: "," %}
{% assign sorted = site.projects | sort: "importance" %}
{% for cat in categories %}
  {% assign items = sorted | where: "category", cat %}
  {% if items.size > 0 %}
    <h2 class="pt-4" id="cat-{{ cat }}">{{ cat | capitalize }}</h2>
    <div class="my-0 p-0 bg-white shadow-sm rounded-xl">
      {% for item in items %}
        {% include widgets/publication_item.html item=item
           hide_bottom_border=forloop.last first=forloop.first last=forloop.last %}
      {% endfor %}
    </div>
  {% endif %}
{% endfor %}
```

Driving the loop from a literal category list makes the order independent of `importance` values and
of how many projects each category holds, and skips a heading if a category is ever emptied. Adding a
third category means adding it to that one list.

Field mapping onto `publication_item.html` — every field degrades gracefully, so no widget change is
needed:

| Widget field | Project value | Absent-value behavior |
|---|---|---|
| `cover` | existing thumbnail | falls back to generated bubble-hash SVG |
| `title` | project name | — |
| `authors` | omitted | `author_list.html` renders nothing |
| `pub` | tech stack, e.g. `Rust · sixel` | renders italic |
| `pub_date` | year | — |
| `abstract` | one-line description | — |
| `links` | `{Code: ..., crates.io: ...}` | loop renders nothing |

### Data files

**`_data/profile.yml`** — all values below are already present in `assets/json/resume.json` or the
existing `_projects/*.md`, except `short_bio` (see Open Items).

- `primary_name` / `navbar_name`: Shrey Joshi; `secondary_name`: empty
- `positions`: omitted
- `email`: shreyjoshi2004@gmail.com
- `github`: ShreyJ1729 · `linkedin`: sjoshi1729 · no `gscholar`, no `twitter`, no `orcid`
- `portrait_url`: `/assets/images/photos/portrait.jpg`; no `portrait_caption`
- `education`: UT Dallas — B.A. Philosophy, minor in Computer Science — Aug 2022 – May 2026 —
  full-ride National Merit Scholar
- `experience`: PwC, SWE Intern (Jun–Aug 2024) · Minion AI, Software Engineer (Jan–Feb 2023) ·
  UT Austin, Machine Learning Researcher (Aug 2020 – Apr 2022)
- `awards`: ISEF 1st Grand Prize, $10,000 (2021) · Codon Digest Winner, Bio×ML Hackathon (2023) ·
  National Merit Scholar, full ride (2022)

No `logo` values are set on education/experience entries — the repo contains no institution logos,
and `experience_card.html` renders a broken `<img>` for a missing `logo`. The implementation must
either supply logos or confirm the widget degrades cleanly; if it does not, omit the `<img>` via the
data rather than by editing the widget.

**`_data/display.yml`**

```yaml
homepage:
  show_experience: true
  show_news: false                  # no real news items exist
  show_selected_publications: true
  num_news: 10
```

`footer_text` retains the upstream template attribution link.

**`_data/navigation.yml`** — Home `/`, Projects `/projects`, Publications `/publications`,
Blog `/blog`. Each `name` must match the corresponding page's `navbar_title` for nav highlighting.

**`_data/authors.yml`** — `Shrey Joshi` (`bold: true`), `Ishaan Javali`, `Ellen Rathje`.

### Publications

One entry, `_publications/2021/2021-glas.md`:

- `title`: "GLAS: Global Landslide Analytics System"
- `selected: true` (surfaces on the homepage)
- `pub`: IEEE MIT Undergraduate Research Technology Conference (URTC) · `pub_date`: 2021
- `authors`: Shrey Joshi\*, Ishaan Javali\*, Ellen Rathje
- `abstract`: condensed from `_projects/1_project.md`
- `cover`: `/assets/images/covers/susmap.png`
- `links`: IEEE Xplore (`https://doi.org/10.1109/URTC54388.2021.9701628`), Code
  (`https://github.com/Landslide-Analytics-System`), Poster (`/assets/pdf/poster.pdf`)

### Blog

`blog.html` and `_layouts/blog_post.html` are copied as-is. `_posts/` ships **empty** — the
template's three lorem posts move to `docs/template-examples/_posts/`. The blog page renders with no
entries until real posts are written.

### Assets

| Source | Destination | Note |
|---|---|---|
| `assets/img/prof_pic_color.png` | `assets/images/photos/portrait.jpg` | resize 2880×3840 → max 800px, convert to JPEG |
| `assets/img/rusty.png` | `assets/images/covers/rusty.png` | Rusty Chess |
| `assets/img/mazegen.png` | `assets/images/covers/mazegen.png` | MazeGen |
| `assets/img/super-mario-mips.png` | `assets/images/covers/super-mario-mips.png` | MIPS Mario |
| `assets/img/bioconceptxplorer.jpeg` | `assets/images/covers/bioconceptxplorer.jpeg` | BioConceptXplorer |
| `assets/img/susmap.png` | `assets/images/covers/susmap.png` | GLAS |
| `assets/pdf/poster.pdf` | `assets/pdf/poster.pdf` | unchanged |
| `assets/json/resume.json` | unchanged | build-excluded |

Dropped: `assets/img/{1..12}.jpg` (generic stock), `prof_pic.jpg` (608×607, superseded by the
higher-resolution color original), `example_pdf.pdf`, `template_error.png`, `thumbnail.png`,
`book_covers/`, `publication_preview/`.

Projects without a real thumbnail omit `cover` and render the template's deterministic bubble-hash
SVG.

### Deploy

`.github/workflows/deploy.yml` — the only workflow. Checkout → `ruby/setup-ruby` with bundler cache
→ `bundle exec jekyll build` → `actions/upload-pages-artifact` → `actions/deploy-pages`. Triggers on
push to `main` and on `workflow_dispatch`.

This replaces GitHub Pages' native build because `jekyll-email-protect` is not on the Pages plugin
allowlist. Under the native build, the unknown `encode_email` Liquid filter passes its input through
silently and the email address ships as scrapeable plaintext — a silent failure, not a build error.

**Repository setting change required:** Pages source must be switched from "Deploy from a branch"
(`gh-pages`) to "GitHub Actions". This is a manual step in repo settings that the implementation
cannot perform; the stale `gh-pages` branch is deleted afterward.

## Verification

1. `bundle install && bundle exec jekyll build` completes with no errors or warnings.
2. `bundle exec jekyll serve` — all four pages render; navbar highlights the active page on each.
3. Content greps over built `_site/` return zero hits: `lorem`, `Lorem`, `Einstein`, `Your Name`,
   `example.com`, `your@email.com`, `bicolor cat`, `academic-homepage/assets`.
4. `_site/CNAME` exists and contains `shreyjoshi.com`.
5. `_site/` contains no `projects/<name>/index.html` — confirms `output: false`.
6. All 13 projects appear on `/projects`, grouped work-then-fun, ordered by `importance`.
7. GLAS appears on `/publications`, on `/projects`, and in the homepage's Selected Publications.
8. Every internal link resolves; no `<img>` resolves to a missing file (crawl `_site/`).
9. Email address does not appear in plaintext in `_site/index.html`.
10. `docs/` and `assets/json/` are absent from `_site/`.

## Open items

**`short_bio` requires review.** No bio exists anywhere in the repo, so the following draft is
constructed strictly from facts already in `resume.json` and `_projects/`. It invents no claims, but
it is written in Shrey's voice by an agent and must be read before merge:

> I'm a software engineer interested in systems programming, machine learning infrastructure, and
> the places where the two meet. I recently finished a B.A. in Philosophy with a Computer Science
> minor at the University of Texas at Dallas, where I studied on a full-ride National Merit
> scholarship.
>
> My research background is in applied machine learning for geoscience. Working with Dr. Ellen
> Rathje at UT Austin, I built GLAS, a global landslide analytics system trained on GLIF — a dataset
> compiled from roughly 200GB of geophysical data across six sources. That work took a first grand
> prize at ISEF and was published at the 2021 IEEE MIT URTC.
>
> Since then I've worked as a software engineer at PwC and Minion AI, and I spend most of my free
> time writing Rust: a chess engine built on magic bitboards, a terminal video-calling client that
> renders frames as sixel graphics, and the FFI bindings underneath it.

**Deferred, non-blocking:** current position/affiliation for the profile card; a rendered CV PDF and
its `cv_link`; a Google Scholar ID; institution logos for education and experience entries.

**Known discrepancy to resolve during implementation:** `resume.json` gives TermCall's URL as
`ShreyJ1729/termcall` while `_projects/3_project.md` gives `ShreyJ1729/termcall-rs`. The project file
is newer and is treated as authoritative; the link must be confirmed live before merge.
