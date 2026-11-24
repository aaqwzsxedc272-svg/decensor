#!/usr/bin/env bash
set -Eeuo pipefail

JASNA_HOME="${JASNA_HOME:-/opt/jasna}"
JASNA_VERSION="${JASNA_VERSION:-v0.12.3}"

install_jasna() {
    if [[ -x "$JASNA_HOME/jasna" ]]; then
        return
    fi

    local api_url release_tag work_dir urls url
    api_url="https://api.github.com/repos/Kruk2/jasna/releases"
    if [[ "$JASNA_VERSION" == "latest" ]]; then
        api_url+="/latest"
    else
        api_url+="/tags/${JASNA_VERSION}"
    fi

    echo "Resolving Jasna release ${JASNA_VERSION} from GitHub..."
    release_tag="$(curl -fsSL "$api_url" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
    work_dir="$(mktemp -d /tmp/jasna-install.XXXXXX)"
    trap 'rm -rf "$work_dir"' EXIT

    mapfile -t urls < <(
        curl -fsSL "$api_url" | python3 -c '
import json, re, sys
release = json.load(sys.stdin)
pattern = re.compile(r"^jasna-linux-nvidia-" + re.escape(release["tag_name"].removeprefix("v")) + r"\.tar\.zst\.part\d+$")
assets = sorted((a for a in release.get("assets", []) if pattern.match(a["name"])), key=lambda a: a["name"])
if not assets:
    raise SystemExit("No official Linux NVIDIA release parts found for " + release["tag_name"])
for asset in assets:
    print(asset["browser_download_url"])
'
    )
    if (( ${#urls[@]} == 0 )); then
        echo "No Linux NVIDIA release files were found for ${release_tag}." >&2
        exit 1
    fi

    mkdir -p "$work_dir/parts" "$work_dir/unpacked"
    for url in "${urls[@]}"; do
        echo "Downloading $(basename "$url")..."
        wget --quiet --show-progress --progress=dot:giga -P "$work_dir/parts" "$url"
    done

    echo "Unpacking the official Jasna Linux NVIDIA release (this needs several GB of disk space)..."
    cat "$work_dir"/parts/*.part* | zstd -dc | tar -xpf - --same-owner -C "$work_dir/unpacked"
    local extracted
    extracted="$(find "$work_dir/unpacked" -mindepth 1 -maxdepth 1 -type d -name 'jasna-linux-nvidia-*' -print -quit)"
    if [[ -z "$extracted" || ! -x "$extracted/jasna" ]]; then
        echo "The release archive did not contain the expected jasna executable." >&2
        exit 1
    fi

    rm -rf "$JASNA_HOME"
    mv "$extracted" "$JASNA_HOME"
    rm -rf "$work_dir"
    trap - EXIT
    echo "Jasna ${release_tag} installed in ${JASNA_HOME}."
}

install_jasna
mkdir -p "${XDG_CONFIG_HOME:-/root/jasna-config}"
cd "$JASNA_HOME"

if (( $# == 0 )); then
    set -- bash
fi
exec "$@"
