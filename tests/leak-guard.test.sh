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
home-path	(\$\{[^}[:space:]]*\}|\$[A-Za-z_][A-Za-z0-9_]*|/tmp(/[A-Za-z0-9_-][A-Za-z0-9._-]*)*)?([\\/]|%2[Ff]|%5[Cc])+(home|users)([\\/]|%2[Ff]|%5[Cc])+[A-Za-z0-9_][A-Za-z0-9._-]*
email	[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}
aws-key	\b(AKIA|ASIA)[0-9A-Z]{16}\b
github-token	\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}
github-token	\bgithub_pat_[A-Za-z0-9_]{22,}
anthropic-key	\bsk-ant-[A-Za-z0-9_-]{20,}
openai-key	\bsk-(proj-|svcacct-|admin-)?[A-Za-z0-9_-]{20,}
private-key	-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----
EOF
)"
# home-path is INVERTED: any home or users directory after one or more separators (/ or \, or URL-encoded %2F / %5C), in
# any case, followed by a user name, is a leak (/home/x, //home/x, /var/home/x, C:\USERS\x, \\wsl$\Ubuntu\home\x,
# file:%2F%2F%2Fhome%2Fx, ..\home\x, ...). Listing leak forms one by one kept missing some (READ r0, r1). Only two SAFE
# prefixes are listed, both test sandboxes: a shell variable right before the separator ($SB, ${SB}) and a /tmp/... path
# (its segments cannot be "..", so /tmp/../home/x still fails). A user name starts with a letter, digit or _, so
# "/home/.config" is not one. The allow-list is checked against the user name alone. .gitleaks.toml holds the same rule;
# part 3 below feeds it the same cases, so the two cannot drift.
# Matches that are fine. Each is checked against the matched text alone, never the whole line, so an
# allowed path on a line cannot hide a real one beside it.
ALLOW_HOME='^(u|x|you|user|username|me|name|example|runner|Public|Default)$'
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
    local gi=""; [ "$label" = home-path ] && gi=i   # a home path in any case (C:\USERS, /HOME)
    (cd "$dir" && grep -HonIE$gi -- "$re" "${files[@]}" 2>/dev/null) | while IFS= read -r hit; do
      local m="${hit#*:}"; m="${m#*:}"
      local subject="$m" icase=""
      if [ "$label" = home-path ]; then
        case "$m" in '$'*|/[Tt][Mm][Pp]*) continue ;; esac   # a safe prefix: a sandbox, not a home
        subject="$(printf '%s' "$m" | sed -E 's/.*([\\/]|%2[Ff]|%5[Cc])//')"   # the user name: the allow-list is about who
        icase=i
      fi
      if [ -n "$allow" ] && printf '%s\n' "$subject" | grep -q${icase}E -- "$allow"; then continue; fi
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
HOME_RED=(
  "cd /ho""me/jdoe/projects"
  "open /Us""ers/jdoe/Library"
  "a placeholder /home/u beside a real path /ho""me/jdoe"
  "WSL: /mnt/c/Us""ers/jdoe/Documents"
  "WSL lower case: /mnt/d/us""ers/jdoe"
  "open file:///ho""me/jdoe/index.html"
  "mac: file:///Us""ers/jdoe/x"
  "cd ~/../ho""me/jdoe"
  'C:\Us''ers\jdoe\AppData'
  'json: "C:\\Us''ers\\jdoe"'
  "C:/Us""ers/jdoe/x"
  "PATH=/usr/bin:/ho""me/jdoe/bin"
  "//ho""me/jdoe"
  "//Us""ers/jdoe"
  "/us""ers/jdoe"
  "/HO""ME/jdoe"
  'C:\US''ERS\jdoe'
  '\\wsl$\Ubuntu\ho''me\jdoe'
  '\\wsl.localhost\Ubuntu\ho''me\jdoe'
  'json: "\\\\wsl$\\Ubuntu\\ho''me\\jdoe"'
  "%2Fho""me%2Fjdoe"
  "file:%2F%2F%2Fho""me%2Fjdoe"
  "%5CUs""ers%5Cjdoe"
  "%2fho""me%2fjdoe"
  "/var/ho""me/jdoe"
  "/mnt/wsl/ho""me/jdoe"
  '..\ho''me\jdoe'
  "\$HOME/../ho""me/jdoe"
  "/tmp/../ho""me/jdoe"
  "\$SB beside /ho""me/jdoe"
)
HOME_CLEAN=(
  "HOME=/home/u and /home/user/x and /Users/you/x and /home/<user> and /home/\$USER"
  'sandbox: "$SB/home/jdoe" "${SB}/home/jdoe" /tmp/sb/home/jdoe "$SB/home/.claude-acct2" $X/Users/jdoe'
  'placeholders: /mnt/c/Users/you C:\Users\Public C:\Users\%USERNAME% file:///home/user/x ../home/u /HOME/U %2Fhome%2Fu'
)
for c in "${HOME_RED[@]}"; do plant home-path "$c"; done
for c in "${HOME_CLEAN[@]}"; do clean home-path "$c"; done
plant email          "mail jane.doe""@""gmail.com"
plant aws-key        "key=${A}KIA${Z}"
plant aws-key        "key=${A}SIA${Z}"
plant github-token   "token=gh""p_${L}"
plant github-token   "token=gh""p_${L}XYZ"   # a longer tail than 36
plant github-token   "token=github""_pat_${L}_${L}"
plant anthropic-key  "ANTHROPIC_API_KEY=sk-""ant-api03-${L}"
plant openai-key     "OPENAI_API_KEY=sk-""proj-${L}"
plant openai-key     "OPENAI_API_KEY=sk-""${L}"
plant private-key    "-----BEGIN ""PRIVATE KEY-----"
plant private-key    "-----BEGIN ""OPENSSH PRIVATE KEY-----"
plant private-key    "-----BEGIN ""RSA PRIVATE KEY-----"
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

# ---- (3) parity: .gitleaks.toml's home-path rule flags exactly the same cases -----------------------------
# The rule's regex and allowlists are read from the toml and applied with Python's re (the same syntax subset as gitleaks'
# RE2 here), so CI's gitleaks scan cannot drift from this guard. With a real gitleaks on PATH (CI's gitleaks job), each case
# also goes through the binary itself, default rules and global allowlist included.
CASES="$SB/home-cases.txt"; : > "$CASES"
for c in "${HOME_RED[@]}"; do printf 'R\t%s\n' "$c" >> "$CASES"; done
for c in "${HOME_CLEAN[@]}"; do printf 'C\t%s\n' "$c" >> "$CASES"; done
if [ ! -f "$ROOT/.gitleaks.toml" ]; then
  echo "SKIP gitleaks parity: no .gitleaks.toml in this repo (a copy of this guard elsewhere, e.g. the pre-push hook's sandbox)"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' 2>/dev/null; then
  drift="$(python3 -I - "$ROOT/.gitleaks.toml" "$CASES" <<'EOF'
import re, sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb"))
rule = next(r for r in cfg.get("rules", []) if r["id"] == "home-path")
rx, grp = re.compile(rule["regex"]), rule.get("secretGroup", 0)
allows = [(a.get("regexTarget", "secret"), [re.compile(x) for x in a.get("regexes", [])]) for a in rule.get("allowlists", [])]
def allowed(m):
    target = {"secret": m.group(grp), "match": m.group(0)}
    return any(any(x.search(target.get(t, m.group(grp))) for x in xs) for t, xs in allows)
for line in open(sys.argv[2], encoding="utf-8"):
    want, text = line.rstrip("\n").split("\t", 1)
    got = "R" if any(not allowed(m) for m in rx.finditer(text)) else "C"
    if got != want:
        print(f"want {'flagged' if want == 'R' else 'clean'}, gitleaks rule says {'flagged' if got == 'R' else 'clean'}: {text}")
EOF
)"
  [ -z "$drift" ] && ok || bad "the .gitleaks.toml home-path rule drifted from this guard:"$'\n'"$drift"
else
  echo "SKIP gitleaks parity (regex): python3 with tomllib (3.11+) is not available"
fi
if [ -f "$ROOT/.gitleaks.toml" ] && command -v gitleaks >/dev/null 2>&1; then
  rm -rf "$SB/gl"; mkdir -p "$SB/gl"; i=0
  while IFS=$'\t' read -r want text; do i=$((i + 1)); printf '%s\n' "$text" > "$SB/gl/$want-$i.txt"; done < "$CASES"
  gitleaks dir "$SB/gl" -c "$ROOT/.gitleaks.toml" --no-banner --report-format csv --report-path "$SB/gl.csv" >/dev/null 2>&1
  [ -s "$SB/gl.csv" ] || bad "gitleaks wrote no report (it failed to run with .gitleaks.toml)"
  flagged="$(awk -F, 'NR > 1 && $1 == "home-path" { print $3 }' "$SB/gl.csv" | sed 's#.*/##' | sort -u)"
  miss=""
  for f in "$SB"/gl/*.txt; do
    b="${f##*/}"; hit=C; grep -qxF "$b" <<<"$flagged" && hit=R
    [ "$hit" = "${b%%-*}" ] || miss="$miss"$'\n'"  gitleaks says $hit, want ${b%%-*}: $(cat "$f")"
  done
  [ -z "$miss" ] && ok || bad "real gitleaks disagrees with this guard:$miss"
elif [ -f "$ROOT/.gitleaks.toml" ]; then
  echo "SKIP gitleaks parity (binary): gitleaks is not on PATH (CI's gitleaks job runs this case)"
fi

# ---- (2) the repo itself is clean -------------------------------------------------------------------
found="$(leak_scan "$ROOT")"
if [ -z "$found" ]; then ok; else
  bad "leaks in the repo (remove them, or use a placeholder like /home/u or a noreply address):"
  printf '%s\n' "$found" | head -40 | sed 's/^/  /'
fi

echo "leak-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
