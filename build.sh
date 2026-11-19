#!/bin/sh
# Packages the app into KickViewer.zip for uploading to a Roku in developer mode.
set -e
cd "$(dirname "$0")"
rm -f KickViewer.zip
zip -r KickViewer.zip manifest source components images -x "*.DS_Store"
echo "Built KickViewer.zip"
