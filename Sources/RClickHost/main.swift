import AppKit
import SwiftUI
import UniformTypeIdentifiers

let configDidChangeNotification = Notification.Name("com.maolike.rclickreplacement.configDidChange")
let configRequestNotification = Notification.Name("com.maolike.rclickreplacement.configRequest")

struct MenuApp: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String

    init(id: UUID = UUID(), name: String, bundleIdentifier: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

struct MenuConfig: Codable, Equatable {
    var apps: [MenuApp]
    var copyPath: Bool
    var delete: Bool
    var newFiles: [String]
    var authorizedFolders: [String]
    var folderScopeVersion: Int?

    static let currentFolderScopeVersion = 1

    static let `default` = MenuConfig(
        apps: [
            MenuApp(name: "终端", bundleIdentifier: "com.apple.Terminal"),
            MenuApp(name: "文本编辑", bundleIdentifier: "com.apple.TextEdit")
        ],
        copyPath: true,
        delete: true,
        newFiles: ["TXT", "Markdown", "JSON", "DOCX", "PPTX", "XLSX"],
        authorizedFolders: [],
        folderScopeVersion: MenuConfig.currentFolderScopeVersion
    )
}

enum ConfigStore {
    static let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.maolike.rclickreplacement")
        ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("RClickReplacement", isDirectory: true)
    static let url = directory.appendingPathComponent("menu.json")

    static func load() -> MenuConfig {
        guard let data = try? Data(contentsOf: url), let config = try? JSONDecoder().decode(MenuConfig.self, from: data) else {
            save(.default)
            return .default
        }
        let migrated = migrateLegacyFolderScope(config)
        if migrated != config { save(migrated) }
        return migrated
    }

    static func save(_ config: MenuConfig) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func migrateLegacyFolderScope(_ config: MenuConfig) -> MenuConfig {
        guard config.folderScopeVersion == nil else { return config }
        var migrated = config
        // v0.1.0 silently monitored the entire home directory by default.
        if migrated.authorizedFolders == [NSHomeDirectory()] {
            migrated.authorizedFolders = []
        }
        migrated.folderScopeVersion = MenuConfig.currentFolderScopeVersion
        return migrated
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config = ConfigStore.load()
    private var settingsWindow: NSWindow?

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            do {
                try performMenuAction(url)
            } catch {
                showActionError(error)
            }
        }
    }

    private func performMenuAction(_ request: URL) throws {
        guard let components = URLComponents(url: request, resolvingAgainstBaseURL: false),
              components.scheme == "quickmenu",
              let action = components.host,
              let value = components.queryItems?.first(where: { $0.name == "value" })?.value else {
            throw actionError("菜单请求格式不正确。")
        }
        let paths = components.queryItems?.filter { $0.name == "path" }.compactMap(\.value) ?? []
        guard !paths.isEmpty, paths.allSatisfy({ $0.hasPrefix("/") }) else {
            throw actionError("没有可操作的文件或文件夹。")
        }
        let targets = paths.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL }
        guard targets.allSatisfy(isAuthorized) else {
            throw actionError("目标不在授权文件夹内，请在设置中添加对应文件夹。")
        }
        switch action {
        case "create":
            guard config.newFiles.contains(value), let target = targets.first else {
                throw actionError("该新建文件类型未启用。")
            }
            let isDirectory = try target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            let directory = isDirectory ? target : target.deletingLastPathComponent()
            guard isAuthorized(directory) else { throw actionError("目标目录未授权。") }
            let created = try NewFileCreator.create(type: value, in: directory)
            NSLog("QuickMenu: created %@", created.lastPathComponent)
            NSWorkspace.shared.activateFileViewerSelecting([created])
        case "open":
            guard config.apps.contains(where: { $0.bundleIdentifier == value }) else {
                throw actionError("该应用不在菜单配置中。")
            }
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: value) else {
                throw actionError("找不到应用 \(value)，请重新添加应用。")
            }
            let urls = try targets.map { target in
                let isDirectory = try target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                return value == "com.apple.Terminal" && !isDirectory ? target.deletingLastPathComponent() : target
            }
            NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: .init()) { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error { self?.showActionError(error) }
                    else { NSLog("QuickMenu: opened %ld item(s) with %@", urls.count, value) }
                }
            }
        default:
            throw actionError("不支持的菜单操作。")
        }
    }

    private func isAuthorized(_ url: URL) -> Bool {
        config.authorizedFolders.contains { folder in
            let root = URL(fileURLWithPath: folder).resolvingSymlinksInPath().standardizedFileURL.path
            return root == "/" || url.path == root || url.path.hasPrefix(root + "/")
        }
    }

    private func actionError(_ description: String) -> NSError {
        NSError(domain: "QuickMenu", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }

    private func showActionError(_ error: Error) {
        NSLog("QuickMenu: action failed: %@", error.localizedDescription)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "操作失败"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleConfigRequest),
            name: configRequestNotification,
            object: nil
        )
        publish(config)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "快点菜单")
        let menu = NSMenu()
        menu.addItem(withTitle: "打开设置", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "打开配置文件夹", action: #selector(openConfigFolder), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        showSettings()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(config: config) { [weak self] newConfig in
                self?.config = newConfig
                ConfigStore.save(newConfig)
                self?.publish(newConfig)
            }
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "快点菜单"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.titlebarAppearsTransparent = false
            let fixedSize = NSSize(width: 480, height: 720)
            window.setContentSize(fixedSize)
            window.contentMinSize = fixedSize
            window.contentMaxSize = fixedSize
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openConfigFolder() {
        NSWorkspace.shared.open(ConfigStore.directory)
    }

    @objc private func handleConfigRequest(_ notification: Notification) {
        publish(config)
    }

    private func publish(_ config: MenuConfig) {
        guard let data = try? JSONEncoder().encode(config),
              let json = String(data: data, encoding: .utf8) else { return }
        DistributedNotificationCenter.default().post(
            name: configDidChangeNotification,
            object: nil,
            userInfo: ["json": json]
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

struct SettingsView: View {
    @State private var config: MenuConfig
    let onSave: (MenuConfig) -> Void

    init(config: MenuConfig, onSave: @escaping (MenuConfig) -> Void) {
        _config = State(initialValue: config)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionHeader("Finder 菜单", icon: "cursorarrow.click.2")
                menuPage
                sectionHeader("打开方式", icon: "arrow.up.forward.app")
                appsPage
                sectionHeader("新建文件", icon: "doc.badge.plus")
                filesPage
                sectionHeader("授权文件夹", icon: "folder.badge.gearshape")
                foldersPage
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 26)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: config) { newConfig in
            onSave(newConfig)
        }
        .frame(width: 480, height: 720)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.top, 2)
    }

    private var menuPage: some View {
        settingGroup {
            settingRow("复制路径", icon: "doc.on.doc", detail: "将选中项目的完整路径放入剪贴板") {
                Toggle("", isOn: $config.copyPath).labelsHidden()
            }
        }
    }

    private var appsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingGroup {
                ForEach(config.apps) { app in
                    settingRow(app.name, icon: "arrow.up.forward.app", detail: app.bundleIdentifier) {
                        Button {
                            config.apps.removeAll { $0.id == app.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("移除应用")
                    }
                    if app.id != config.apps.last?.id { Divider().padding(.leading, 46) }
                }
                if config.apps.isEmpty {
                    emptyRow("还没有添加应用", icon: "app.dashed")
                }
            }
            Button { addApplication() } label: {
                Label("添加应用", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }

    private var filesPage: some View {
        settingGroup {
            ForEach(["TXT", "Markdown", "JSON", "DOCX", "PPTX", "XLSX"], id: \.self) { fileType in
                settingRow(fileType, icon: fileIcon(fileType), detail: "创建空的 .\(fileType == "Markdown" ? "md" : fileType.lowercased()) 文件") {
                    Toggle("", isOn: fileToggle(fileType)).labelsHidden()
                }
                if fileType != "XLSX" { Divider().padding(.leading, 46) }
            }
        }
    }

    private var foldersPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingGroup {
                ForEach(config.authorizedFolders, id: \.self) { folder in
                    settingRow(URL(fileURLWithPath: folder).lastPathComponent, icon: "folder", detail: folder) {
                        Button {
                            config.authorizedFolders.removeAll { $0 == folder }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("移除授权文件夹")
                    }
                    if folder != config.authorizedFolders.last { Divider().padding(.leading, 46) }
                }
                if config.authorizedFolders.isEmpty {
                    emptyRow("没有授权文件夹", icon: "folder.badge.questionmark")
                }
            }
            Button { addFolder() } label: {
                Label("添加文件夹", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            Text("Finder 菜单仅在已添加的文件夹及其子文件夹中显示。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func settingGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    private func settingRow<Trailing: View>(_ title: String, icon: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.vertical, 9)
    }

    private func emptyRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24).foregroundStyle(.secondary)
            Text(title).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    private func fileIcon(_ type: String) -> String {
        switch type {
        case "Markdown": return "text.book.closed"
        case "JSON": return "curlybraces"
        default: return "doc.text"
        }
    }

    private func fileToggle(_ type: String) -> Binding<Bool> {
        Binding(
            get: { config.newFiles.contains(type) },
            set: { enabled in
                if enabled, !config.newFiles.contains(type) {
                    let order = ["TXT", "Markdown", "JSON", "DOCX", "PPTX", "XLSX"]
                    config.newFiles.append(type)
                    config.newFiles.sort {
                        (order.firstIndex(of: $0) ?? order.endIndex) < (order.firstIndex(of: $1) ?? order.endIndex)
                    }
                }
                if !enabled { config.newFiles.removeAll { $0 == type } }
            }
        )
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }
        let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        guard !config.apps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else { return }
        config.apps.append(MenuApp(name: name, bundleIdentifier: bundleIdentifier))
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !config.authorizedFolders.contains(url.path) else { return }
        config.authorizedFolders.append(url.path)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
