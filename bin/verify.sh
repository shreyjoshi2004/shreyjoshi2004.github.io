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
