# 快点菜单

快点菜单是一款 macOS Finder 右键菜单工具，支持用指定应用打开文件或文件夹、拷贝完整路径，以及快速新建文本和 Office 文件。通过菜单栏设置常用应用、文件类型和生效目录，把日常文件操作放到右键菜单中。

## ✨ 核心优势

- ⚡ **右键直达**：常用应用、拷贝路径和新建文件直接显示在 Finder 右键菜单中，减少多层菜单切换。
- 🚀 **自选打开方式**：添加本机已安装的应用，使用 Cursor、PyCharm 等工具打开文件或文件夹；使用终端打开文件时，自动定位到文件所在目录。
- 📄 **多种新建类型**：支持 TXT、Markdown、JSON、DOCX、PPTX、XLSX，各类型可单独开启或关闭。
- 🛡️ **同名文件保护**：自动使用 `Untitled 2.txt` 等递增名称，避免覆盖已有文件。
- 📁 **自定义生效范围**：按文件夹配置菜单生效目录，新建和打开操作执行前会再次校验目录范围。
- ⚙️ **菜单栏快速配置**：随时添加应用、调整文件类型和管理目录，设置修改后自动保存并同步到扩展。
- 💻 **原生 macOS 实现**：使用 Swift、SwiftUI 和 Finder Sync，构建为同时包含 Apple Silicon 与 Intel 的 Universal 应用。
- 🔌 **本地运行**：菜单操作无需账号或网络服务，项目不依赖第三方 Swift 包。

## 🖼️ 界面预览

设置常用应用、文件类型和生效目录：

![快点菜单设置页面](docs/images/settings.png)

## 📦 下载与安装

系统要求：**macOS 13+**。下载包同时包含 Apple Silicon 与 Intel 架构；最低系统版本和 Intel 支持基于部署配置与编译结果，尚未覆盖所有系统版本和 Intel 真机测试。

### 1. 下载应用

前往 [GitHub Releases](https://github.com/MaoLikeQvQ/quick-menu/releases/latest)，下载 `QuickMenu-v0.1.0-macOS-universal.zip`。解压后，将 **快点菜单.app** 拖到“应用程序”文件夹。不要在 ZIP 内或临时解压目录中直接长期运行。

如需核对下载完整性，同时下载 `SHA256SUMS.txt`，在两个文件所在目录运行：

```sh
shasum -a 256 -c SHA256SUMS.txt
```

输出 ZIP 文件名和 `OK` 表示校验通过。

### 2. 处理下载隔离属性

当前发行包使用 ad-hoc 本地签名，**尚未进行 Developer ID 签名和 Apple 公证**。浏览器下载的应用可能带有 `com.apple.quarantine` 属性，macOS 可能因此阻止打开。

确认下载来源为本仓库 Release、文件校验通过后，优先尝试系统提供的“系统设置 → 隐私与安全性 → 仍要打开”。如需手动移除该应用的下载隔离属性，在终端执行：

```sh
xattr -dr com.apple.quarantine "/Applications/快点菜单.app"
open "/Applications/快点菜单.app"
```

`-d` 删除指定属性，`-r` 同时处理应用包内的文件和 Finder 扩展。命令只作用于上面的应用路径；若安装位置不同，请替换为实际路径。不要将目标改为整个下载目录、主目录或磁盘，也无需关闭 Gatekeeper 或 SIP。

如果提示 `No such xattr`，表示该属性不存在；若仍无法启动，应检查错误信息，而不是反复删除属性。如果提示权限不足，请先确认应用归属和安装位置，不要直接对大范围目录使用管理员权限。

移除隔离属性不会完成公证，也不会修复损坏或被篡改的应用。签名损坏时请重新下载或从源码构建。

### 3. 启用 Finder 扩展

打开快点菜单后，在系统设置中找到 Finder 扩展并启用：

- 较新的 macOS 通常位于“通用 → 登录项与扩展 → Finder”。
- 较旧版本可在“隐私与安全性 → 扩展”中查找。
- 具体路径随版本变化，可直接在系统设置中搜索“扩展”。

找到快点菜单或“快点菜单 Finder 扩展”，打开对应开关，然后回到 Finder。

### 4. 配置并开始使用

点击菜单栏中的快点菜单图标，选择“打开设置”：

1. 在“打开方式”中添加已安装的应用。
2. 在“新建文件”中勾选需要的文件类型。
3. 在“授权文件夹”中确认需要使用的目录。
4. 打开该目录，在 Finder 里右键文件、文件夹或空白处，选择对应菜单项。

默认配置包含终端、文本编辑、全部新建类型，默认生效范围为当前用户主目录。截图展示的是自定义配置，并非所有用户的默认菜单。

## 🖱️ 使用说明

### 用指定应用打开

在设置的“打开方式”区域点击“添加应用”，选择本机应用。右键选中的文件或文件夹，点击对应应用名称即可打开；在窗口空白处操作时，使用当前目标文件夹。

应用能否处理文件夹或某种文件格式，取决于应用自身。当前已实测 Finder 右键使用 Cursor 打开文件夹，其他应用尚未逐项验收。

### 拷贝路径

启用“复制路径”后，右键点击“拷贝路径”即可复制完整路径。多选时，每个项目的路径独占一行。

### 新建文件

| 菜单选项 | 文件后缀 | 初始内容 |
| --- | --- | --- |
| 新建 TXT | `.txt` | 空文本 |
| 新建 Markdown | `.md` | 空文本 |
| 新建 JSON | `.json` | 空文本，需自行填写有效 JSON |
| 新建 DOCX | `.docx` | 包含空白段落的 Word 文档 |
| 新建 PPTX | `.pptx` | 零幻灯片的空白演示文稿 |
| 新建 XLSX | `.xlsx` | 包含一张 `Sheet1` 空工作表 |

- 右键文件夹时，在该文件夹内新建；右键文件时，在文件所在目录新建。
- 多选时，以第一个项目确定新建目录。
- 新文件默认使用 `Untitled` 命名，遇到同名文件自动追加编号。
- 创建成功后，Finder 会定位并选中新文件；失败时显示错误提示。

Office 文件包含对应的 OOXML 文档结构。DOCX 已通过 macOS `textutil` 导入检查，PPTX、XLSX 已通过 ZIP/XML 结构检查，尚未逐个用 Office 桌面应用验证。

### 管理生效目录

在“授权文件夹”区域添加或移除目录。默认生效范围是当前用户主目录，可以按需要缩小。

这里的“授权”是应用自己的目录范围配置，不会绕过 macOS 隐私权限或文件系统权限。

## 🛠️ 从源码构建

需要 Swift 5.9 或更新的兼容工具链及 macOS SDK，可通过 Xcode 或 Command Line Tools 提供。

在项目根目录执行：

```sh
./Scripts/build-app.sh
```

脚本分别编译 ARM64 和 x86_64，合并为 Universal 应用，组装 Finder 扩展并进行本地签名。产物位于：

```text
build/快点菜单.app
```

仅执行 `swift build` 不会生成完整的应用包。Office 文件创建使用 macOS 自带的 `/usr/bin/zip`。

### 运行检查

```sh
# 需要 Python 3；覆盖六种文件创建、同名保护、错误处理和 Office 文档结构
bash Scripts/check-new-files.sh

# 校验应用包的本地签名
codesign --verify --deep --strict 'build/快点菜单.app'
```

Finder 菜单新建 TXT、Markdown、使用 Cursor 打开文件夹以及设置窗口滚动布局已做本机验证。自动检查不代替其他设备上的安装和交互测试。

## 📂 项目结构

```text
Sources/
├── RClickHost/
│   ├── main.swift              # 菜单栏、设置、配置保存和动作执行
│   └── NewFileCreator.swift    # 文本及 Office 文件创建
└── RClickFinder/
    └── main.swift              # Finder 右键菜单和动作转发
Resources/                      # 应用与扩展配置、entitlements
Scripts/
├── build-app.sh                # 双架构构建、打包与本地签名
└── check-new-files.sh          # 新建文件定向检查
Package.swift                   # Swift Package 配置
```

主应用负责设置、新建文件和启动指定应用；Finder 扩展负责菜单及目标选择，通过 `quickmenu` URL scheme 转交操作。菜单项使用 `tag` 关联请求，避免 Finder 复制菜单项时丢失参数。

## ❓ 常见问题

**右键菜单没有出现？**

确认应用已打开、Finder 扩展已启用，且当前目录在生效范围内。替换或移动应用后，可能需要重新启用扩展并重新启动 Finder。

本地开发时，可在项目根目录执行以下命令注册构建产物：

```sh
pluginkit -a "$PWD/build/快点菜单.app/Contents/PlugIns/RClickFinder.appex"
pluginkit -e use -i com.maolike.rclickreplacement.finder-extension
```

应用移到其他位置后，请使用对应的实际路径。若仍未刷新，可在完成正在进行的 Finder 操作后执行 `killall Finder`。

**指定应用打不开？**

确认应用仍然安装，并在设置中重新添加。部分应用不支持打开文件夹；无法找到应用、目录未授权或操作失败时，会显示错误提示。

**配置文件在哪里？**

点击菜单栏中的“打开配置文件夹”即可查看 `menu.json`。配置优先保存于 App Group 容器，无法获取容器时使用 Application Support 下的 `RClickReplacement` 目录。建议通过设置界面修改，以便同步到扩展。

**为什么还有“移到废纸篓”？**

快点菜单不再提供此操作，Finder 自带的“移到废纸篓”仍会保留。旧配置中的 `delete` 字段仅保留兼容读取。

## 许可证

当前尚未添加开源许可证。公开源码不等同于授予修改或再分发许可；许可证以仓库后续添加的 `LICENSE` 为准。
