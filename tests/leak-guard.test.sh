#!/usr/bin/env bash
# Leak guard: no committed secret or personal detail in the kit's own files. Fails on
#   - a /home/<user> or /Users/<user> path (placeholder users like u, x, you, user are allowed)
#   - an email address (only noreply forms and the reserved example.* domains are allowed)
#   - AWS, GitHub, Anthropic and OpenAI key shapes
#   - a private-key header
# It scans every tracked file plus untracked files that are not ignored, so a planted file fails before
# it is committed. Part 1 plants each class in a sandbox (the scanner must catch it); part 2 scans the repo.
# The planted values are built from pieces at run time, so this file never holds a matching string itself.
# Run: bash tests/leak-guard.test.sh   (needs bash, git, grep)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL $*"; }

# ---- the classes: label TAB extended regex (grep -E) ------------------------------------------------
CLASSES="$(cat <<'EOF'
home-path	(^|[^A-Za-z0-9_}/.-])/(home|Users)/[A-Za-z0-9_][A-Za-z0-9._-]*
email	[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}
aws-key	\b(AKIA|ASIA)[0-9A-Z]{16}\b
github-token	\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}\b
github-token	\bgithub_pat_[A-Za-z0-9_]{22,}
anthropic-key	\bsk-ant-[A-Za-z0-9_-]{20,}
openai-key	\bsk-(proj-|svcacct-|admin-)?[A-Za-z0-9_-]{20,}
private-key	-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----
EOF
)"
# home-path starts at a boundary, so a sandbox path like "$SB/home/x" is not a user's home; a user name
# starts with a letter, digit or _, so "/home/.config" is not one either.
# Matches that are fine. Each is checked against the matched text alone, never the whole line, so an
# allowed path on a line cannot hide a real one beside it.
ALLOW_HOME='^/(home|Users)/(u|x|you|user|username|me|name|example|runner)$'
ALLOW_EMAIL='(@users\.noreply\.github\.com|^noreply@anthropic\.com|^noreply@github\.com|^git@github\.com|@example\.(com|org|net))$'
# The openai shape also catches every Anthropic key; report those once, as anthropic-key.
ALLOW_OPENAI='^sk-ant-'

leak_scan() {  # <dir> → "label file:line: match" per finding, nothing when clean
  local dir="$1" label re allow f
  local files=()
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do [ -f "$dir/$f" ] && files+=("$f"); done \
      < <(git -C "$dir" ls-files -z --cached --others --exclude-standard)
  else
    while IFS= read -r -d '' f; do files+=("${f#./}"); done < <(cd "$dir" && find . -type f -print0)
  fi
  [ "${#files[@]}" -gt 0 ] || return 0
  while IFS=$'\t' read -r label re; do
    case "$label" in home-path) allow="$ALLOW_HOME" ;; email) allow="$ALLOW_EMAIL" ;; openai-key) allow="$ALLOW_OPENAI" ;; *) allow='' ;; esac
    # -I skips binary files; -o prints each match on its own line; -H keeps file:line: with one file
    (cd "$dir" && grep -HonIE -- "$re" "${files[@]}" 2>/dev/null) | while IFS= read -r hit; do
      local m="${hit#*:}"; m="${m#*:}"
      [ "$label" = home-path ] && m="/${m#*/}"   # drop the boundary character
      if [ -n "$allow" ] && printf '%s\n' "$m" | grep -qE -- "$allow"; then continue; fi
      echo "$label ${hit%%:*}:$(printf '%s' "${hit#*:}" | cut -d: -f1): $m"
    done
  done <<< "$CLASSES"
}

# ---- (1) the scanner catches each class, and lets the allowed forms through ------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/leak-guard.XXXXXX")"; trap 'rm -rf "$SB"' EXIT
plant() {  # <label> <file content>: the scanner must report <label> for it
  rm -rf "$SB/s"; mkdir -p "$SB/s"; printf '%s\n' "$2" > "$SB/s/planted.txt"
  local out; out="$(leak_scan "$SB/s")"
  case "$out" in *"$1 planted.txt:1:"*) ok ;; *) bad "scanner missed a planted $1 (got: ${out:-nothing})" ;; esac
}
clean() {  # <label> <file content>: the scanner must report nothing
  rm -rf "$SB/s"; mkdir -p "$SB/s"; printf '%s\n' "$2" > "$SB/s/allowed.txt"
  local out; out="$(leak_scan "$SB/s")"
  [ -z "$out" ] && ok || bad "allowed form flagged ($1): $out"
}
A=A; Z=0123456789ABCDEF; L=abcdefghijklmnopqrstuvwxyz0123456789
plant home-path      "cd /ho""me/jdoe/projects"
plant home-path      "open /Us""ers/jdoe/Library"
plant home-path      "a placeholder /home/u beside a real path /ho""me/jdoe"
plant email          "mail jane.doe""@""gmail.com"
plant aws-key        "key=${A}KIA${Z}"
plant aws-key        "key=${A}SIA${Z}"
plant github-token   "token=gh""p_${L}"
plant github-token   "token=github""_pat_${L}_${L}"
plant anthropic-key  "ANTHROPIC_API_KEY=sk-""ant-api03-${L}"
plant openai-key     "OPENAI_API_KEY=sk-""proj-${L}"
plant openai-key     "OPENAI_API_KEY=sk-""${L}"
plant private-key    "-----BEGIN ""PRIVATE KEY-----"
plant private-key    "-----BEGIN ""OPENSSH PRIVATE KEY-----"
plant private-key    "-----BEGIN ""RSA PRIVATE KEY-----"
clean home-path      "HOME=/home/u and /home/user/x and /Users/you/x and /home/<user> and /home/\$USER"
clean email          "Co-Authored-By: Claude <noreply""@anthropic.com> and 12345+someone""@users.noreply.github.com"
clean email          "t""@example.com, git""@github.com:owner/repo.git, plugin@marketplace-name"
clean anthropic-key  "an Anthropic key starts with sk-ant- and the docs never show one"
# The only finding for an Anthropic key is anthropic-key, not openai-key too.
rm -rf "$SB/s"; mkdir -p "$SB/s"; printf '%s\n' "sk-""ant-api03-${L}" > "$SB/s/one.txt"
[ "$(leak_scan "$SB/s" | wc -l | tr -d ' ')" = 1 ] && ok || bad "an Anthropic key is reported more than once: $(leak_scan "$SB/s")"
# Untracked files that are not ignored are scanned; ignored ones are not.
rm -rf "$SB/g"; mkdir -p "$SB/g"; git -C "$SB/g" init -q
printf 'ignored.txt\n' > "$SB/g/.gitignore"; printf '%s\n' "/ho""me/jdoe" > "$SB/g/new.txt"; printf '%s\n' "/ho""me/jdoe" > "$SB/g/ignored.txt"
out="$(leak_scan "$SB/g")"
case "$out" in *"new.txt:1:"*) ok ;; *) bad "untracked file not scanned (got: ${out:-nothing})" ;; esac
case "$out" in *"ignored.txt"*) bad "ignored file scanned: $out" ;; *) ok ;; esac

# ---- (2) the repo itself is clean -------------------------------------------------------------------
found="$(leak_scan "$ROOT")"
if [ -z "$found" ]; then ok; else
  bad "leaks in the repo (remove them, or use a placeholder like /home/u or a noreply address):"
  printf '%s\n' "$found" | head -40 | sed 's/^/  /'
fi

echo "leak-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
