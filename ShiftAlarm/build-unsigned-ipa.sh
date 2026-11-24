#!/usr/bin/env bash
# 在没有开发者账号、也不想配签名的 Mac 上打一个未签名 IPA。
# 用途：借来的 Mac / 云 Mac 上跑一遍，把 IPA 拷回 Windows 用 Sideloadly 装到 iPhone。
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "▸ 安装 XcodeGen…"
  brew install xcodegen
fi

echo "▸ 生成工程…"
xcodegen generate

echo "▸ 编译（Release / 不签名）…"
xcodebuild \
  -project ShiftAlarm.xcodeproj \
  -scheme ShiftAlarm \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' | head -n 1)
if [ -z "$APP_PATH" ]; then
  echo "✗ 没找到 .app，编译失败了"; exit 1
fi

echo "▸ 打包 IPA…"
rm -rf Payload
mkdir Payload
cp -R "$APP_PATH" Payload/
zip -qry ShiftAlarm-unsigned.ipa Payload

echo "✅ 产物：$(pwd)/ShiftAlarm-unsigned.ipa"
