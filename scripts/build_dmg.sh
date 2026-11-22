#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
cd "$project_dir"

source "${script_dir}/config.sh"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_NAME,,}"
mkdir -p "$cache_dir"

sdk_file="${cache_dir}/sdk_path.tmp"
xcrun --show-sdk-path >"$sdk_file" 2>/dev/null
if [[ ! -s "$sdk_file" ]]; then
    rm -f "$sdk_file"
    printf '%s\n' "Error: Failed to obtain SDK path from xcrun" >&2
    exit 1
fi
IFS= read -r sdk_path <"$sdk_file"
rm -f "$sdk_file"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' "Error: VERSION file must contain a version like 1.2.3 (found '${VERSION}')" >&2
    exit 1
fi

# Every build increments BUILD_NUMBER; the file is the single source of truth.
if [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    build_number=$((10#$BUILD_NUMBER + 1))
else
    build_number=1
fi
printf '%s\n' "$build_number" >"$build_num_file"
export BUILD_NUMBER="$build_number"

build_dir="build"
app_name="${APP_NAME}"
app_display_name="${APP_DISPLAY_NAME:-$app_name}"
bundle_id="${BUNDLE_ID}"
app_dir="${build_dir}/${app_display_name}.app"
contents_dir="${app_dir}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"

if [[ "$app_name" != "$app_display_name" && -d "${build_dir}/${app_name}.app" ]]; then
    rm -rf "${build_dir}/${app_name}.app"
fi

mkdir -p "$macos_dir" "$resources_dir"

if [[ -d "Resources" ]]; then
    cp -R Resources/. "${resources_dir}/"
fi

if [[ -f "VERSION" ]]; then
    cp "VERSION" "${resources_dir}/VERSION"
fi
printf '%s\n' "$build_number" >"${resources_dir}/BUILD_NUMBER"

sources=()
while IFS= read -r file; do
    sources+=("$file")
done < <(find Sources/App -type f -name "*.swift" | sort)

normalize_arch() {
    case "$1" in
    intel | x86_64 | amd64) printf '%s\n' "x86_64" ;;
    silicon | apple-silicon | arm64 | aarch64) printf '%s\n' "arm64" ;;
    *) printf '%s\n' "$1" ;;
    esac
}

arch_list=()
for a in ${ARCHS:-arm64 x86_64}; do
    arch_norm="$(normalize_arch "$a")"
    if [[ ! " ${arch_list[*]:-} " =~ [[:space:]]${arch_norm}[[:space:]] ]]; then
        arch_list+=("$arch_norm")
    fi
done

[[ ${#arch_list[@]} -gt 0 ]] || arch_list=("arm64" "x86_64")

printf '%s\n' "Compiling ${app_name} v${VERSION} (Build ${BUILD_NUMBER}) for ${arch_list[*]} (${#sources[@]} source files)..."
if [[ ${#arch_list[@]} -eq 1 ]]; then
    swiftc -sdk "$sdk_path" \
        -target "${arch_list[0]}-apple-macos${MIN_MACOS_VERSION}" \
        -O \
        -whole-module-optimization \
        -Xlinker -dead_strip \
        "${sources[@]}" \
        -o "${macos_dir}/${app_name}"
else
    tmp_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/${app_name}_build.XXXXXX")"
    trap 'rm -rf "$tmp_build_dir"' EXIT
    slice_bins=()
    for arch in "${arch_list[@]}"; do
        slice_bin="${tmp_build_dir}/${app_name}_${arch}"
        swiftc -sdk "$sdk_path" \
            -target "${arch}-apple-macos${MIN_MACOS_VERSION}" \
            -O \
            -whole-module-optimization \
            -Xlinker -dead_strip \
            "${sources[@]}" \
            -o "$slice_bin"
        slice_bins+=("$slice_bin")
    done
    lipo -create "${slice_bins[@]}" -output "${macos_dir}/${app_name}"
    rm -rf "$tmp_build_dir"
    trap - EXIT
fi

xml_escape() {
    local s="$1"
    shopt -u patsub_replacement 2>/dev/null || true
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    s="${s//\'/&apos;}"
    printf '%s' "$s"
}

app_name_xml="$(xml_escape "$app_name")"
app_display_name_xml="$(xml_escape "$app_display_name")"
bundle_id_xml="$(xml_escape "$bundle_id")"
version_xml="$(xml_escape "$VERSION")"
build_number_xml="$(xml_escape "$BUILD_NUMBER")"
min_macos_xml="$(xml_escape "$MIN_MACOS_VERSION")"
copyright_xml="$(xml_escape "$COPYRIGHT")"

printf '%s\n' "Generating ${app_name} Info.plist..."
lproj_dir="${resources_dir}/en.lproj"
mkdir -p "$lproj_dir"
cat <<EOF >"${lproj_dir}/InfoPlist.strings"
"CFBundleDisplayName" = "${app_display_name}";
"CFBundleName" = "${app_display_name}";
EOF
cat <<EOF >"${contents_dir}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${app_name_xml}</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id_xml}</string>
    <key>CFBundleName</key>
    <string>${app_display_name_xml}</string>
    <key>CFBundleDisplayName</key>
    <string>${app_display_name_xml}</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>LSHasLocalizedDisplayName</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${version_xml}</string>
    <key>CFBundleVersion</key>
    <string>${build_number_xml}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>${min_macos_xml}</string>
    <key>LSUIElement</key>
    <${LS_UI_ELEMENT}/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>${copyright_xml}</string>
</dict>
</plist>
EOF

# macOS remembers granted permissions (TCC) against the app's designated requirement.
# When ad-hoc signing, pin the requirement to the bundle ID for local development persistence.
# Hardened runtime (--options runtime) is enforced to prevent DYLD library injection.
signing_identity="${SIGNING_IDENTITY:--}"
sign_args=(--force --deep --options runtime --sign "$signing_identity")

if [[ "$signing_identity" == "-" ]]; then
    designated_requirement="designated => identifier \"${bundle_id}\""
    sign_args+=(--requirements "=${designated_requirement}")
    printf '%s\n' "Signing ${app_name} bundle (ad-hoc hardened, ${designated_requirement})..."
else
    printf '%s\n' "Signing ${app_name} bundle (identity: ${signing_identity}, hardened runtime)..."
fi

codesign "${sign_args[@]}" "$app_dir"

if [[ "$signing_identity" == "-" ]]; then
    signed_requirement="$(codesign -d -r- "$app_dir" 2>&1 | grep '^designated => ' || true)"
    if [[ "$signed_requirement" != "$designated_requirement" ]]; then
        printf '%s\n' "Error: Unexpected designated requirement '${signed_requirement}'; permissions would not persist." >&2
        exit 1
    fi
fi

printf '%s\n' "Refreshing macOS LaunchServices cache..."
touch "$app_dir"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$app_dir" >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

printf '%s\n' "✅ Build complete:"
printf '%s\n' "   - ${app_dir}"
