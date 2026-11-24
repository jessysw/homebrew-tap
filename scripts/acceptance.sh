#!/usr/bin/env bash
# Only disposable CI data is created; never run against an existing deployment.
set -euo pipefail
: "${RUNNER_TEMP:?This acceptance script requires an isolated CI runner}"
root="$RUNNER_TEMP/contitext-acceptance"
mkdir -p "$root"
formula="$GITHUB_WORKSPACE/Formula/contitext.rb"
cp "$formula" "$root/new.rb"
trap 'cp "$root/new.rb" "$formula"; if [ -f "$root/pg/postmaster.pid" ]; then "$pg/pg_ctl" -D "$root/pg" -m fast stop; fi' EXIT
brew install postgresql@18
pg="$(brew --prefix postgresql@18)/bin"
"$pg/initdb" -D "$root/pg" -A trust -U acceptance --no-locale > "$root/initdb.log"
"$pg/pg_ctl" -D "$root/pg" -l "$root/postgres.log" -o "-h 127.0.0.1 -p 55484 -k $root" start
"$pg/createdb" -h 127.0.0.1 -p 55484 -U acceptance contitext_test
export DATABASE_URL=postgresql+psycopg://acceptance@127.0.0.1:55484/contitext_test
upgrade=false
if [ -n "${BASE_FORMULA:-}" ]; then
  cp "$BASE_FORMULA" "$root/old.rb"
  cp "$root/old.rb" "$formula"
  upgrade=true
elif [[ "${BASE_SHA:-}" =~ ^[0-9a-f]{40}$ ]] && git cat-file -e "$BASE_SHA:Formula/contitext.rb" 2>/dev/null; then
  git show "$BASE_SHA:Formula/contitext.rb" > "$root/old.rb"
  old_source=$(sed -n '/^  url /{p;q;}' "$root/old.rb")
  new_source=$(sed -n '/^  url /{p;q;}' "$root/new.rb")
  if [ "$old_source" != "$new_source" ]; then
    cp "$root/old.rb" "$formula"
    upgrade=true
  fi
fi
brew install --build-from-source jessysw/tap/contitext
cli="$(brew --prefix)/opt/contitext/bin/contitext"
python="$(brew --prefix)/opt/contitext/libexec/bin/python"
"$cli" init --project demo --output "$root/private.env"
"$cli" --env-file "$root/private.env" migrate
"$cli" --env-file "$root/private.env" admin seed --if-empty
"$cli" --env-file "$root/private.env" mcp-smoke
"$cli" client-config --config-file "$root/private.env" --executable "$cli" > "$root/client.json"
"$python" "$GITHUB_WORKSPACE/scripts/data_snapshot.py" "$root/before.json"
cp "$root/private.env" "$root/private.env.original"
cp "$root/client.json" "$root/client.json.original"
if $upgrade; then
  old_keg="$(cd "$(brew --prefix contitext)" && pwd -P)"
  cp "$root/new.rb" "$formula"
  brew upgrade --build-from-source jessysw/tap/contitext
  brew cleanup contitext
  test ! -d "$old_keg"
  echo 'Upgrade and old-keg removal passed.'
else
  echo 'Clean installation: no older formula was provided.'
fi
cmp "$root/private.env" "$root/private.env.original"
cmp "$root/client.json" "$root/client.json.original"
"$cli" --env-file "$root/private.env" doctor
"$python" "$GITHUB_WORKSPACE/scripts/data_snapshot.py" "$root/after.json"
cmp "$root/before.json" "$root/after.json"
"$cli" --env-file "$root/private.env" mcp-smoke
"$python" "$(brew --prefix contitext)/share/contitext/scripts/check_hook_installation.py" --connection "$root/client.json" --project personal/demo --directory "$root/hooks"
"$(brew --prefix python@3.14)/bin/python3.14" -m pip --python "$python" check
brew test jessysw/tap/contitext
count_before=$("$pg/psql" -h 127.0.0.1 -p 55484 -U acceptance -d contitext_test -Atc 'SELECT count(*) FROM context_events')
brew uninstall contitext
cmp "$root/private.env" "$root/private.env.original"
cmp "$root/client.json" "$root/client.json.original"
count_after=$("$pg/psql" -h 127.0.0.1 -p 55484 -U acceptance -d contitext_test -Atc 'SELECT count(*) FROM context_events')
test "$count_before" = "$count_after"
echo 'CLI, MCP write/read, eight adapter contracts and data-preserving uninstall passed.'
