# academic-homepage Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace al-folio with the academic-homepage template on `shreyjoshi.com`, carrying over only real content and shedding the Docker/npm/17-workflow toolchain.

**Architecture:** A single Jekyll site built from the academic-homepage template with one added collection (`_projects`) rendered by an existing template widget. No template widget is forked or modified, so the repo stays mergeable with upstream. All personal data lives in `_data/profile.yml`, derived from the existing `assets/json/resume.json`.

**Tech Stack:** Jekyll 3.9, `jekyll-email-protect`, Bootstrap 4.6 + Font Awesome 6 (CDN), GitHub Actions → GitHub Pages.

## Global Constraints

- Branch: `refactor/academic-homepage`. Never commit to `main`.
- `CNAME` must contain `shreyjoshi.com` and survive every task.
- No template file under `_includes/widgets/` or `_layouts/` may be modified. If a widget seems to need a change, change the data feeding it instead.
- `baseurl` is `""` — this is a user site on a custom domain.
- No lorem, `Einstein`, `Your Name`, `your@email.com`, `bicolor cat`, or cat imagery may appear in built output.
- Homepage uses **Layout 2** (full-width `profile_card.html`).
- Projects render via `widgets/publication_item.html`, unchanged.
- Project category order is **work, then fun**, driven by a literal list in `projects.html`.
- `_projects` generates no per-project pages.
- Every task ends with `bin/verify.sh` passing the checks available at that point, then a commit.

---

### Task 1: Verification harness

The site has no test framework — it's static Jekyll. `bin/verify.sh` is the test suite: it encodes the spec's verification criteria as assertions over built output. It is written first and fails first.

**Files:**
- Create: `bin/verify.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `bin/verify.sh`, run with no arguments from repo root. Exits `0` if all checks pass, `1` otherwise. Prints `PASS`/`FAIL` per check. Every later task runs it.

- [ ] **Step 1: Write the verification script**

```bash
#!/usr/bin/env bash
# Verification suite for shreyjoshi.com. Run from repo root: bin/verify.sh
set -uo pipefail

FAILED=0
SITE="_site"

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED=1; }

# assert_absent <description> <pattern>  -- pattern must NOT appear in built site
assert_absent() {
  local desc="$1" pat="$2"
  if grep -rqi -- "$pat" "$SITE" 2>/dev/null; then
    fail "$desc (found '$pat')"
  else
    pass "$desc"
  fi
}

# assert_file <description> <path>
assert_file() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then pass "$desc"; else fail "$desc (missing $path)"; fi
}

# assert_contains <description> <path> <pattern>
assert_contains() {
  local desc="$1" path="$2" pat="$3"
  if [ -f "$path" ] && grep -qi -- "$pat" "$path"; then
    pass "$desc"
  else
    fail "$desc (expected '$pat' in $path)"
  fi
}

# assert_count <description> <expected> <path> <pattern>
assert_count() {
  local desc="$1" want="$2" path="$3" pat="$4"
  local got
  got=$(grep -c -- "$pat" "$path" 2>/dev/null || echo 0)
  if [ "$got" -eq "$want" ]; then
    pass "$desc ($got)"
  else
    fail "$desc (want $want, got $got)"
  fi
}

echo "==> Building site"
if bundle exec jekyll build --quiet; then
  pass "jekyll build succeeds"
else
  fail "jekyll build succeeds"
  echo "Build failed; skipping output checks."
  exit 1
fi

# Pages live at the repo root with no `permalink`, so Jekyll emits
# `_site/<name>.html` — not `_site/<name>/index.html`.
echo "==> Pages exist"
assert_file "homepage renders"      "$SITE/index.html"
assert_file "publications renders"  "$SITE/publications.html"
assert_file "projects renders"      "$SITE/projects.html"
assert_file "blog renders"          "$SITE/blog.html"
assert_file "404 renders"           "$SITE/404.html"

echo "==> Domain"
assert_file     "CNAME published"  "$SITE/CNAME"
assert_contains "CNAME correct"    "$SITE/CNAME" "shreyjoshi.com"

echo "==> No placeholder content"
assert_absent "no lorem ipsum"        "lorem ipsum"
assert_absent "no Einstein"           "einstein"
assert_absent "no 'Your Name'"        "your name"
assert_absent "no template email"     "your@email.com"
assert_absent "no bicolor cat bio"    "bicolor cat"
assert_absent "no template baseurl"   "/academic-homepage/assets"
assert_absent "no al-folio leftovers" "al-folio"

echo "==> Build hygiene"
if [ -d "$SITE/docs" ]; then fail "docs/ excluded from build"; else pass "docs/ excluded from build"; fi
if [ -d "$SITE/assets/json" ]; then fail "resume.json excluded from build"; else pass "resume.json excluded from build"; fi
# With `output: false` the collection emits no `_site/projects/` directory at
# all. Asserting on the directory catches any per-item page, whatever its name.
if [ -d "$SITE/projects" ]; then
  fail "_projects generates no detail pages"
else
  pass "_projects generates no detail pages"
fi

echo "==> Content"
assert_contains "name on homepage"          "$SITE/index.html" "Shrey Joshi"
assert_contains "education present"         "$SITE/index.html" "University of Texas at Dallas"
assert_contains "awards present"            "$SITE/index.html" "ISEF"
assert_contains "GLAS on homepage"          "$SITE/index.html" "GLAS"
assert_contains "GLAS on publications"      "$SITE/publications.html" "GLAS"
assert_contains "GLAS on projects"          "$SITE/projects.html" "GLAS"
assert_contains "work category heading"     "$SITE/projects.html" "id=\"cat-work\""
assert_contains "fun category heading"      "$SITE/projects.html" "id=\"cat-fun\""

echo "==> Email obfuscation"
if grep -q "shreyjoshi2004@gmail.com" "$SITE/index.html" 2>/dev/null; then
  fail "email obfuscated (plaintext address found)"
else
  pass "email obfuscated"
fi

echo "==> Assets referenced by the site all exist"
# Read via process substitution, not a pipe: a piped `while` runs in a subshell,
# so assignments to `missing` inside it would be discarded and this check would
# always report PASS.
missing=0
while read -r ref; do
  [ -f "$SITE$ref" ] || { echo "    missing asset: $ref"; missing=1; }
done < <(grep -rhoE '(src|href)="/(assets|images)/[^"]+"' "$SITE" 2>/dev/null \
           | sed -E 's/^(src|href)="//; s/"$//' | sort -u)
if [ "$missing" -eq 0 ]; then
  pass "no missing local assets"
else
  fail "no missing local assets"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  printf '\033[32mAll checks passed.\033[0m\n'
else
  printf '\033[31mSome checks failed.\033[0m\n'
fi
exit "$FAILED"
```

- [ ] **Step 2: Make it executable and run it to verify it fails**

Run:
```bash
chmod +x bin/verify.sh && bin/verify.sh
```

Expected: FAIL. The al-folio site is still in place, so `jekyll build` either fails outright (missing gems) or the Einstein/lorem assertions fail. Either outcome is the expected red state.

- [ ] **Step 3: Commit**

```bash
git add bin/verify.sh
git commit -m "test: add verification harness for site migration"
```

---

### Task 2: Replace al-folio with the template skeleton

**Files:**
- Delete: al-folio tree (enumerated below)
- Create: `_config.yml`, `Gemfile`, `.gitignore`, `index.html`, `.github/workflows/deploy.yml`, `docs/template-examples/`
- Copy: `_layouts/`, `_includes/`, `_data/`, `assets/css/`, `assets/js/`, `assets/images/empty_300x200.png`, `publications.html`, `blog.html`, `404.html`

**Interfaces:**
- Consumes: `bin/verify.sh` from Task 1.
- Produces: a building site with template defaults. `_data/profile.yml`, `_data/display.yml`, `_data/navigation.yml`, `_data/authors.yml` exist with template content (replaced in Task 4). `assets/images/covers/` exists and is empty (filled in Task 3).

- [ ] **Step 1: Remove the al-folio tree**

```bash
git rm -rq _layouts _includes _sass _plugins _scripts bin/cibuild bin/deploy \
  bin/entry_point.sh bin/update_scholar_citations.py _data _pages _posts _news \
  _projects _books _teachings _bibliography assets/css assets/js \
  .devcontainer lighthouse_results readme_preview .github/workflows
git rm -q Dockerfile docker-compose.yml docker-compose-slim.yml .dockerignore \
  package.json package-lock.json purgecss.config.js requirements.txt \
  .pre-commit-config.yaml .prettierrc .prettierignore .all-contributorsrc \
  .lycheeignore .git-blame-ignore-revs .gitattributes \
  ANALYTICS.md CONTRIBUTING.md CUSTOMIZE.md FAQ.md INSTALL.md QUICKSTART.md \
  SEO.md TROUBLESHOOTING.md README.md Gemfile Gemfile.lock _config.yml
```

Note: `bin/verify.sh` is preserved — only al-folio's four scripts under `bin/` are removed.

- [ ] **Step 2: Copy the template in**

```bash
T=/Users/shreyjoshi/dev/academic-homepage
cp -R "$T/_layouts" "$T/_includes" "$T/_data" .
cp -R "$T/assets/css" "$T/assets/js" assets/
mkdir -p assets/images/covers assets/images/photos
cp "$T/assets/images/empty_300x200.png" assets/images/
cp "$T/publications.html" "$T/blog.html" "$T/404.html" "$T/Gemfile" "$T/.gitignore" .
cp "$T/index_layout2.html" index.html
```

Layout 2 was chosen, so `index_layout2.html` becomes `index.html`; Layout 1 and `showcase.html`/`_showcase/` are never copied.

- [ ] **Step 3: Fix the homepage front matter**

`index.html` arrives with Layout 2's navbar title. Replace its front matter block so it is the canonical home page:

```yaml
---
layout: default
title : Homepage
navbar_title: Home
---
```

- [ ] **Step 4: Relocate template example content**

The template's example posts/news/publications are kept as syntax reference but must never build.

```bash
T=/Users/shreyjoshi/dev/academic-homepage
mkdir -p docs/template-examples
cp -R "$T/_posts" "$T/_news" "$T/_publications" "$T/_showcase" docs/template-examples/
cp "$T/index.html" docs/template-examples/index_layout1.html
cp "$T/showcase.html" docs/template-examples/
mkdir -p _posts _news _publications _projects
```

- [ ] **Step 5: Write `_config.yml`**

```yaml
title: Shrey Joshi
description: Personal website of Shrey Joshi.
url: "https://shreyjoshi.com"
baseurl: ""

markdown: kramdown
plugins:
  - jekyll-email-protect

collections:
  - publications
  - news
  - showcase
  - posts
  - projects

exclude:
  - docs/
  - assets/json/
  - bin/
  - Gemfile
  - Gemfile.lock
  - README.md
  - vendor/
```

`collections` uses Jekyll's sequence form, under which `output` defaults to `false`. `_projects` therefore produces no detail pages with no further configuration — Task 6 asserts this. `showcase` is retained in the list so the collection is declared if a Showcase page is ever added; with no `_showcase/` directory it contributes nothing.

- [ ] **Step 6: Write `.github/workflows/deploy.yml`**

```yaml
name: Deploy site

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.2"
          bundler-cache: true
      - name: Build site
        run: bundle exec jekyll build
        env:
          JEKYLL_ENV: production
      - uses: actions/upload-pages-artifact@v3
        with:
          path: _site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

This replaces GitHub Pages' native build. `jekyll-email-protect` is not on the Pages plugin allowlist, and under the native build the unknown `encode_email` filter passes its input through silently — shipping the email as scrapeable plaintext with no build error.

- [ ] **Step 7: Install gems and run verification**

Run:
```bash
bundle install && bin/verify.sh
```

Expected: `jekyll build succeeds` PASSES and all five page checks PASS. The "No placeholder content" and "Content" sections still FAIL — `_data/profile.yml` is still the template's `Your Name` / bicolor-cat default, and no projects or publications exist yet. `projects renders` also FAILS (no `projects.html` until Task 6). This is the expected intermediate state.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: replace al-folio with academic-homepage skeleton

Removes ~25 plugins, the Docker/npm/purgecss toolchain, and all 17
workflows. Adds the template with Layout 2 as the homepage and a single
Actions workflow that runs bundle exec jekyll build, required because
jekyll-email-protect is not on GitHub Pages' plugin allowlist."
```

---

### Task 3: Migrate assets

**Files:**
- Create: `assets/images/photos/portrait.jpg`, `assets/images/covers/*.{png,jpeg}`
- Delete: `assets/img/`
- Keep: `assets/pdf/poster.pdf`, `assets/json/resume.json`

**Interfaces:**
- Consumes: `assets/images/covers/` and `assets/images/photos/` from Task 2.
- Produces: exact cover paths referenced by Tasks 5 and 6 —
  `/assets/images/covers/susmap.png`, `rusty.png`, `mazegen.png`,
  `super-mario-mips.png`, `bioconceptxplorer.jpeg`; portrait at
  `/assets/images/photos/portrait.jpg`.

- [ ] **Step 1: Generate the portrait**

`prof_pic_color.png` is 2880×3840 — far too large to ship. Downscale to 800px on the long edge and convert to JPEG:

```bash
sips -Z 800 -s format jpeg assets/img/prof_pic_color.png \
  --out assets/images/photos/portrait.jpg
```

`sips` ships with macOS. Verify the result is under 200KB:

```bash
ls -lh assets/images/photos/portrait.jpg
```

- [ ] **Step 2: Move the real thumbnails**

```bash
cp assets/img/susmap.png              assets/images/covers/susmap.png
cp assets/img/rusty.png               assets/images/covers/rusty.png
cp assets/img/mazegen.png             assets/images/covers/mazegen.png
cp assets/img/super-mario-mips.png    assets/images/covers/super-mario-mips.png
cp assets/img/bioconceptxplorer.jpeg  assets/images/covers/bioconceptxplorer.jpeg
```

- [ ] **Step 3: Delete the al-folio image tree**

Everything left in `assets/img/` is generic stock (`1.jpg`–`12.jpg`), superseded (`prof_pic.jpg`, 608×607), or template chrome (`template_error.png`, `thumbnail.png`, `book_covers/`, `publication_preview/`).

```bash
git rm -rq assets/img
git rm -q assets/pdf/example_pdf.pdf
```

Projects with no real thumbnail omit `cover` entirely and render the template's deterministic bubble-hash SVG, which reads better than unrelated stock photography.

- [ ] **Step 4: Verify**

Run:
```bash
bin/verify.sh
```

Expected: same pass/fail profile as Task 2 Step 7 — asset changes alone don't flip any content check yet. Confirm no NEW failures appeared, particularly `no missing local assets`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: migrate assets to template layout

Portrait downscaled 2880x3840 -> 800px JPEG. Keeps the five real project
thumbnails; drops generic stock imagery in favor of the template's
generated bubble-hash covers."
```

---

### Task 4: Personal data

**Files:**
- Modify: `_data/profile.yml`, `_data/display.yml`, `_data/navigation.yml`, `_data/authors.yml`
- Read: `assets/json/resume.json` (source of truth)

**Interfaces:**
- Consumes: portrait path from Task 3.
- Produces: `site.data.profile` consumed by `profile_card.html` and `experience_card.html`; `site.data.authors` keyed by the exact strings Task 5 uses in its `authors` list — `Shrey Joshi`, `Ishaan Javali`, `Ellen Rathje`.

- [ ] **Step 1: Write `_data/profile.yml`**

Every value below except `short_bio` comes from `assets/json/resume.json` or the existing project files. No `logo` keys are set — the repo has no institution logos, and `experience_card.html` renders a broken `<img>` for a missing file; omitting the key avoids editing the widget.

```yaml
primary_name: "Shrey Joshi"
secondary_name: ""
navbar_name: "Shrey Joshi"

email: "shreyjoshi2004@gmail.com"
github: ShreyJ1729
linkedin: sjoshi1729

short_bio_text_justify: false
short_bio: >-
  <p>
    I'm a software engineer interested in systems programming, machine learning
    infrastructure, and the places where the two meet. I recently finished a B.A.
    in Philosophy with a Computer Science minor at the University of Texas at
    Dallas, where I studied on a full-ride National Merit scholarship.
  </p>
  <p>
    My research background is in applied machine learning for geoscience. Working
    with Dr. Ellen Rathje at UT Austin, I built
    <a href="/publications">GLAS</a>, a global landslide analytics system trained
    on GLIF — a dataset compiled from roughly 200GB of geophysical data across six
    sources. That work took a first grand prize at ISEF and was published at the
    2021 IEEE MIT URTC.
  </p>
  <p>
    Since then I've worked as a software engineer at PwC and Minion AI, and I
    spend most of my free time <a href="/projects">writing Rust</a>: a chess
    engine built on magic bitboards, a terminal video-calling client that renders
    frames as sixel graphics, and the FFI bindings underneath it.
  </p>

portrait_url: /assets/images/photos/portrait.jpg

education:
- name: University of Texas at Dallas
  position: >-
    B.A. Philosophy, minor in Computer Science <br/>
    Full-ride National Merit Scholar
  date: Aug. 2022 - May 2026

experience:
- name: PwC
  position: Software Engineering Intern
  date: Jun. 2024 - Aug. 2024
- name: Minion AI
  position: Software Engineer
  date: Jan. 2023 - Feb. 2023
- name: University of Texas at Austin
  position: Machine Learning Researcher
  date: Aug. 2020 - Apr. 2022

awards:
- name: Codon Digest Winner, Bio x ML Hackathon
  date: 2023
- name: National Merit Scholar (full ride)
  date: 2022
- name: ISEF 1st Grand Prize ($10,000)
  date: 2021
```

`positions` and `cv_link` are intentionally absent — UTD ended May 2026 and the current role is undecided; no rendered CV PDF exists. `gscholar`, `twitter`, and `orcid` are absent because no such IDs exist in the repo.

- [ ] **Step 2: Write `_data/display.yml`**

```yaml
homepage:
  show_experience: true
  show_news: false
  show_selected_publications: true
  num_news: 10

footer_text: >-
  <a href="https://github.com/luost26/academic-homepage" target="_blank"><i class="fas fa-pencil-ruler"></i> academic-homepage</a>
```

`show_news: false` because no real news items exist. The upstream attribution link is kept deliberately.

- [ ] **Step 3: Write `_data/navigation.yml`**

Each `name` must match the target page's `navbar_title` exactly, or the navbar won't highlight the active page.

```yaml
pages:
- name: Home
  url: /
- name: Projects
  url: /projects
- name: Publications
  url: /publications
- name: Blog
  url: /blog
```

- [ ] **Step 4: Write `_data/authors.yml`**

Keys must match the `authors` entries in Task 5 character-for-character.

```yaml
"Shrey Joshi":
  bold: true

"Ishaan Javali":

"Ellen Rathje":
  url: https://www.caee.utexas.edu/faculty/directory/rathje
```

- [ ] **Step 5: Verify**

Run:
```bash
bin/verify.sh
```

Expected: the "No placeholder content" section now PASSES in full (`Your Name`, `your@email.com`, `bicolor cat` are gone). `name on homepage`, `education present`, `awards present`, and `email obfuscated` PASS. GLAS and projects checks still FAIL — Tasks 5 and 6.

- [ ] **Step 6: Commit**

```bash
git add _data/
git commit -m "feat: populate profile data from resume.json

Education, experience, and awards derived from assets/json/resume.json.
Bio is newly written and pending review. No positions or cv_link set."
```

---

### Task 5: GLAS publication

**Files:**
- Create: `_publications/2021/2021-glas.md`

**Interfaces:**
- Consumes: `_data/authors.yml` keys from Task 4; `susmap.png` from Task 3.
- Produces: a `site.publications` entry with `selected: true`, consumed by `publications.html` and by the homepage's Selected Publications block.

- [ ] **Step 1: Write the publication entry**

```markdown
---
title:          "GLAS: A Global Landslide Analytics System"
date:           2021-10-09 00:01:00 -0500
selected:       true
pub:            "IEEE MIT Undergraduate Research Technology Conference (URTC)"
pub_date:       "2021"
abstract: >-
  A scalable, low-latency system for global landslide forecasting, severity assessment,
  and date estimation, built on GLIF — the first publicly available dataset of Global
  Landslide Incidents and Features, compiled from roughly 200GB of elevation, climate,
  lithology, forest-change, and infrastructure data across six sources.
cover:          /assets/images/covers/susmap.png
authors:
- Shrey Joshi*
- Ishaan Javali*
- Ellen Rathje
links:
  Paper: https://doi.org/10.1109/URTC54388.2021.9701628
  Code: https://github.com/Landslide-Analytics-System
  Poster: /assets/pdf/poster.pdf
---
```

The `*` suffixes denote co-first authorship and are part of the display string; `author_list.html` matches `_data/authors.yml` on the base name.

- [ ] **Step 2: Verify**

Run:
```bash
bin/verify.sh
```

Expected: `GLAS on homepage` and `GLAS on publications` now PASS. `GLAS on projects`, `projects renders`, and the two category-heading checks still FAIL — Task 6.

- [ ] **Step 3: Commit**

```bash
git add _publications/
git commit -m "feat: add GLAS publication entry"
```

---

### Task 6: Projects collection and page

The 13 existing projects plus BioConceptXplorer, which has a thumbnail and a `resume.json` entry but never had a project file — its image was orphaned in the al-folio repo.

`importance` is renumbered **per category** (work 1–7, fun 1–7), preserving each project's original relative order. Global numbering is meaningless once the page filters by category first.

**Files:**
- Create: `projects.html`, `_projects/*.md` (14 files)

**Interfaces:**
- Consumes: cover paths from Task 3; `widgets/publication_item.html` from Task 2 (used unchanged).
- Produces: `/projects` with `id="cat-work"` and `id="cat-fun"` headings. No detail pages.

- [ ] **Step 1: Write `projects.html`**

Category order is a literal list, so it never depends on `importance` values or on `group_by`'s first-appearance ordering. Adding a category means adding one word to the `split` string.

```html
---
layout: default
title : Projects
navbar_title: Projects
---

{% assign categories = "work,fun" | split: "," %}
{% assign sorted = site.projects | sort: "importance" %}

<div class="row">
    <div class="col-12">
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
    </div>
</div>
```

- [ ] **Step 2: Write the seven `work` projects**

`_projects/glas.md`:
```markdown
---
title:      "GLAS: Global Landslide Analytics System"
category:   work
importance: 1
pub:        "Machine learning · Geospatial data"
pub_date:   "2021"
cover:      /assets/images/covers/susmap.png
abstract: >-
  AI-driven landslide risk assessment using geophysical and meteorological data.
  ISEF 1st Grand Prize ($10k); published at the 2021 IEEE MIT URTC.
links:
  Paper: https://doi.org/10.1109/URTC54388.2021.9701628
  Code: https://github.com/Landslide-Analytics-System
  Poster: /assets/pdf/poster.pdf
---
```

`_projects/leelafaquantum.md`:
```markdown
---
title:      "LeelaFAQuantum"
category:   work
importance: 2
pub:        "Next.js · FastAPI · ChromaDB · Whisper"
abstract: >-
  A RAG-backed FAQ engine over YouTube transcriptions: scrapes and transcribes
  channel video, embeds it in ChromaDB, and serves semantic search through a
  FastAPI endpoint.
links:
  Frontend: https://github.com/ShreyJ1729/leelafaquantum
  Backend: https://github.com/ShreyJ1729/leelafaquantum-backend
---
```

`_projects/bioconceptxplorer.md`:
```markdown
---
title:      "BioConceptXplorer"
category:   work
importance: 3
pub:        "Vector embeddings · PubMed"
pub_date:   "2023"
cover:      /assets/images/covers/bioconceptxplorer.jpeg
abstract: >-
  Explores undocumented molecular interactions at scale using pre-trained vector
  embeddings of proteins, genes, and chemicals drawn from 30 million PubMed papers.
  Codon Digest winner at the Bio x ML Hackathon.
links:
  Code: https://github.com/Cognition-Labs/BioConceptXplorer
---
```

`_projects/cliptranslator.md`:
```markdown
---
title:      "ClipTranslator"
category:   work
importance: 4
pub:        "ElevenLabs · VideoRetalking · Modal"
abstract: >-
  Dubs and lip-syncs video between any of 29 languages, pairing ElevenLabs voice
  synthesis with VideoRetalking for lip movement, deployed as web endpoints on Modal.
links:
  Code: https://github.com/ShreyJ1729/cliptranslator
---
```

`_projects/conversational-ai-twilio.md`:
```markdown
---
title:      "Conversational AI over Twilio"
category:   work
importance: 5
pub:        "Twilio · Speech-to-text · LLM"
abstract: >-
  A phone agent that holds natural conversations over real calls, running
  speech-to-text, LLM inference, and text-to-speech in a low-latency loop.
links:
  Code: https://github.com/ShreyJ1729/conversational-ai-twilio
---
```

`_projects/libsixel-sys.md`:
```markdown
---
title:      "libsixel-sys"
category:   work
importance: 6
pub:        "Rust · FFI"
abstract: >-
  Static Rust FFI bindings to libsixel, enabling images to render as sixel graphics
  directly in terminal emulators. Published on crates.io and the foundation for TermCall.
links:
  Code: https://github.com/ShreyJ1729/libsixel-sys
  crates.io: https://crates.io/crates/libsixel-sys
---
```

`_projects/competitive-programming.md`:
```markdown
---
title:      "Competitive Programming"
category:   work
importance: 7
pub:        "Algorithms"
abstract: >-
  Solutions, templates, and notes accumulated across competitive programming
  platforms and problem sets.
links:
  Code: https://github.com/ShreyJ1729/Competitive-Programming
---
```

- [ ] **Step 3: Write the seven `fun` projects**

`_projects/termcall.md` — note the repo is `termcall-rs`; `resume.json` says `termcall`, and the newer project file wins. Confirm the link resolves before merging.
```markdown
---
title:      "TermCall"
category:   fun
importance: 1
pub:        "Rust · sixel"
abstract: >-
  Video calling inside your terminal. Renders live video frames as sixel graphics
  so you can hold face-to-face calls without leaving the command line.
links:
  Code: https://github.com/ShreyJ1729/termcall-rs
---
```

`_projects/the-resonance-code.md`:
```markdown
---
title:      "The Resonance Code"
category:   fun
importance: 2
pub:        "React 19 · TypeScript · Vite"
abstract: >-
  A wellness navigator inspired by Dr. Bradley Nelson's The Body Code, guiding
  users through a category tree via muscle testing to identify imbalances.
links:
  Code: https://github.com/ShreyJ1729/the-resonance-code
---
```

`_projects/rusty-chess-engine.md`:
```markdown
---
title:      "Rusty Chess Engine"
category:   fun
importance: 3
pub:        "Rust · Magic bitboards"
cover:      /assets/images/covers/rusty.png
abstract: >-
  A chess engine built from scratch in Rust, reaching 4M moves/sec single-threaded
  via magic bitboards, with FEN parsing and a 43-case perft testing suite.
links:
  Code: https://github.com/ShreyJ1729/rusty-chess-engine
---
```

`_projects/mazegen.md`:
```markdown
---
title:      "Maze Generator"
category:   fun
importance: 4
pub:        "Rust · Union-find"
cover:      /assets/images/covers/mazegen.png
abstract: >-
  A Rust CLI generating perfect mazes with Kruskal's algorithm over a disjoint-set
  structure, using path compression to stay fast on large grids and rendering
  straight to the terminal.
links:
  Code: https://github.com/ShreyJ1729/mazegen
---
```

`_projects/game-of-life.md`:
```markdown
---
title:      "Game of Life"
category:   fun
importance: 5
pub:        "Rust · Bevy"
abstract: >-
  Conway's Game of Life in Rust, written as an introduction to the Bevy engine —
  whose entity-component-system architecture turned out to suit cellular automata well.
links:
  Code: https://github.com/ShreyJ1729/game-of-life-rs
---
```

`_projects/js-chess-engine.md`:
```markdown
---
title:      "JS Chess Engine"
category:   fun
importance: 6
pub:        "JavaScript · Minimax"
abstract: >-
  A chess engine in JavaScript using minimax with alpha-beta pruning for move
  selection. The precursor to the Rust engine — same ideas, different language.
links:
  Code: https://github.com/ShreyJ1729/js-chess-engine
---
```

`_projects/super-mario-mips.md`:
```markdown
---
title:      "Super Mario in MIPS Assembly"
category:   fun
importance: 7
pub:        "MIPS assembly"
cover:      /assets/images/covers/super-mario-mips.png
abstract: >-
  A playable, animated Mario written entirely in MIPS assembly, rendering to the
  MARS bitmap display with run/idle animation and wrapping WASD movement. Nearly
  every operation is wrapped in a macro to keep the codebase debuggable.
links:
  Code: https://github.com/ShreyJ1729/UTD/tree/main/cs2340/bitmap-project
---
```

- [ ] **Step 4: Verify**

Run:
```bash
bin/verify.sh
```

Expected: **all checks PASS**, including `projects renders`, `GLAS on projects`, both category headings, and `_projects generates no detail pages`.

- [ ] **Step 5: Confirm project count and ordering by eye**

Run:
```bash
bundle exec jekyll build --quiet
grep -c 'class="mt-0 mb-1 font-weight-normal"' _site/projects.html
```

Expected: `28` — `publication_item.html` renders each item twice (a desktop block and a mobile block), so 14 projects yield 28 title elements. Then confirm work precedes fun:

```bash
grep -o 'id="cat-[a-z]*"' _site/projects.html
```

Expected, in order: `id="cat-work"` then `id="cat-fun"`.

- [ ] **Step 6: Commit**

```bash
git add projects.html _projects/
git commit -m "feat: add projects page and collection

14 projects rendered by widgets/publication_item.html unchanged, grouped
work-then-fun via a literal category list. Adds BioConceptXplorer, which
had a thumbnail and resume entry but no project file in al-folio.
importance renumbered per category, preserving relative order."
```

---

### Task 7: Documentation and final verification

**Files:**
- Create: `README.md`
- Modify: `CLAUDE.md`, `AGENTS.md`

**Interfaces:**
- Consumes: the finished site from Tasks 1–6.
- Produces: nothing consumed by other tasks. Terminal task.

- [ ] **Step 1: Write `README.md`**

```markdown
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
```

- [ ] **Step 2: Rewrite `CLAUDE.md` and `AGENTS.md`**

Both currently describe al-folio's structure, plugins, and Docker workflow — all of which are gone. Replace the contents of each with:

```markdown
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
```

- [ ] **Step 3: Full verification from a clean build**

```bash
rm -rf _site && bin/verify.sh
```

Expected: every check PASSES.

- [ ] **Step 4: Confirm the working tree is clean and review the diff scale**

```bash
git status --short
git diff --stat main...HEAD | tail -1
```

Expected: no untracked or modified files; the diffstat shows the large deletion from removing al-folio.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md AGENTS.md
git commit -m "docs: rewrite README and agent notes for the new stack"
```

- [ ] **Step 6: Report manual follow-ups**

These cannot be done from the repo and must be surfaced to the user:

1. **GitHub Pages source must be switched** from "Deploy from a branch" (`gh-pages`) to "GitHub Actions" in repo settings. Until then the workflow builds but the live site serves stale al-folio output.
2. **Delete the stale `gh-pages` branch** once Actions deployment is confirmed working.
3. **Review the bio** in `_data/profile.yml` — newly written, not ported from anything.
4. **Confirm `termcall-rs`** is the correct repo name (`resume.json` disagrees).
5. **Optional:** PairProgram appears in `resume.json` but has no project file and no thumbnail. Add it if wanted.

---

## Self-Review

**Spec coverage:** Every spec section maps to a task — file disposition and `_config.yml` → Task 2; projects page and field mapping → Task 6; data files → Task 4; publications → Task 5; blog (ships empty, examples relocated) → Task 2 Step 4; assets → Task 3; deploy → Task 2 Step 6; verification → Task 1, run at every task. The spec's README gap is covered by Task 7.

**Deviation from spec, resolved:** the spec's asset table retains `bioconceptxplorer.jpeg`, but no project referenced it — the image was orphaned in al-folio. Task 6 adds a BioConceptXplorer project (sourced from `resume.json`) rather than shipping a dead asset, taking the project count from 13 to 14. Verification step counts reflect 14.

**Placeholder scan:** no TBD/TODO markers; every code step carries literal file content.

**Consistency:** `_data/authors.yml` keys match Task 5's `authors` entries exactly. Cover paths in Tasks 5 and 6 match the destinations written in Task 3. Category IDs asserted in `bin/verify.sh` (`cat-work`, `cat-fun`) match those emitted by `projects.html`. `bin/verify.sh` survives Task 2's `bin/` deletion, which removes only al-folio's four scripts by name.
