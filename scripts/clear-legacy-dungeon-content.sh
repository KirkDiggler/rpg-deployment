#!/bin/bash
# Empty the authored-dungeon content volume of the pair-form files the new
# compiler refuses (rpg-project#360, wall geometry slice 2).
#
# ONE-SHOT, AND DELIBERATELY NOT WIRED INTO deploy.yml. Every file it removes
# is somebody's authored dungeon, so it runs when a human says so and never
# on a schedule. Run it ONCE on the box, before the deploy that carries an
# rpg-api built on encounter v0.52.0, and not again.
#
# Why it is needed. A wall used to be a list of crossings between adjacent
# cells and is now a line between two picked positions. The pair form is
# deleted rather than migrated, so the compiler refuses a file that uses it,
# by name, at the header. The api builds its content registry at construction
# and a file that will not compile is a hard boot refusal, not a skipped
# entry -- the first legacy file it loads takes the whole api down. Kirk
# re-authors what he wants in the builder afterwards.
#
# Why a deploy cannot do it on its own. deploy.yml runs `git reset --hard
# origin/main`, and content/ is gitignored (content/README.md aside), so
# nothing the pipeline does touches these files. They survive every deploy,
# which is exactly the property the authoring volume was given on purpose
# (see docker-compose.prod.yml's note on the ./content mount) and exactly
# what makes this step manual.
#
# Usage, on the box:
#
#   cd /opt/rpg-deployment
#   ./scripts/clear-legacy-dungeon-content.sh          # list what would go
#   ./scripts/clear-legacy-dungeon-content.sh --delete # actually remove it

set -euo pipefail

CONTENT_DIR="${RPG_CONTENT_HOST_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/content}"

if [ ! -d "$CONTENT_DIR" ]; then
	echo "No content directory at $CONTENT_DIR -- nothing to clear."
	exit 0
fi

mapfile -t files < <(find "$CONTENT_DIR" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)

if [ "${#files[@]}" -eq 0 ]; then
	echo "No authored dungeons in $CONTENT_DIR -- nothing to clear."
	exit 0
fi

echo "Authored dungeons in $CONTENT_DIR:"
for file in "${files[@]}"; do
	echo "  $(basename "$file")"
done
echo ""

if [ "${1:-}" != "--delete" ]; then
	echo "Dry run. Re-run with --delete to remove these ${#files[@]} file(s)."
	echo "content/README.md is kept either way -- it is the only tracked file here."
	exit 0
fi

for file in "${files[@]}"; do
	rm -- "$file"
	echo "removed $(basename "$file")"
done

echo ""
echo "Cleared ${#files[@]} file(s). The api seeds the reference tomb into an"
echo "empty mount on boot, so the volume being empty is a valid state."
