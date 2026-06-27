# MacClipboard

macOS 剪贴板历史管理器 —— 轻量级、半透明悬浮球设计，终端启动。

## 功能

- 🔵 半透明毛玻璃悬浮球，始终置顶，可拖拽
- 📋 点击展开剪贴板历史面板，实时记录复制内容
- 📄 点击历史条目直接复制，面板不关闭可连续操作
- ✕ 单条删除 / 一键清除全部
- ⌨️ 全局快捷键 `⌘⇧V` 唤起/收起
- 🚪 退出方式：右键悬浮球选「退出」或面板内点「退出」按钮
- 💾 最多保存 200 条历史记录

## 安装

```bash
# 克隆仓库
git clone https://github.com/dongshi0523/MacClipboard.git
cd MacClipboard

# 编译
chmod +x build.sh
./build.sh
```

## 使用

```bash
# 启动
./macclipboard

# 或添加 alias 后直接输入
macclipboard
```

## 系统要求

- macOS 14.0+
- Apple Silicon (arm64)
- Xcode Command Line Tools

## 技术栈

- SwiftUI + AppKit
- 纯 Swift 单文件实现
- 编译产物仅 ~240KB

## License

MIT
