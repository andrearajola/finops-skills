#!/usr/bin/env bash
# Fails if any skills/<name>/SKILL.md is missing or has no name/description in its frontmatter.
set -euo pipefail
shopt -s nullglob
status=0
for dir in skills/*/; do
  f="${dir}SKILL.md"
  if [[ ! -f "$f" ]]; then echo "ERROR: $f not found"; status=1; continue; fi
  front=$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$f")
  grep -qE '^name:[[:space:]]*[^[:space:]]' <<<"$front"        || { echo "ERROR: $f has no 'name:' in frontmatter"; status=1; }
  grep -qE '^description:[[:space:]]*[^[:space:]]' <<<"$front" || { echo "ERROR: $f has no 'description:' in frontmatter"; status=1; }
  [[ $status -eq 0 ]] && echo "OK: $f"
done
exit $status
