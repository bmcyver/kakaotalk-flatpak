#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_SHA:?}"
: "${GITHUB_RUN_ID:?}"
: "${GITHUB_RUN_ATTEMPT:?}"
: "${GH_TOKEN:?}"

if [[ ! $GITHUB_REPOSITORY =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ||
      ! $GITHUB_SHA =~ ^[a-fA-F0-9]{40}$ ||
      ! $GITHUB_RUN_ID =~ ^[0-9]+$ || ! $GITHUB_RUN_ATTEMPT =~ ^[0-9]+$ ]]; then
  echo 'Invalid GitHub execution context.' >&2
  exit 1
fi

export GH_REPO="$GITHUB_REPOSITORY"
release_tag="flatpak-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
release_dir=$(mktemp -d)
published=false
release_id=''

cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n $release_id && $published == false ]]; then
    gh api --method DELETE "repos/$GH_REPO/releases/$release_id" || true
  fi
  rm -rf -- "$release_dir"
  exit "$status"
}
trap cleanup EXIT

assets=(.build/KakaoTalk.flatpak)
for asset in "${assets[@]}"; do
  if [[ ! -f $asset || -L $asset || ! -s $asset ]]; then
    echo "Missing or empty bundle: $asset" >&2
    exit 1
  fi
done

(cd .build && sha256sum KakaoTalk.flatpak) > "$release_dir/SHA256SUMS"

jq -n --arg tag "$release_tag" --arg target "$GITHUB_SHA" \
  '{tag_name: $tag, target_commitish: $target, name: "카카오톡", body: "", draft: true}' \
  > "$release_dir/create.json"
gh api --method POST "repos/$GH_REPO/releases" \
  --input "$release_dir/create.json" > "$release_dir/created.json"
release_id=$(jq -er '.id | select(type == "number" and . > 0) | tostring' "$release_dir/created.json")
jq -e --arg tag "$release_tag" '.tag_name == $tag and .draft == true' \
  "$release_dir/created.json" > /dev/null

for asset in "${assets[@]}" "$release_dir/SHA256SUMS"; do
  gh api --method POST \
    "https://uploads.github.com/repos/$GH_REPO/releases/$release_id/assets?name=${asset##*/}" \
    --header 'Content-Type: application/octet-stream' --input "$asset" --silent
done

gh api "repos/$GH_REPO/releases/$release_id" > "$release_dir/assets.json"
jq -e \
  --argjson kakao_size "$(stat -c %s .build/KakaoTalk.flatpak)" \
  --argjson sums_size "$(stat -c %s "$release_dir/SHA256SUMS")" '
  .assets as $assets |
  [.assets[] | select(.state == "uploaded" and .size > 0) | .name] | sort ==
  (["KakaoTalk.flatpak", "SHA256SUMS"] | sort) and
  all($assets[];
    if .name == "KakaoTalk.flatpak" then .size == $kakao_size
    elif .name == "SHA256SUMS" then .size == $sums_size
    else false end)
' "$release_dir/assets.json" > /dev/null

gh api --method PATCH "repos/$GH_REPO/releases/$release_id" \
  -F draft=false -f make_latest=true > "$release_dir/published.json"
published=true
jq -e --arg tag "$release_tag" '.tag_name == $tag and .draft == false' \
  "$release_dir/published.json" > /dev/null

gh api --paginate "repos/$GH_REPO/releases?per_page=100" \
  --jq '.[] | [.id, .tag_name] | @tsv' > "$release_dir/releases.tsv"

while IFS=$'\t' read -r old_release_id old_tag; do
  [[ $old_tag == "$release_tag" ]] && continue
  gh api --method DELETE "repos/$GH_REPO/releases/$old_release_id"
  if [[ $old_tag =~ ^flatpak-[0-9]+-[0-9]+$ ]]; then
    if gh api "repos/$GH_REPO/git/ref/tags/$old_tag" --silent 2> "$release_dir/tag-error"; then
      gh api --method DELETE "repos/$GH_REPO/git/refs/tags/$old_tag"
    elif ! rg -q 'HTTP 404' "$release_dir/tag-error"; then
      cat "$release_dir/tag-error" >&2
      exit 1
    fi
  fi
done < "$release_dir/releases.tsv"

gh api --paginate --slurp "repos/$GH_REPO/releases?per_page=100" > "$release_dir/remaining.json"
jq -e --arg tag "$release_tag" 'add | length == 1 and .[0].tag_name == $tag' \
  "$release_dir/remaining.json" > /dev/null

jq -r '.html_url' "$release_dir/published.json"
