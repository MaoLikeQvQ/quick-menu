import Cocoa
import FinderSync
import OSLog

private struct MenuApp: Codable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
}

private struct MenuConfig: Codable {
    let apps: [MenuApp]
    let copyPath: Bool
    let delete: Bool
    let newFiles: [String]
    let authorizedFolders: [String]

    static let inactive = MenuConfig(
        apps: [],
        copyPath: false,
        delete: false,
        newFiles: [],
        authorizedFolders: []
    )
}

final class FinderSync: FIFinderSync {
    private static let configDidChangeNotification = Notification.Name("com.maolike.rclickreplacement.configDidChange")
    private static let configRequestNotification = Notification.Name("com.maolike.rclickreplacement.configRequest")
    private var config: MenuConfig
    private var menuRequests: [Int: URL] = [:]
    private var nextRequestID = 0

    override init() {
        NSLog("QuickMenu: initializing")
        // Open and Save panels create separate Finder Sync instances. Do not
        // read the host app's shared container from those instances; the host
        // replies to configRequestNotification with an in-memory snapshot.
        config = .inactive
        super.init()
        NSLog("QuickMenu: loaded %ld apps, %ld folders", config.apps.count, config.authorizedFolders.count)
        updateMonitoredDirectories()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(reloadConfig),
            name: Self.configDidChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().post(name: Self.configRequestNotification, object: nil)
    }

    @objc private func reloadConfig(_ notification: Notification) {
        if let json = notification.userInfo?["json"] as? String,
           let data = json.data(using: .utf8),
           let updated = try? JSONDecoder().decode(MenuConfig.self, from: data) {
            config = updated
            NSLog("QuickMenu: reloaded %ld apps, %ld folders", config.apps.count, config.authorizedFolders.count)
            updateMonitoredDirectories()
        }
    }

    private func updateMonitoredDirectories() {
        let directories = Set(config.authorizedFolders.map {
            URL(fileURLWithPath: $0, isDirectory: true)
                .resolvingSymlinksInPath()
                .standardizedFileURL
        })
        FIFinderSyncController.default().directoryURLs = directories
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        NSLog("QuickMenu: menu requested kind=%ld", menuKind.rawValue)
        let menu = NSMenu()
        menuRequests.removeAll()
        let selected = currentURLs()
        guard !selected.isEmpty, selected.allSatisfy(isAuthorized) else {
            let item = NSMenuItem(title: "当前文件夹未授权", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        if !config.apps.isEmpty {
            for app in config.apps {
                let item = NSMenuItem(title: app.name, action: #selector(openWith(_:)), keyEquivalent: "")
                item.target = self
                registerRequest(item, action: "open", value: app.bundleIdentifier, urls: selected)
                menu.addItem(item)
            }
        }

        if config.copyPath {
            menu.addItem(actionItem("拷贝路径", #selector(copyPath)))
        }

        if !config.newFiles.isEmpty {
            for fileType in config.newFiles {
                let item = NSMenuItem(title: "新建 \(fileType)", action: #selector(createFile(_:)), keyEquivalent: "")
                item.target = self
                registerRequest(item, action: "create", value: fileType, urls: selected)
                menu.addItem(item)
            }
        }

        return menu
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func registerRequest(_ item: NSMenuItem, action: String, value: String, urls: [URL]) {
        var components = URLComponents()
        components.scheme = "quickmenu"
        components.host = action
        components.queryItems = [URLQueryItem(name: "value", value: value)]
            + urls.map { URLQueryItem(name: "path", value: $0.path) }
        // Finder returns a copied menu item without representedObject, but preserves its tag.
        nextRequestID += 1
        item.tag = nextRequestID
        menuRequests[item.tag] = components.url
    }

    private func sendToHost(_ sender: NSMenuItem) {
        let logger = Logger(subsystem: "com.maolike.rclickreplacement", category: "actions")
        logger.notice("Menu action received")
        guard let request = menuRequests[sender.tag] else {
            logger.error("Menu action has no request URL")
            let alert = NSAlert()
            alert.messageText = "菜单已失效"
            alert.informativeText = "请重新右键打开菜单后再试。"
            alert.runModal()
            return
        }
        let hostURL = Bundle.main.bundleURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let options = NSWorkspace.OpenConfiguration()
        options.activates = false
        NSWorkspace.shared.open([request], withApplicationAt: hostURL, configuration: options) { _, error in
            logger.notice("Host dispatch finished; error: \(error?.localizedDescription ?? "none", privacy: .public)")
            if let error {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "无法执行快点菜单操作"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    @objc private func openWith(_ sender: NSMenuItem) {
        sendToHost(sender)
    }

    @objc private func copyPath() {
        let paths = currentURLs().map(\.path)
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        sendToHost(sender)
    }

    private func selectedURLs() -> [URL] {
        FIFinderSyncController.default().selectedItemURLs() ?? []
    }

    private func currentURLs() -> [URL] {
        let selected = selectedURLs()
        if !selected.isEmpty { return selected }
        if let targeted = FIFinderSyncController.default().targetedURL() { return [targeted] }
        return []
    }

    private func isAuthorized(_ url: URL) -> Bool {
        config.authorizedFolders.contains { folder in
            let root = URL(fileURLWithPath: folder).standardizedFileURL.path
            let path = url.standardizedFileURL.path
            return path == root || path.hasPrefix(root + "/")
        }
    }
}
