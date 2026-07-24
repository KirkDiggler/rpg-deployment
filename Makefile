.PHONY: local-prod local-prod-down local-prod-logs

# One-command local prod-parity stack (rpg-deployment#56): pulls and runs
# the exact published production images. See LOCAL_DEV.md for details.
local-prod:
	docker compose -f docker-compose.local-prod.yml pull rpg-api rpg-web
	docker compose -f docker-compose.local-prod.yml up -d
	@echo ""
	@echo "Up at http://localhost:8090"

local-prod-down:
	docker compose -f docker-compose.local-prod.yml down

local-prod-logs:
	docker compose -f docker-compose.local-prod.yml logs -f
