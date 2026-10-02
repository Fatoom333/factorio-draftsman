#!/usr/bin/env bash
# Keeps the fork branch rebased on upstream's main.
# Called by .github/workflows/sync-upstream.yml (a copy of this file is run, because
# the rebase rewrites the working tree and would pull the script out from under bash).
#
# Environment:
#   BRANCH        fork branch to keep rebased          (default: main-forge)
#   UPSTREAM_URL  upstream repository                  (default: redruin1/factorio-draftsman)
#   UPSTREAM_REF  ref to rebase onto                   (default: upstream/main)
#   RUN_URL       link to the workflow run, for issues
#   GH_TOKEN      token for `gh` (issue reporting)
#   DRY_RUN=1     do not install, test, push or touch issues; only print what would happen
set -euo pipefail

BRANCH="${BRANCH:-main-forge}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/redruin1/factorio-draftsman}"
UPSTREAM_REF="${UPSTREAM_REF:-upstream/main}"
RUN_URL="${RUN_URL:-(local run)}"
DRY_RUN="${DRY_RUN:-0}"
WORK="$(mktemp -d)"
FENCE='```'

# Pickles that exist only in the fork; every other pickle must stay as upstream committed it.
FORK_PICKLES=(
  draftsman/data/resources.pkl
  draftsman/data/asteroid_chunks.pkl
  draftsman/data/surfaces.pkl
)

ISSUE_TITLE="Upstream sync needs attention"
ISSUE_LABEL="upstream-sync"

OLD_HEAD=""
MERGE_BASE=""
UPSTREAM_SHA=""

log() { echo "==> $*"; }

summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "$*" >>"$GITHUB_STEP_SUMMARY"; else echo "$*"; fi
}

# ---------------------------------------------------------------- issue reporting

open_issue_number() {
  gh issue list --label "$ISSUE_LABEL" --state open --json number --jq '.[0].number // empty'
}

# report_failure <failed step> <file with details>
report_failure() {
  local step="$1" details="$2" body="$WORK/issue-body.md"
  {
    echo "Step that failed: **$step**"
    echo
    echo "Upstream commit: \`${UPSTREAM_SHA:-unknown}\` (\`$UPSTREAM_REF\`)"
    echo "Fork branch before the attempt: \`${OLD_HEAD:-unknown}\` (\`$BRANCH\`)"
    echo "Run: $RUN_URL"
    echo
    cat "$details"
  } >"$body"

  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] would report failure of step '$step':"
    cat "$body"
    return 0
  fi

  # Reporting must never hide the original failure, so every gh call is allowed to fail.
  gh label create "$ISSUE_LABEL" --description "Fork branch could not be synced with upstream" \
    --color d93f0b >/dev/null 2>&1 || true
  local number
  number="$(open_issue_number)" || number=""
  if [ -n "$number" ]; then
    gh issue comment "$number" --body-file "$body" ||
      echo "warning: could not comment on issue #$number"
  else
    gh issue create --title "$ISSUE_TITLE" --label "$ISSUE_LABEL" --body-file "$body" ||
      echo "warning: could not open an issue (are issues enabled for this fork?)"
  fi
}

resolve_issue() {
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] would close an open '$ISSUE_LABEL' issue"
    return 0
  fi
  local number
  number="$(open_issue_number)" || return 0
  [ -n "$number" ] || return 0
  gh issue close "$number" --comment "Resolved by run $RUN_URL" ||
    echo "warning: could not close issue #$number"
}

# ---------------------------------------------------------------- steps

configure_git() {
  git config user.name "Tartaluga"
  git config user.email "123869746+Fatoom333@users.noreply.github.com"
}

fetch_upstream() {
  case "$UPSTREAM_REF" in
    upstream/*)
      git remote add upstream "$UPSTREAM_URL" 2>/dev/null || git remote set-url upstream "$UPSTREAM_URL"
      git fetch --no-tags upstream "${UPSTREAM_REF#upstream/}"
      ;;
    *) log "UPSTREAM_REF=$UPSTREAM_REF is not an upstream/* ref, skipping fetch" ;;
  esac
  UPSTREAM_SHA="$(git rev-parse "$UPSTREAM_REF")"
}

# Returns 0 when there is nothing to do.
is_up_to_date() {
  git merge-base --is-ancestor "$UPSTREAM_REF" HEAD
}

rebase_onto_upstream() {
  OLD_HEAD="$(git rev-parse HEAD)"
  MERGE_BASE="$(git merge-base HEAD "$UPSTREAM_REF")"
  git log --format=%s "$MERGE_BASE..$OLD_HEAD" >"$WORK/subjects-before"

  # Fork commits whose change upstream already made are dropped: git skips commits with the
  # same patch-id (no --reapply-cherry-picks) and --empty=drop removes the ones left empty.
  if git rebase --empty=drop "$UPSTREAM_REF" >"$WORK/rebase.log" 2>&1; then
    cat "$WORK/rebase.log"
    return 0
  fi

  cat "$WORK/rebase.log"
  {
    echo "The rebase hit a conflict."
    echo
    echo "Commit being applied: \`$(git log -1 --format='%h %s' REBASE_HEAD 2>/dev/null || echo unknown)\`"
    echo
    echo "Conflicting files:"
    git diff --name-only --diff-filter=U | sed 's/^/- /'
    echo
    echo "$FENCE"
    git status | head -40
    echo "$FENCE"
  } >"$WORK/details"
  git rebase --abort
  report_failure "rebase" "$WORK/details"
  return 1
}

# True when upstream touched pickles or moved the factorio-data submodule.
upstream_changed_data() {
  [ -n "$(git diff --name-only "$MERGE_BASE" "$UPSTREAM_REF" -- 'draftsman/data/*.pkl' draftsman/factorio-data)" ]
}

install_package() {
  # Same tooling as upstream's push_ci.yml; referencing is imported by test/test_entity.py.
  uv venv --python 3.12 --allow-existing
  uv pip install --group test referencing -e .
}

refresh_fork_pickles() {
  if ! upstream_changed_data; then
    log "Upstream did not touch data pickles or the factorio-data submodule, nothing to re-extract"
    return 0
  fi
  log "Upstream changed vanilla data, re-extracting the fork's pickles"
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] would run draftsman update --no-mods"
    return 0
  fi

  git submodule update --init --depth 1 draftsman/factorio-data
  install_package
  uv run --no-sync draftsman update --no-mods

  # The update rewrites every pickle; keep only the fork-owned ones.
  local f
  while IFS= read -r f; do
    case " ${FORK_PICKLES[*]} " in
      *" $f "*) ;;
      *) git checkout -- "$f" ;;
    esac
  done < <(git diff --name-only -- draftsman/data)

  if git diff --quiet -- "${FORK_PICKLES[@]}"; then
    log "Fork pickles unchanged"
  else
    git add -- "${FORK_PICKLES[@]}"
    git commit -m "Re-extract resources, asteroid chunks and surfaces from the new vanilla data"
  fi
}

run_tests() {
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] would install the package and run pytest"
    return 0
  fi
  install_package
  if uv run --no-sync pytest -q 2>&1 | tee "$WORK/pytest.log"; then
    return 0
  fi
  {
    echo "Tests failed after rebasing onto upstream. Tail of the pytest output:"
    echo
    echo "$FENCE"
    tail -n 60 "$WORK/pytest.log"
    echo "$FENCE"
  } >"$WORK/details"
  report_failure "tests" "$WORK/details"
  return 1
}

push_branch() {
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] would run: git push --force-with-lease=$BRANCH:$OLD_HEAD origin HEAD:$BRANCH"
    return 0
  fi
  if git push --force-with-lease="$BRANCH:$OLD_HEAD" origin "HEAD:$BRANCH" 2>"$WORK/push.log"; then
    return 0
  fi
  cat "$WORK/push.log"
  {
    echo "The rebased branch could not be pushed. Output:"
    echo
    echo "$FENCE"
    tail -n 30 "$WORK/push.log"
    echo "$FENCE"
    echo "If this mentions the workflows permission, upstream changed files in .github/workflows and"
    echo "the default GITHUB_TOKEN may not push those; add a PAT as the SYNC_PUSH_TOKEN secret."
  } >"$WORK/details"
  report_failure "push" "$WORK/details"
  return 1
}

summarize_dropped() {
  git log --format=%s "$UPSTREAM_REF..HEAD" >"$WORK/subjects-after"
  local dropped
  dropped="$(grep -vxFf "$WORK/subjects-after" "$WORK/subjects-before" || true)"

  summary "### Fork rebased onto upstream \`${UPSTREAM_SHA:0:7}\`"
  summary ""
  summary "Branch \`$BRANCH\`: \`${OLD_HEAD:0:7}\` -> \`$(git rev-parse --short HEAD)\`"
  summary ""
  if [ -n "$dropped" ]; then
    summary "Fork commits that were dropped (upstream already has the change):"
    summary ""
    while IFS= read -r line; do summary "- $line"; done <<<"$dropped"
  else
    summary "No fork commits were dropped."
  fi
}

# ---------------------------------------------------------------- main

main() {
  configure_git
  fetch_upstream

  if is_up_to_date; then
    log "up to date: $UPSTREAM_REF ($UPSTREAM_SHA) is already contained in $BRANCH"
    summary "$BRANCH is up to date with upstream (\`${UPSTREAM_SHA:0:7}\`)."
    resolve_issue
    return 0
  fi

  rebase_onto_upstream || exit 1
  refresh_fork_pickles
  run_tests || exit 1
  push_branch || exit 1
  summarize_dropped
  resolve_issue
}

main "$@"
