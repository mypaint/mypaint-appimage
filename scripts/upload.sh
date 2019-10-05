#!/bin/bash
#
# This script is set up specifically for use with travis
# and the release.py script. It is used to safely
# replace continous releases and releases with rotating
# assets (so that older builds can be accessed for a
# limited time period - for testing/comparison)

set +e

# Do not upload non-master branch builds
if [ "$TRAVIS_EVENT_TYPE" == "pull_request" ] ; then
  echo "Release uploading disabled for pull requests"
  echo "Uploading to transfer.sh"
  rm -f ./uploaded-to
  for file in "$@"; do
    curl --upload-file "$file" "https://transfer.sh/$(basename "${file}")"
  done
  exit 0
fi

rel_script="$(readlink -f "$(dirname "$0")")"/release.py

rel()
{
    $rel_script -a GITHUB_TOKEN "$TRAVIS_REPO_SLUG" "$@"
}

# == Create new continous release ==
rel_tag="continuous"
rel_body="Build log: $TRAVIS_BUILD_WEB_URL"
rel_name="Continuous release"
# Create a new draft release
id=$(
    rel create $rel_tag -n "$rel_name" -b "$rel_body" --draft=true \
	--commitish="$TRAVIS_COMMIT" --prerelease=true
  )
if [ -n "$id" ]; then
    # Upload assets to draft release
    rel upload-asset -i "$id" "$@"
    # Delete old continuous release
    rel delete -t "$rel_tag"
    # Set draft release as new (non-draft) continuous release
    rel edit -i "$id" --draft=false
else
    echo "Failed to create new continuous release draft!"
fi

# == Upload to rotating release ==
rel_tag="continuous-rotating"
# Create if it does not exist
rel create $rel_tag
rel_body="Last updated: $(date -R)
Latest build log: $TRAVIS_BUILD_WEB_URL
"
rel edit -t $rel_tag --body="$rel_body" --name "$rel_name - (rotating)"
rel upload-asset -t $rel_tag --replace --max-assets 10 "$@"
