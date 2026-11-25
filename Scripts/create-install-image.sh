#!/bin/bash
set -euo pipefail

if [[ $# != 2 || "$2" != *.dmg ]]; then
    echo "Usage: $0 path/to/DisplayShift.app path/to/DisplayShift.dmg" >&2
    exit 2
fi

app=$1
image=$2
[[ ! -e "$image" ]]
test "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")" = com.displayshift.app
codesign --verify --deep --strict "$app"

staging=$(mktemp -d)
trap 'rm -rf -- "$staging"' EXIT
ditto "$app" "$staging/DisplayShift.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname DisplayShift -srcfolder "$staging" -format UDZO "$image"
hdiutil verify "$image"
