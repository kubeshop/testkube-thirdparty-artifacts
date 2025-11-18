#!/bin/bash

# Script unificado para verificar y actualizar MinIO
# - Consulta Docker Hub para obtener la última versión oficial
# - Compara con la versión actual del repositorio
# - Si hay nueva versión, actualiza los archivos necesarios
#
# Uso:
#   ./check-and-update-minio.sh [--dry-run] [--update-files]
#
# Opciones:
#   --dry-run: Solo muestra qué se haría sin hacer cambios
#   --update-files: Actualiza los archivos (Dockerfile, Chart.yaml, values.yaml)

set -o errexit
set -o nounset
set -o pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MINIO_DIR="${SCRIPT_DIR}/.."
DOCKERFILE="${MINIO_DIR}/minio-release.dockerfile"
CHART_YAML="${MINIO_DIR}/helm/Chart.yaml"
VALUES_YAML="${MINIO_DIR}/helm/values.yaml"

# Docker Hub configuración
DOCKER_HUB_NAMESPACE="${DOCKER_HUB_NAMESPACE:-minio}"
DOCKER_HUB_REPOSITORY="${DOCKER_HUB_REPOSITORY:-minio}"
DOCKER_HUB_API_URL="https://hub.docker.com/v2/repositories/${DOCKER_HUB_NAMESPACE}/${DOCKER_HUB_REPOSITORY}/tags"

# Flags
DRY_RUN=false
UPDATE_FILES=false

# ============================================================================
# Funciones de utilidad
# ============================================================================

log_info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
  echo -e "${RED}✗${NC} $*" >&2
}

# ============================================================================
# Funciones para obtener versiones
# ============================================================================

# Obtener versión actual del Dockerfile
get_current_version() {
  local output_format="${1:-full}"  # "full" para tag completo, "semantic" para YYYY.MM
  
  if [ ! -f "$DOCKERFILE" ]; then
    log_error "No se encontró el Dockerfile en $DOCKERFILE"
    return 1
  fi
  
  # Buscar MINIO_SERVER_VERSION en el Dockerfile
  local version=$(grep -E "^(ARG|ENV)\s+MINIO_SERVER_VERSION=" "$DOCKERFILE" \
    | head -n 1 \
    | sed -E 's/.*MINIO_SERVER_VERSION=(RELEASE\.[^[:space:]]+).*/\1/' \
    | tr -d '[:space:]')
  
  if [ -z "$version" ]; then
    log_error "No se encontró MINIO_SERVER_VERSION en el Dockerfile"
    return 1
  fi
  
  # Convertir a versión semántica si se solicita
  if [ "$output_format" = "semantic" ]; then
    if [[ $version =~ RELEASE\.([0-9]{4})-([0-9]{2}) ]]; then
      local year="${BASH_REMATCH[1]}"
      local month="${BASH_REMATCH[2]}"
      echo "${year}.${month}"
    else
      echo "$version"
    fi
  else
    echo "$version"
  fi
}

# Obtener última versión oficial de Docker Hub
get_latest_version() {
  local output_format="${1:-full}"  # "full" para tag completo, "semantic" para YYYY.MM
  
  log_info "Consultando Docker Hub para obtener la última versión de MinIO..."
  
  # Consultar Docker Hub API
  # Filtrar tags que empiezan con RELEASE. y tienen el formato completo RELEASE.YYYY-MM-DDTHH-MM-SSZ
  # Ordenar por nombre (el formato permite orden lexicográfico descendente)
  local response=$(curl -s "${DOCKER_HUB_API_URL}?page_size=100&page=1" \
    | jq -r '.results[] | select(.name | startswith("RELEASE.")) | select(.name | test("^RELEASE\\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z$")) | .name' \
    | sort -r \
    | head -n 1)
  
  if [ -z "$response" ] || [ "$response" = "null" ]; then
    log_error "No se pudo obtener la versión de MinIO desde Docker Hub"
    return 1
  fi
  
  # Convertir a versión semántica si se solicita
  if [ "$output_format" = "semantic" ]; then
    if [[ $response =~ RELEASE\.([0-9]{4})-([0-9]{2}) ]]; then
      local year="${BASH_REMATCH[1]}"
      local month="${BASH_REMATCH[2]}"
      echo "${year}.${month}"
    else
      echo "$response"
    fi
  else
    echo "$response"
  fi
}

# Comparar dos tags de MinIO
# Retorna: -1 si tag2 > tag1, 0 si iguales, 1 si tag1 > tag2
compare_tags() {
  local tag1="$1"
  local tag2="$2"
  
  # Convertir a formato comparable eliminando "RELEASE." y comparando
  local date1=$(echo "$tag1" | sed 's/RELEASE\.//' | tr 'T' ' ' | sed 's/Z$//')
  local date2=$(echo "$tag2" | sed 's/RELEASE\.//' | tr 'T' ' ' | sed 's/Z$//')
  
  # Comparar usando sort
  if [ "$(printf "%s\n%s\n" "$date1" "$date2" | sort -V | head -n 1)" = "$date2" ]; then
    # date2 es mayor o igual
    if [ "$date1" = "$date2" ]; then
      echo "0"  # Iguales
    else
      echo "-1"  # tag2 es mayor
    fi
  else
    echo "1"  # tag1 es mayor
  fi
}

# ============================================================================
# Funciones para actualizar archivos
# ============================================================================

# Actualizar Dockerfile
update_dockerfile() {
  local new_version="$1"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Actualizaría Dockerfile: MINIO_SERVER_VERSION=$new_version"
    return 0
  fi
  
  # Actualizar ARG MINIO_SERVER_VERSION
  sed -i.bak "s/^ARG MINIO_SERVER_VERSION=.*/ARG MINIO_SERVER_VERSION=${new_version}/" "$DOCKERFILE"
  
  # Actualizar ENV MINIO_SERVER_VERSION
  sed -i.bak "s/^ENV MINIO_SERVER_VERSION=.*/ENV MINIO_SERVER_VERSION=${new_version}/" "$DOCKERFILE"
  
  # Actualizar LABEL version (versión semántica)
  local semantic_version=$(get_latest_version semantic)
  sed -i.bak "s/^LABEL.*version=\".*\"/LABEL maintainer=\"Testkube Team\" \\\\
      version=\"${semantic_version}\" \\\\
      description=\"Minio Server - Testkube Edition\"/" "$DOCKERFILE"
  
  # Limpiar archivos backup
  rm -f "${DOCKERFILE}.bak"
  
  log_success "Dockerfile actualizado"
}

# Actualizar Chart.yaml
update_chart_yaml() {
  local new_semantic_version="$1"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Actualizaría Chart.yaml: appVersion=$new_semantic_version"
    return 0
  fi
  
  # Actualizar appVersion
  sed -i.bak "s/^appVersion:.*/appVersion: \"${new_semantic_version}\"/" "$CHART_YAML"
  
  # Actualizar version (mantener iterador si existe, resetear a 0 si cambia la versión base)
  # Si la versión base cambia, resetear el iterador
  local current_chart_version=$(grep "^version:" "$CHART_YAML" | sed 's/^version: //' | tr -d '"')
  local current_base_version=$(echo "$current_chart_version" | cut -d'-' -f1)
  
  if [ "$current_base_version" != "$new_semantic_version" ]; then
    # Nueva versión base, resetear iterador
    sed -i.bak "s/^version:.*/version: ${new_semantic_version}-0/" "$CHART_YAML"
    log_info "Versión base cambió, iterador reseteado a 0"
  fi
  
  # Actualizar annotations image tag
  sed -i.bak "s|image: us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/minio:[0-9.]*|image: us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/minio:${new_semantic_version}|" "$CHART_YAML"
  
  # Limpiar archivos backup
  rm -f "${CHART_YAML}.bak"
  
  log_success "Chart.yaml actualizado"
}

# Actualizar values.yaml
update_values_yaml() {
  local new_semantic_version="$1"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Actualizaría values.yaml: image.tag=$new_semantic_version, clientImage.tag=$new_semantic_version"
    return 0
  fi
  
  # Actualizar image.tag (línea después de "image:")
  sed -i.bak '/^image:/,/^[a-zA-Z]/s/^  tag:.*/  tag: "'"${new_semantic_version}"'"/' "$VALUES_YAML"
  
  # Actualizar clientImage.tag (línea después de "clientImage:")
  sed -i.bak '/^clientImage:/,/^[a-zA-Z]/s/^  tag:.*/  tag: "'"${new_semantic_version}"'"/' "$VALUES_YAML"
  
  # Actualizar volumePermissions.image.tag si existe (bajo volumePermissions.image:)
  sed -i.bak '/^  volumePermissions:/,/^  [a-zA-Z]/s/^    tag:.*/    tag: "'"${new_semantic_version}"'"/' "$VALUES_YAML" || true
  
  # Limpiar archivos backup
  rm -f "${VALUES_YAML}.bak"
  
  log_success "values.yaml actualizado"
}

# Actualizar todos los archivos
update_all_files() {
  local new_version="$1"
  local new_semantic_version=$(echo "$new_version" | sed -E 's/RELEASE\.([0-9]{4})-([0-9]{2}).*/\1.\2/')
  
  log_info "Actualizando archivos con nueva versión: $new_version ($new_semantic_version)"
  
  update_dockerfile "$new_version"
  update_chart_yaml "$new_semantic_version"
  update_values_yaml "$new_semantic_version"
  
  log_success "Todos los archivos han sido actualizados"
}

# ============================================================================
# Función principal
# ============================================================================

main() {
  # Parsear argumentos
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --update-files)
        UPDATE_FILES=true
        shift
        ;;
      -h|--help)
        echo "Uso: $0 [--dry-run] [--update-files]"
        echo ""
        echo "Opciones:"
        echo "  --dry-run      Solo muestra qué se haría sin hacer cambios"
        echo "  --update-files Actualiza los archivos con la nueva versión"
        echo "  -h, --help     Muestra esta ayuda"
        exit 0
        ;;
      *)
        log_error "Opción desconocida: $1"
        exit 1
        ;;
    esac
  done
  
  log_info "Verificando actualizaciones de MinIO..."
  echo ""
  
  # Obtener versiones
  local current_version
  local latest_version
  
  current_version=$(get_current_version full)
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  latest_version=$(get_latest_version full)
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  # Mostrar versiones
  log_info "Versión actual del repositorio: $current_version"
  log_info "Última versión oficial en Docker Hub: $latest_version"
  echo ""
  
  # Comparar versiones
  local comparison
  comparison=$(compare_tags "$current_version" "$latest_version")
  
  if [ "$comparison" = "-1" ]; then
    # Hay nueva versión disponible
    local current_semantic=$(get_current_version semantic)
    local latest_semantic=$(get_latest_version semantic)
    
    log_success "¡Hay una nueva versión disponible!"
    echo ""
    log_info "Actualizar de: $current_version ($current_semantic)"
    log_info "Actualizar a:  $latest_version ($latest_semantic)"
    echo ""
    
    if [ "$UPDATE_FILES" = true ]; then
      update_all_files "$latest_version"
      echo ""
      log_success "Actualización completada. Por favor, revisa los cambios y crea un commit."
      exit 0
    elif [ "$DRY_RUN" = false ]; then
      log_warning "Usa --update-files para actualizar los archivos automáticamente"
      exit 0  # Hay nueva versión disponible
    else
      log_info "[DRY RUN] Se actualizarían los archivos a la nueva versión"
      update_all_files "$latest_version"
      exit 0  # Hay nueva versión disponible
    fi
  elif [ "$comparison" = "0" ]; then
    log_success "Ya está actualizado a la última versión"
    exit 1  # No hay nueva versión
  else
    log_warning "La versión actual es más reciente que la oficial"
    log_warning "Esto puede indicar un pre-release o un problema con la consulta"
    exit 1  # No hay nueva versión
  fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

