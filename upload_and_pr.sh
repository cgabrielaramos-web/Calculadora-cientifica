#!/usr/bin/env bash
# upload_and_pr.sh
# Clona el repo, extrae el ZIP creado (por defecto calculadora_scientifica.zip),
# crea una rama feature/scientific-calculator, añade los archivos del ZIP,
# hace commit, push y abre un PR contra main.
#
# Requisitos:
#  - git, unzip, curl (o gh), jq (recomendado)
#  - GITHUB_TOKEN con permisos repo (export GITHUB_TOKEN=ghp_...)
#  - Opcional: GH CLI (gh). Si no está, el script usará la API con curl.
#
# Uso:
#   GITHUB_TOKEN=... bash upload_and_pr.sh [ZIP_PATH] [BRANCH] [PR_TITLE] [PR_BODY] [REPO]
#
# Ejemplo:
#   GITHUB_TOKEN="$GITHUB_TOKEN" bash upload_and_pr.sh calculadora_scientifica.zip feature/scientific-calculator "feat: scaffold calculadora científica" "Scaffold inicial: FastAPI + React, SymPy, SQLite" cgabrielaramos-web/Calculadora-cientifica
#
set -euo pipefail

# ------- Configuración por defecto -------
ZIP_PATH="${1:-calculadora_scientifica.zip}"
BRANCH="${2:-feature/scientific-calculator}"
PR_TITLE="${3:-feat: scaffold calculadora científica (FastAPI + React)}"
PR_BODY="${4:-Scaffold inicial: backend con FastAPI, SymPy y SQLite; frontend con React+Vite; Dockerfiles y docker-compose.}"
REPO="${5:-cgabrielaramos-web/Calculadora-cientifica}"   # owner/repo
DEFAULT_BASE="main"
TMPDIR=$(mktemp -d)
CLONE_DIR="$TMPDIR/repo"

# ------- Verificaciones iniciales -------
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: debes exportar GITHUB_TOKEN con permisos repo."
  echo "Ejemplo: export GITHUB_TOKEN=\"ghp_xxx\""
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "ERROR: ZIP no encontrado en $ZIP_PATH"
  exit 1
fi

echo "Repositorio objetivo: $REPO"
echo "ZIP a subir: $ZIP_PATH"
echo "Rama a crear: $BRANCH"
echo "Título PR: $PR_TITLE"
echo "Directorio temporal: $TMPDIR"
echo

# ------- Clonar el repo -------
echo "Clonando repo..."
git clone "https://github.com/$REPO.git" "$CLONE_DIR"
cd "$CLONE_DIR"

# Configurar remote usando token para push
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git"

# Comprobar existencia de la rama base (main). Si no existe, crear main vacío.
echo "Comprobando si existe la rama base '$DEFAULT_BASE' en el remoto..."
if ! git ls-remote --heads origin "$DEFAULT_BASE" >/dev/null 2>&1; then
  echo "La rama '$DEFAULT_BASE' no existe en remoto. Creando commit inicial en '$DEFAULT_BASE'..."
  # Crear rama main con commit inicial README si el repo está vacío localmente
  git checkout --orphan "$DEFAULT_BASE"
  git rm -rf . >/dev/null 2>&1 || true
  echo "# Inicial" > README.md
  git add README.md
  git commit -m "chore: initial commit (create $DEFAULT_BASE branch)"
  git push origin "$DEFAULT_BASE"
else
  echo "La rama '$DEFAULT_BASE' existe en remoto."
fi

# Actualizar referencias y crear la rama de trabajo a partir de main
git fetch origin "$DEFAULT_BASE"
git checkout -b "$BRANCH" "origin/$DEFAULT_BASE" 2>/dev/null || git checkout -b "$BRANCH"

# ------- Extraer ZIP y copiar contenido -------
echo "Extrayendo ZIP..."
UNZIP_DIR="$TMPDIR/unzipped"
mkdir -p "$UNZIP_DIR"
unzip -q "$ZIP_PATH" -d "$UNZIP_DIR"

# Determinar carpeta raíz dentro del ZIP (si existe una carpeta top-level)
# Si el ZIP contiene varios items en la raíz, copiar todo.
FIRST_DIR=$(find "$UNZIP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)
if [[ -n "$FIRST_DIR" ]]; then
  # Si dentro hay una carpeta llamada calculadora_scientifica o similar, usar su contenido
  echo "Copiando contenido de $FIRST_DIR a la raíz del repo..."
  rsync -a --delete --exclude='.git' "$FIRST_DIR"/. "$CLONE_DIR"/
else
  echo "No se encontró una carpeta top-level. Copiando todos los archivos del ZIP..."
  rsync -a --delete --exclude='.git' "$UNZIP_DIR"/. "$CLONE_DIR"/
fi

# ------- Commit & Push -------
git add .
# Evitar commit si no hay cambios
if git diff --cached --quiet; then
  echo "No hay cambios para commitear en la rama $BRANCH."
else
  git commit -m "feat: add scaffold calculadora científica (backend + frontend + docker)"
  echo "Pushing rama $BRANCH al remoto..."
  git push -u origin "$BRANCH"
fi

# ------- Comprobar si ya existe un PR para esta rama contra main -------
echo "Comprobando si ya existe un PR abierto desde la rama $BRANCH hacia $DEFAULT_BASE..."
API_BASE="https://api.github.com"
OWNER="$(echo "$REPO" | cut -d'/' -f1)"
REPO_NAME="$(echo "$REPO" | cut -d'/' -f2)"

EXISTING_PR_JSON=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
  "${API_BASE}/repos/${OWNER}/${REPO_NAME}/pulls?head=${OWNER}:${BRANCH}&base=${DEFAULT_BASE}&state=open")

if [[ -n "$EXISTING_PR_JSON" && "$EXISTING_PR_JSON" != "[]" ]]; then
  # Hay al menos 1 PR abierto. Mostrar el primero.
  if command -v jq >/dev/null 2>&1; then
    PR_URL=$(echo "$EXISTING_PR_JSON" | jq -r '.[0].html_url')
  else
    PR_URL=$(echo "$EXISTING_PR_JSON" | grep -o '"html_url":[^,]*' | head -n1 | sed -E 's/"html_url":\s*"([^"]+)"/\1/')
  fi
  echo "Ya existe un PR abierto: $PR_URL"
  echo "Saliendo sin crear un nuevo PR."
  exit 0
fi

# ------- Crear PR -------
echo "Creando PR..."
if command -v gh >/dev/null 2>&1; then
  echo "Usando GitHub CLI (gh) para crear PR..."
  gh auth login --with-token <<<"${GITHUB_TOKEN}" >/dev/null 2>&1 || true
  PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base "$DEFAULT_BASE" --head "$BRANCH" --repo "$REPO" --web || true)
  # gh pr create --web abriría el navegador; si gh pr create devolvió URL en stdout, usarla
  if [[ -z "$PR_URL" ]]; then
    # intentar crear y capturar URL con jq sobre salida JSON
    PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base "$DEFAULT_BASE" --head "$BRANCH" --repo "$REPO" --json url -q ".url" || true)
  fi
else
  echo "GH CLI no encontrada. Usando API con curl para crear PR..."
  DATA=$(jq -n --arg t "$PR_TITLE" --arg h "$BRANCH" --arg b "$DEFAULT_BASE" --arg bd "$PR_BODY" '{title:$t, head:$h, base:$b, body:$bd}')
  RESPONSE=$(curl -s -X POST -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
    "${API_BASE}/repos/${OWNER}/${REPO_NAME}/pulls" -d "$DATA")
  if command -v jq >/dev/null 2>&1; then
    PR_URL=$(echo "$RESPONSE" | jq -r '.html_url // empty')
  else
    PR_URL=$(echo "$RESPONSE" | grep -o '"html_url":[^,]*' | head -n1 | sed -E 's/"html_url":\s*"([^"]+)"/\1/')
  fi
fi

if [[ -z "${PR_URL:-}" ]]; then
  echo "ERROR: no se pudo crear PR o no se obtuvo la URL de PR. Respuesta cruda:"
  echo "---- API RESPONSE ----"
  if [[ -n "${RESPONSE:-}" ]]; then
    echo "$RESPONSE"
  fi
  echo "----------------------"
  exit 1
fi

echo "PR creado correctamente: $PR_URL"

# ------- Limpieza -------
cd /
rm -rf "$TMPDIR"

echo "Hecho."