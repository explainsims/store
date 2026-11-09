#!/bin/bash
# Installs Storefront from store.explainsims.com into Applications and opens it:
#   curl -fsSL https://store.explainsims.com/install.sh | bash
# Written when Storefront 1.2.0 was published; every publish rewrites it.
# Everything happens in main, called on the last line, so a download cut off halfway runs nothing.

main() {
    set -u
    local name='Storefront' app='Storefront.app' id='com.lennoxmeldrum.storefront' version='1.2.0'
    local url='https://github.com/explainsims/store/releases/download/storefront-1.2.0/Storefront-1.2.0.zip'
    local minimum=14

    ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
    fail() { printf '\n\033[1;31m✗ %s\033[0m\n\n' "$*" >&2; exit 1; }

    printf '\n\033[1mInstalling %s %s\033[0m\n\n' "$name" "$version"

    [ "$(uname -s)" = Darwin ] || fail "$name is a Mac app."
    local macos
    macos="$(sw_vers -productVersion)"
    [ "${macos%%.*}" -ge "$minimum" ] || fail "$name needs macOS $minimum or later (this Mac has $macos)."

    local work
    work="$(mktemp -d -t storefront-install)" || fail "Couldn't make a temporary folder."
    trap "rm -rf \"$work\"" EXIT

    curl -fL --progress-bar -o "$work/download.zip" "$url" \
        || fail "Couldn't download $name. Check the internet connection and try again."
    ditto -x -k "$work/download.zip" "$work/unzipped" || fail "The download was damaged. Try again."
    local found
    found="$(find "$work/unzipped" -maxdepth 3 -type d -name "$app" | head -n 1)"
    [ -n "$found" ] || fail "The download didn't contain $app."
    [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$found/Contents/Info.plist" 2>/dev/null)" = "$id" ] \
        || fail "The download wasn't $name."
    codesign --verify --deep --strict "$found" 2>/dev/null || fail "$name's signature didn't check out. Try again."
    ok "Downloaded $name $version"

    # Applications, or the Applications folder in your home folder when this account can't change the main one.
    local dest=/Applications
    if [ ! -w "$dest" ]; then
        dest="$HOME/Applications"
        mkdir -p "$dest"
    fi
    if osascript -e "application id \"$id\" is running" 2>/dev/null | grep -q true; then
        osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1
        sleep 2
    fi
    pkill -f "/$app/Contents/MacOS/" 2>/dev/null
    rm -rf "${dest:?}/$app"
    ditto --noqtn "$found" "$dest/$app" || fail "Couldn't put $name in $dest."
    xattr -dr com.apple.quarantine "$dest/$app" 2>/dev/null
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest/$app" 2>/dev/null
    ok "Installed in $dest"

    open "$dest/$app" && ok "$name is open: look for its icon in the menu bar"
    echo
}

main "$@"
