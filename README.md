# ZCode 智谱账号切换器 (macOS 专属原生版) / ZCode Account Switcher macOS

<p align="center">
  <img src="macOS/Resources/AppIcon.png" width="128" height="128" alt="ZCode Account Switcher macOS Icon">
</p>

> **⚠️ 注意 / Note**：本项目为 **macOS 专属原生客户端** (Native Swift / SwiftUI)，采用 Apple macOS 27 Apple Maps 双层水凝液态玻璃 (Dual-Layer Liquid Glass) 语言设计，非 Electron 架构。仅适用于 macOS 操作系统（macOS 13.0 及更高版本）。

---

## 🎯 功能特点

- **macOS 专属原生性能**：基于 Swift 5, SwiftUI, AppKit 及 Apple CryptoKit (AES-256-GCM) 构建，极度轻量通透，内存占用极低。
- **苹果最新 UI 美学**：全量复刻 macOS 27 / Apple Maps 双层水凝液态玻璃 (Dual-Layer Liquid Glass) 与 3D 凸透镜高光设计。
- **无损凭据快照**：支持为 BigModel 国内账号与 Z.ai 国际账号保存多个快照，切换前自动创建安全备份。
- **进程联动管理**：直接在界面中查看 ZCode 进程运行状态并进行一键启动或关闭。
- **安全隐私**：本地优先保存，凭据加密存储于本机，绝对不向外网传输敏感信息。

---

## 💻 系统要求

- **操作系统**：macOS 13.0 (Ventura) 或更高版本（支持 macOS 14 / macOS 15 / macOS 27）
- **架构**：Apple Silicon (M1/M2/M3/M4) 及 Intel 架构全原生支持

---

## 🚀 编译与构建 (Build & Run)

在 Mac 上克隆本项目并使用脚本进行一键原生打包：

```bash
git clone https://github.com/alaxrpg/zcode-account-switcher-mac.git
cd zcode-account-switcher-mac

# 运行 macOS 原生一键构建脚本
./scripts/build-native-mac.sh
```

构建成功后，App 会打包至 `dist/ZCode Account Switcher.app`，可以直接双击运行或拖拽至 `/Applications` 应用程序目录。

---

## 📖 使用说明

1. 在智谱 **ZCode 桌面客户端** 中正常登录账号。
2. 打开 **ZCode Account Switcher (macOS)**，点击 **`[+]`** 按钮保存当前账号为快照。
3. 在 ZCode 客户端中登录另一个账号后，重复保存快照步骤。
4. 后续点击任意保存的账号快照右侧的 **`[⇄]` 切换按钮**，即可实现一键无缝切换！

---

## 📄 免责声明

本项目基于 **MIT License** 开源，仅用于个人学习交流与研究使用。本项目非 ZCode / 智谱 AI 官方出品。

---

## 🔑 搜索关键词

`ZCode 账号切换器` `macOS 账号切换` `ZCode macOS Native` `SwiftUI ZCode` `BigModel 账号切换` `Z.ai 账号切换` `智谱清言多账号` `ZCode Account Switcher macOS`
