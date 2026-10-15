#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

manifests=(
  plugin.json
  .claude-plugin/plugin.json
  .claude-plugin/marketplace.json
  .agents/plugins/marketplace.json
  .cursor-plugin/marketplace.json
)

for manifest in "${manifests[@]}"; do
  jq empty "$manifest"
done

plugin_name="$(jq -er '.name' plugin.json)"
if [[ ! "$plugin_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  printf 'Invalid portable plugin name: %s\n' "$plugin_name" >&2
  exit 1
fi

assert_plugin_name() {
  local manifest="$1"
  local expression="$2"
  local actual
  actual="$(jq -er "$expression" "$manifest")"
  if [[ "$actual" != "$plugin_name" ]]; then
    printf '%s names %s, expected %s\n' "$manifest" "$actual" "$plugin_name" >&2
    exit 1
  fi
}

assert_plugin_name .claude-plugin/plugin.json '.name'
assert_plugin_name .claude-plugin/marketplace.json '.name'
assert_plugin_name .claude-plugin/marketplace.json '.plugins[0].name'
assert_plugin_name .agents/plugins/marketplace.json '.name'
assert_plugin_name .agents/plugins/marketplace.json '.plugins[0].name'
assert_plugin_name .cursor-plugin/marketplace.json '.name'
assert_plugin_name .cursor-plugin/marketplace.json '.plugins[0].name'

jq -e --arg name "$plugin_name" \
  '.plugins | length == 1 and .[0].name == $name and .[0].source == "."' \
  .claude-plugin/marketplace.json >/dev/null
jq -e --arg name "$plugin_name" \
  '.plugins | length == 1 and .[0].name == $name and .[0].source.url == "https://github.com/sammasak/skills.git"' \
  .agents/plugins/marketplace.json >/dev/null
jq -e --arg name "$plugin_name" \
  '.plugins | length == 1 and .[0].name == $name and .[0].source == "." and ((.[0] | keys | sort) == ["description", "name", "source"])' \
  .cursor-plugin/marketplace.json >/dev/null

skill_count=0
for skill_dir in skills/*/; do
  [[ -s "${skill_dir}SKILL.md" ]] || {
    printf 'Missing SKILL.md in %s\n' "$skill_dir" >&2
    exit 1
  }
  skill_count=$((skill_count + 1))
done

(( skill_count > 0 ))
[[ -s LICENSE ]]
printf 'Plugin manifests are consistent; found %d packaged skills.\n' "$skill_count"
