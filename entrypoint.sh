#!/usr/bin/env bash
set -Eeuo pipefail

log() {
	printf '[%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"
}

err() {
	printf '[%s] ERROR: %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" >&2
}

APP_HOME=${APP_HOME:-/app}
REPO_DIR="$APP_HOME/repo"

REPO_URL=${NODE_NPX_REPO_URL:-}
REPO_TOKEN=${NODE_NPX_REPO_TOKEN:-}
REPO_PROXY=${NODE_NPX_REPO_PROXY:-}
RUN_CMD=${NODE_NPX_RUN_CMD:-}

trap 'err "Startup failed. See logs above for details."' ERR

if [[ -z "$REPO_URL" ]]; then
	err "NODE_NPX_REPO_URL is required"
	exit 64
fi

mkdir -p "$APP_HOME"
cd "$APP_HOME"

# Configure proxy if provided
if [[ -n "${REPO_PROXY}" ]]; then
	log "Configuring proxy for git and npm"
	export HTTP_PROXY="$REPO_PROXY"
	export HTTPS_PROXY="$REPO_PROXY"
	git config --global http.proxy "$REPO_PROXY" || true
	git config --global https.proxy "$REPO_PROXY" || true
	npm config set proxy "$REPO_PROXY" >/dev/null 2>&1 || true
	npm config set https-proxy "$REPO_PROXY" >/dev/null 2>&1 || true
fi

# Fresh clone on each start
rm -rf "$REPO_DIR"

log "Cloning repository from provided URL"
if [[ -n "$REPO_TOKEN" ]]; then
	# Use Authorization header to avoid leaking token in process list or git remotes
	git \
		-c http.extraHeader="Authorization: Bearer ${REPO_TOKEN}" \
		-c http.extraHeader="PRIVATE-TOKEN: ${REPO_TOKEN}" \
		clone --depth 1 "$REPO_URL" "$REPO_DIR"
else
	git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
log "Clone complete at $(pwd)"

if [[ -f package.json ]]; then
	log "Installing Node dependencies"
	if [[ -f package-lock.json ]]; then
		npm ci
	else
		npm install
	fi
else
	log "No package.json found; proceeding without npm install"
fi

start_server() {
	# Allow user to override run command
	if [[ -n "$RUN_CMD" ]]; then
		log "Starting server using custom command"
		exec bash -lc "$RUN_CMD"
	fi

	# Prefer predictable scripts; default to npx .
	if [[ -f package.json ]]; then
		# npm run mcp
		if node -e "const p=require('./package.json'); process.exit(p.scripts&&p.scripts.mcp?0:1)" 2>/dev/null; then
			log "Running: npm run mcp"
			exec npm run mcp
		fi

		# npm start
		if node -e "const p=require('./package.json'); process.exit(p.scripts&&p.scripts.start?0:1)" 2>/dev/null; then
			log "Running: npm start"
			exec npm start
		fi

		# Fall back to npx .
		log "Running: npx ."
		exec npx --yes --prefer-online --quiet .
	fi

	# Try common Node entrypoints when no package.json
	if [[ -f server.js ]]; then
		log "Running: node server.js"
		exec node server.js
	fi

	log "Running: node ."
	exec node .
}

log "Starting MCP server"
start_server

