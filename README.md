# 译译 (Yiyi)

一个极简的 macOS 划词翻译，用 DeepSeek。对标 Bob 的核心体验，纯开源、按 token 计费、个人自用几乎 0 成本。

## 功能

- 菜单栏常驻，无 Dock 图标（`LSUIElement`）
- 全局热键 `⌥D`，选中任意 App 中的文字即可翻译
- 悬浮毛玻璃面板（原生 `NSVisualEffectView`），苹果风
- 流式输出（SSE）
- Esc 关闭，⌘⇧C 复制（面板内点按钮）
- API Key 存 macOS Keychain，进程内缓存，避免反复弹密码

## 系统要求

- macOS 13.0+
- Swift 5.9+（Xcode 15 / Command Line Tools 即可）

## 构建 & 启动

```bash
./build.sh
open "build/译译.app"
```

构建脚本会做 `swift build -c release` + 拷贝 Info.plist + ad-hoc 代码签名。

## 首次配置（4 步）

### 1. 给"辅助功能"权限

⌥D 取词依赖辅助功能权限（用 AX API 读选中文本，或模拟 ⌘C）。

- 第一次启动时系统会弹"译译 想要控制此电脑…"对话框 → **打开系统设置**
- **系统设置 → 隐私与安全性 → 辅助功能** → 把"译译"打勾

### 2. 填 DeepSeek API Key

- 去 https://platform.deepseek.com **注册 + 充值**（账号是预付费，至少充几块钱）
- 左侧 **API Keys → Create new API Key**，复制 `sk-...`
- 回到 译译：**菜单栏右上角"译"图标 → 设置… → DeepSeek API Key** 粘贴 → 保存

### 3. 允许访问 Keychain

第一次按 ⌥D 翻译时，macOS 会弹一次"译译 想访问你 Keychain 中的密码"对话框：
- 点 **始终允许**（不点就要每次都输密码）

之后进程内会缓存这个 key，本次启动不再访问 Keychain。

### 4. 试一下

随便选段文字 → 按 **⌥D** → 屏幕中央应该弹出毛玻璃面板，流式输出译文。Esc 关闭。

## 重新编译后的注意事项 ⚠️

每次 `./build.sh` 都会重新 ad-hoc 签名，二进制 `cdhash` 变化，导致：

1. **辅助功能权限失效** —— 看着还勾着，但系统认成新 app。表现：按 ⌥D 听到"咚"一声但没反应。  
   修复：
   ```bash
   tccutil reset Accessibility com.yiyi.app
   ```
   然后重启 app，按 ⌥D 重新走授权流程。或者去系统设置里把旧的"译译"条目 **－** 掉，再勾新的。

2. **Keychain 又要弹密码** —— 上一次"始终允许"是绑在旧 cdhash 上。每次重 build 后第一次按 ⌥D 会再弹一次，再点一次"始终允许"即可。

## 取词机制

`TextCapture.grabSelectedText` 走两条链路：

1. **默认（Accessibility API）**：读焦点 UI 元素的 `kAXSelectedTextAttribute`。不动剪贴板，无副作用。
   - 适用：原生 NSTextView / UITextField 类控件
   - 不适用：Chrome / Electron / Safari 网页内容、终端、PDF 阅读器
2. **兜底（模拟 ⌘C）**：备份剪贴板 → 模拟 ⌘C → 等 0.12 秒 → 读剪贴板 → 还原。
   - 优点：几乎所有 app 通吃
   - 副作用：剪贴板瞬间会变（再恢复），剪贴板管理器（如 Paste、Maccy）可能多记一条历史

## 翻译 / 模型

- API：`https://api.deepseek.com/chat/completions`（OpenAI 兼容）
- 模型：`deepseek-chat`（DeepSeek 官方主力模型别名）
- 流式 SSE，`temperature=0.3`
- system prompt：中文 → 英文；其他语言 → 中文；直出译文不加解释

## 成本

按 deepseek-chat 当前定价：输入 ¥2/M tokens（缓存命中 ¥0.5/M），输出 ¥8/M tokens。

- 一次翻译 ≈ 输入 50 + 输出 100 tokens
- 每天 100 次 ≈ 月成本几分钱

充 10 块钱够用很久。

## 调试日志

代码里在关键路径打了 `NSLog`（不会泄露 key 内容，只打长度）。从终端直接跑二进制查看：

```bash
pkill -f "build/译译.app/Contents/MacOS/Yiyi"
./build/译译.app/Contents/MacOS/Yiyi
```

或写到文件里：

```bash
nohup ./build/译译.app/Contents/MacOS/Yiyi > /tmp/yiyi.log 2>&1 &
tail -f /tmp/yiyi.log
```

## 技术栈

- Swift 5.9 + SwiftUI
- AppKit（NSPanel + NSVisualEffectView）
- [HotKey](https://github.com/soffes/HotKey) 全局快捷键
- DeepSeek OpenAI 兼容 API，URLSession + SSE

## TODO（按需扩展）

- [ ] OCR 截图翻译（macOS Vision framework）
- [ ] 自定义热键
- [ ] 多翻译引擎 fallback（Qwen / Kimi）
- [ ] 钉住窗口
- [ ] 历史记录
- [ ] 用稳定的 Developer ID 签名（避免每次 rebuild 后重新授权）
