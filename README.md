# AI Monitor

macOS 菜单栏应用，实时监控 Claude 和 Codex 用量。

<img width="280" alt="AI Monitor" src="https://github.com/user-attachments/assets/febb7647-e46e-4377-9401-85a679720898" />

## 功能

### Claude 监控
- **环形指示器** — 5 小时会话 / 7 日额度 / 今日 Tokens
- **倒计时** — 各额度重置时间
- **套餐识别** — 自动显示 Pro / Max / Team 标签
- **用量提示** — 根据消耗速度给出操作建议

### Codex 监控
- **环形指示器** — Primary（5 小时）/ Secondary（7 日）/ Credits 余额
- **OAuth 认证** — 自动读取 `~/.codex/auth.json`，支持 Token 刷新
- **限额提示** — 到达限额时显示"已用尽"

### 通用
- **独立开关** — Claude / Codex 各自独立控制，互不影响
- **毛玻璃背景** — 原生 macOS vibrancy 效果
- **自适应颜色** — 深色 / 浅色模式自动切换对比度
- **菜单栏环形图标** — 按用量变色：绿 < 60%，橙 60–90%，红 ≥ 90%
- **连接提示** — 成功 / 失败 toast 通知

## 系统要求

- macOS 14.0（Sonoma）及以上
- Xcode 16+（仅编译时）

## 安装

### 方式一：下载编译好的包

前往 [Releases](../../releases) 页面下载最新 `.zip`，解压后将 `AI Monitor.app` 拖入 `/Applications`。

### 方式二：从源码编译

```bash
git clone https://github.com/h-k-c/ClaudeMonitor.git
cd ClaudeMonitor
open ClaudeMonitor.xcodeproj
```

在 Xcode 中选择 `Product → Archive`，或直接运行（⌘R）。

> **注意**：首次运行需在 Xcode Signing & Capabilities 中配置你自己的 Team / Bundle ID。

## 使用方法

### Claude

1. 启动应用，打开 Claude 开关
2. 按提示获取 `sessionKey`：
   - 浏览器打开 [claude.ai](https://claude.ai) 并登录
   - F12 → Application → Cookies
   - 找到 `sessionKey` 字段，复制其值
3. 粘贴到输入框，点击「连接」

### Codex

1. 在终端运行 `codex` 登录 ChatGPT 账号
2. 打开 Codex 开关，应用自动读取 `~/.codex/auth.json`

## 数据来源

| 数据 | 来源 |
|------|------|
| Claude 会话 / 7 日用量 | `claude.ai` 官方 API（需 sessionKey） |
| 今日 Token 数 | 本地 `buddy-tokens.json`（由 Claude Code 生成） |
| Codex 用量 | `chatgpt.com/backend-api/wham/usage`（OAuth Token） |

## 隐私

- 所有请求直接发往 `claude.ai` / `chatgpt.com`，不经过任何第三方服务器
- `sessionKey` 仅存储在本机
- Codex OAuth Token 存储在 `~/.codex/auth.json`

## License

MIT
