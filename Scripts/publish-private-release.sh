#!/bin/bash
set -euo pipefail

if [[ $# != 2 ]]; then
    echo "Usage: $0 path/to/DisplayShift.app path/to/Sparkle/bin/sign_update" >&2
    exit 2
fi

app=$1
sign_update=$2
repository=egekrdl/DisplayShift
account=com.displayshift.app
info="$app/Contents/Info.plist"
version=$(plutil -extract CFBundleShortVersionString raw "$info")
build=$(plutil -extract CFBundleVersion raw "$info")
minimum=$(plutil -extract LSMinimumSystemVersion raw "$info")
public_key=$(plutil -extract SUPublicEDKey raw "$info")
tag="v$version"
archive_name="DisplayShift-$version.zip"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[0-9]+$ &&
   "$minimum" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
[[ "$(plutil -extract CFBundleIdentifier raw "$info")" == "$account" ]]
[[ "$(plutil -extract SURequireSignedFeed raw "$info")" == true ]]
[[ "$(plutil -extract SUVerifyUpdateBeforeExtraction raw "$info")" == true ]]
[[ "$public_key" == "$("$(dirname "$sign_update")/generate_keys" --account "$account" -p)" ]]
[[ "$(gh repo view "$repository" --json visibility --jq .visibility)" == PRIVATE ]]
executable=$(plutil -extract CFBundleExecutable raw "$info")
test -f "$app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"
for architecture in $(lipo -archs "$app/Contents/MacOS/$executable"); do
    otool -arch "$architecture" -l "$app/Contents/MacOS/$executable" |
        grep -F 'path @executable_path/../Frameworks (offset' >/dev/null
done
codesign --verify --deep --strict "$app"

output=$(mktemp -d)
trap 'rm -rf -- "$output"' EXIT
archive="$output/$archive_name"
ditto -c -k --keepParent "$app" "$archive"
signature=$("$sign_update" --account "$account" -p "$archive")
"$sign_update" --account "$account" --verify "$archive" "$signature"
length=$(stat -f %z "$archive")

if gh release view "$tag" --repo "$repository" >/dev/null 2>&1; then
    echo "Release $tag already exists. Inspect the existing release before retrying." >&2
    exit 1
fi

revision=$(git rev-parse HEAD)
gh release create "$tag" "$archive" --repo "$repository" --target "$revision" \
    --draft --title "DisplayShift $version" --notes "Private, signed DisplayShift update."
asset_id=$(gh api --paginate "repos/$repository/releases" \
    --jq ".[] | select(.tag_name == \"$tag\" and .draft) | .assets[] | select(.name == \"$archive_name\") | .id")
[[ "$asset_id" =~ ^[0-9]+$ ]]

cat > "$output/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>DisplayShift Updates</title>
        <item>
            <title>DisplayShift $version</title>
            <sparkle:version>$build</sparkle:version>
            <sparkle:shortVersionString>$version</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>$minimum</sparkle:minimumSystemVersion>
            <enclosure url="https://api.github.com/repos/$repository/releases/assets/$asset_id"
                       length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
        </item>
    </channel>
</rss>
XML

"$sign_update" --account "$account" "$output/appcast.xml"
"$sign_update" --account "$account" --verify "$output/appcast.xml"
gh release upload "$tag" "$output/appcast.xml" --repo "$repository"
gh release edit "$tag" --repo "$repository" --draft=false --latest
