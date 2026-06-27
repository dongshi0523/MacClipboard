#!/bin/bash
cd "$(dirname "$0")"
echo "编译 MacClipboard..."
swiftc main.swift -o macclipboard \
    -framework SwiftUI -framework AppKit \
    -target arm64-apple-macosx14.0 \
    -O -parse-as-library
echo "✅ 编译完成: $(pwd)/macclipboard"
echo "运行: ./macclipboard"
