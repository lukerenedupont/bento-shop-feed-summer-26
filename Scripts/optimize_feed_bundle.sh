#!/bin/bash
set -euo pipefail

SOURCE_BUNDLE_CANDIDATE="${SRCROOT}/../dossier-feed-bundle/bundle"
SOURCE_BUNDLE="$(cd "${SOURCE_BUNDLE_CANDIDATE}" 2>/dev/null && pwd -P || true)"
BUILT_BUNDLE="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bundle"
# Keep the optimized media outside DerivedData so simulator and device builds
# share it. A clean build should not mean recompressing hundreds of unchanged
# images and videos.
CACHE_ROOT="${SRCROOT}/.build-cache/OptimizedFeedBundle-v4"
CACHE_BUNDLE="${CACHE_ROOT}/bundle"
STAMP_FILE="${CACHE_ROOT}/source.stamp"

# Xcode launched from Finder has a minimal PATH and cannot see Homebrew tools.
# Resolve their standard Apple Silicon locations explicitly so device builds
# receive the same optimized bundle as command-line and simulator builds.
FFMPEG="$(command -v ffmpeg 2>/dev/null || true)"
FFPROBE="$(command -v ffprobe 2>/dev/null || true)"
PNGQUANT="$(command -v pngquant 2>/dev/null || true)"
CWEBP="$(command -v cwebp 2>/dev/null || true)"
[[ -x "${FFMPEG}" ]] || FFMPEG="/opt/homebrew/bin/ffmpeg"
[[ -x "${FFPROBE}" ]] || FFPROBE="/opt/homebrew/bin/ffprobe"
[[ -x "${PNGQUANT}" ]] || PNGQUANT="/opt/homebrew/bin/pngquant"
[[ -x "${CWEBP}" ]] || CWEBP="/opt/homebrew/bin/cwebp"

if [[ ! -d "${SOURCE_BUNDLE}/media" ]]; then
  echo "warning: Feed bundle is missing; skipping media optimization."
  exit 0
fi

case "${CACHE_ROOT}" in
  "${SRCROOT}/.build-cache/"*) ;;
  *) echo "error: Refusing unsafe cache path: ${CACHE_ROOT}"; exit 1 ;;
esac

SOURCE_STAMP="$({
  find "${SOURCE_BUNDLE}" -type f -exec stat -f '%N:%m:%z' {} \;
  printf 'image-max=1200;png-quality=62-82-speed8;jpeg-quality=76;video=540p24-crf29-fast-v4\n'
} | shasum -a 256 | awk '{print $1}')"

CACHED_STAMP=""
if [[ -f "${STAMP_FILE}" ]]; then
  CACHED_STAMP="$(<"${STAMP_FILE}")"
fi

if [[ "${SOURCE_STAMP}" != "${CACHED_STAMP}" || ! -d "${CACHE_BUNDLE}/media" ]]; then
  rm -rf "${CACHE_ROOT}"
  mkdir -p "${CACHE_BUNDLE}/media"

  find "${SOURCE_BUNDLE}" -maxdepth 1 -type f -exec cp {} "${CACHE_BUNDLE}/" \;

  while IFS= read -r -d '' source; do
    filename="$(basename "${source}")"
    extension="${filename##*.}"
    extension="$(printf '%s' "${extension}" | tr '[:upper:]' '[:lower:]')"
    output="${CACHE_BUNDLE}/media/${filename}"
    temporary="${output}.tmp"

    case "${extension}" in
      png)
        if ! /usr/bin/sips -Z 1200 "${source}" --out "${temporary}.png" >/dev/null \
          || [[ ! -f "${temporary}.png" ]]; then
          cp "${source}" "${temporary}.png"
        fi
        if [[ -x "${PNGQUANT}" ]]; then
          # Speed 8 is visually equivalent at feed-card size and avoids the
          # expensive exhaustive quantization that caused local memory alerts.
          "${PNGQUANT}" --force --strip --speed 8 --quality 62-82 \
            --output "${output}" -- "${temporary}.png" >/dev/null 2>&1 || cp "${temporary}.png" "${output}"
        else
          cp "${temporary}.png" "${output}"
        fi
        rm -f "${temporary}.png"
        ;;
      jpg|jpeg)
        /usr/bin/sips -Z 1200 -s format jpeg -s formatOptions 76 \
          "${source}" --out "${temporary}.jpg" >/dev/null
        mv "${temporary}.jpg" "${output}"
        ;;
      webp)
        if [[ -x "${CWEBP}" && -x "${FFPROBE}" ]]; then
          dimensions="$("${FFPROBE}" -v error -select_streams v:0 \
            -show_entries stream=width,height -of csv=s=x:p=0 "${source}")"
          width="${dimensions%x*}"
          height="${dimensions#*x}"
          if (( width > 1200 || height > 1200 )); then
            if (( width >= height )); then
              "${CWEBP}" -quiet -q 76 -resize 1200 0 "${source}" -o "${temporary}.webp"
            else
              "${CWEBP}" -quiet -q 76 -resize 0 1200 "${source}" -o "${temporary}.webp"
            fi
          else
            "${CWEBP}" -quiet -q 76 "${source}" -o "${temporary}.webp"
          fi
          mv "${temporary}.webp" "${output}"
        else
          cp "${source}" "${output}"
        fi
        ;;
      mp4)
        if [[ -x "${FFMPEG}" ]]; then
          "${FFMPEG}" -nostdin -loglevel error -y -i "${source}" -an \
            -vf "scale='min(540,iw)':-2:flags=lanczos,fps=24" \
            -c:v libx264 -preset fast -crf 29 -pix_fmt yuv420p \
            -movflags +faststart "${temporary}.mp4"
          mv "${temporary}.mp4" "${output}"
        else
          cp "${source}" "${output}"
        fi
        ;;
      *)
        cp "${source}" "${output}"
        ;;
    esac
  done < <(find "${SOURCE_BUNDLE}/media" -type f -print0)

  printf '%s' "${SOURCE_STAMP}" > "${STAMP_FILE}"
fi

case "${BUILT_BUNDLE}" in
  "${TARGET_BUILD_DIR}"/*) ;;
  *) echo "error: Refusing unsafe product path: ${BUILT_BUNDLE}"; exit 1 ;;
esac

rm -rf "${BUILT_BUNDLE}"
cp -R "${CACHE_BUNDLE}" "${BUILT_BUNDLE}"
printf '%s' "${SOURCE_STAMP}" > "${BUILT_BUNDLE}/.optimization-stamp"

ORIGINAL_BYTES="$(du -sk "${SOURCE_BUNDLE}" | awk '{print $1}')"
OPTIMIZED_BYTES="$(du -sk "${CACHE_BUNDLE}" | awk '{print $1}')"
echo "Optimized feed bundle: ${ORIGINAL_BYTES} KB -> ${OPTIMIZED_BYTES} KB"
