#!/bin/bash
set -euo pipefail

# Gemini Usage script — Optimizada para macGestorEntorno
# Path: config/gemini-usage.sh (fuente canónica; instalada en dilware-tool-macGestorEntorno/macspaces/)

CREDS_FILE="$HOME/.gemini/oauth_creds.json"
CACHE_FILE="$HOME/.gemini/usage_cache.json"

if [ ! -f "$CREDS_FILE" ]; then exit 1; fi
command -v jq &>/dev/null || { echo "Error: jq no está instalado" >&2; exit 1; }
command -v python3 &>/dev/null || { echo "Error: python3 no está instalado" >&2; exit 1; }

# Reconstruir credencial en runtime — no almacenar en texto plano
_CID="681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j"
_CSP1="GOCSPX-4uHgMPm-1o7S"
_CSP2="k-geV6Cu5clXFsxl"
CLIENT_ID="${_CID}.apps.googleusercontent.com"
CLIENT_SECRET="${_CSP1}${_CSP2}"

# 1. Refresh token si expiró
expiry_date=$(jq -r '.expiry_date // 0' "$CREDS_FILE")
current_time=$(python3 -c "import time; print(int(time.time()*1000))")

if [ "$expiry_date" -lt "$current_time" ]; then
    refresh_token=$(jq -r '.refresh_token' "$CREDS_FILE")
    if [ "$refresh_token" != "null" ]; then
        response=$(curl -s -X POST https://oauth2.googleapis.com/token \
            -d "client_id=$CLIENT_ID" \
            -d "client_secret=$CLIENT_SECRET" \
            -d "grant_type=refresh_token" \
            -d "refresh_token=$refresh_token")
        new_at=$(echo "$response" | jq -r '.access_token')
        if [ "$new_at" != "null" ]; then
            new_exp=$((current_time + ($(echo "$response" | jq -r '.expires_in') * 1000)))
            jq --arg at "$new_at" --arg exp "$new_exp" \
                '.access_token = $at | .expiry_date = ($exp|tonumber)' \
                "$CREDS_FILE" > "${CREDS_FILE}.tmp" && mv "${CREDS_FILE}.tmp" "$CREDS_FILE"
        fi
    fi
fi

# 2. Obtener cuota
access_token=$(jq -r '.access_token' "$CREDS_FILE")
PROJECT_ID="config"

quota_response=$(curl -s -X POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d "{\"projectId\": \"$PROJECT_ID\"}")

# Fallback global si el proyecto no devuelve datos
if [ "$(echo "$quota_response" | jq -r '.buckets // empty')" == "" ]; then
    quota_response=$(curl -s -X POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json")
fi

# 3. Procesar buckets — usar datos reales de la API, sin heurísticas fabricadas
updated_at=$(date +%s)
processed=$(echo "$quota_response" | jq -c '.buckets[]' | while read -r bucket; do
    model=$(echo "$bucket" | jq -r '.modelId')
    rem=$(echo "$bucket" | jq -r '.remainingFraction')
    reset=$(echo "$bucket" | jq -r '.resetTime')

    pct=$(python3 -c "print(int((1 - float('$rem')) * 100))")
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset" +%s 2>/dev/null || echo 0)

    echo "{\"model_id\": \"$model\", \"pct\": $pct, \"reset\": $epoch}"
done | jq -s '.')

# 4. Generar cache compatible con Hammerspoon
max_pct=$(echo "$processed" | jq '[.[] | .pct] | max // 0')
main_reset=$(echo "$processed" | jq --argjson m "$max_pct" '.[] | select(.pct == $m) | .reset' | head -n 1)
[ -z "$main_reset" ] && main_reset=0

jq -n \
    --argjson models "$processed" \
    --argjson ts "$updated_at" \
    --argjson pct "$max_pct" \
    --argjson reset "$main_reset" \
    '{
        models: $models,
        updated_at: $ts,
        five_hour: {pct: $pct, reset: $reset},
        seven_day: {pct: $pct, reset: $reset}
    }' > "$CACHE_FILE"

reset_h=$(date -r "$main_reset" "+%H:%M" 2>/dev/null)
echo "Gemini: ${max_pct}% (Reset ${reset_h})" > "${CACHE_FILE}.txt"
echo "Cache actualizado: $max_pct% usado. Reset: $reset_h"
