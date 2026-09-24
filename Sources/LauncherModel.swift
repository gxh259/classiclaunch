import AppKit

struct TileRef: Codable, Equatable {
    var kind: String // "app" or "folder"
    var id: String
}

struct FolderRecord: Codable {
    var name: String
    var apps: [String]
}

struct LauncherState: Codable {
    var tiles: [TileRef] = []
    var folders: [String: FolderRecord] = [:]
    var aliases: [String: String] = [:]
    var hidden: Set<String> = []
}

struct DisplayTile {
    let ref: TileRef
    let title: String
    let icons: [NSImage]
}

final class LauncherModel {
    private(set) var state: LauncherState
    private(set) var apps: [String: AppEntry] = [:]
    private let utilitiesFolderID = "builtin.utilities"
    private let store: LauncherStore

    init(store: LauncherStore = .shared) {
        self.store = store
        state = store.data.launcherState
        reloadCatalog()
    }

    func clearLoadedCatalog() {
        apps.removeAll(keepingCapacity: false)
    }

    func reloadCatalog() {
        clearLoadedCatalog()
        apps = Dictionary(uniqueKeysWithValues: AppCatalog.load().map { ($0.id, $0) })
        var seen = Set<String>()
        state.tiles = state.tiles.filter { ref in
            if ref.kind == "folder" { return state.folders[ref.id] != nil }
            guard !state.hidden.contains(ref.id), !seen.contains(ref.id) else { return false }
            seen.insert(ref.id); return true
        }
        for id in state.folders.keys {
            guard let existing = state.folders[id]?.apps else { continue }
            let filtered = existing.filter { appID in
                guard !state.hidden.contains(appID), !seen.contains(appID) else { return false }
                seen.insert(appID); return true
            }
            state.folders[id]?.apps = filtered
        }
        let emptyFolderIDs = state.folders.compactMap { $0.value.apps.isEmpty ? $0.key : nil }
        for id in emptyFolderIDs {
            state.folders.removeValue(forKey: id)
            state.tiles.removeAll { $0.kind == "folder" && $0.id == id }
        }
        let utilityIDs = Set(apps.values.filter { isUtility($0) }.map(\.id))
        if !utilityIDs.isEmpty && !store.data.utilitiesFolderInitialized {
            let rootUtilities = state.tiles.enumerated().compactMap { index, ref -> (Int, String)? in
                ref.kind == "app" && utilityIDs.contains(ref.id) ? (index, ref.id) : nil
            }
            let unplacedUtilities = utilityIDs.subtracting(seen).subtracting(state.hidden)
            if !rootUtilities.isEmpty || !unplacedUtilities.isEmpty {
                let folderID = utilitiesFolderIDForDisplay ?? utilitiesFolderID
                var folder = state.folders[folderID] ?? FolderRecord(name: "其他", apps: [])
                folder.apps += rootUtilities.map(\.1)
                state.folders[folderID] = folder
                state.tiles.removeAll { $0.kind == "app" && utilityIDs.contains($0.id) }
                if !state.tiles.contains(where: { $0.kind == "folder" && $0.id == folderID }) {
                    let index = min(rootUtilities.first?.0 ?? state.tiles.count, state.tiles.count)
                    state.tiles.insert(TileRef(kind: "folder", id: folderID), at: index)
                }
            }
            store.setUtilitiesFolderInitialized()
        }
        for app in apps.values.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            if !seen.contains(app.id) && !state.hidden.contains(app.id) {
                if utilityIDs.contains(app.id), let folderID = utilitiesFolderIDForDisplay {
                    state.folders[folderID]?.apps.append(app.id)
                } else {
                    state.tiles.append(TileRef(kind: "app", id: app.id))
                }
            }
        }
        save()
    }

    private var utilitiesFolderIDForDisplay: String? {
        if state.folders[utilitiesFolderID] != nil { return utilitiesFolderID }
        return state.folders.first(where: { $0.value.name == "其他" })?.key
    }

    private func isUtility(_ app: AppEntry) -> Bool {
        let path = app.url.standardizedFileURL.path
        return path.hasPrefix("/Applications/Utilities/") ||
               path.hasPrefix("/System/Applications/Utilities/")
    }

    func save() {
        store.saveState(state)
    }

    func title(for id: String) -> String { state.aliases[id] ?? apps[id]?.name ?? id }

    func tiles(in folderID: String? = nil, query: String = "") -> [DisplayTile] {
        if !query.isEmpty {
            return apps.values.filter { app in
                !state.hidden.contains(app.id) &&
                (title(for: app.id).localizedStandardContains(query) || app.name.localizedStandardContains(query))
            }.sorted { title(for: $0.id).localizedStandardCompare(title(for: $1.id)) == .orderedAscending }
             .map { DisplayTile(ref: TileRef(kind: "app", id: $0.id), title: title(for: $0.id), icons: [$0.icon]) }
        }
        let refs: [TileRef]
        if let folderID { refs = (state.folders[folderID]?.apps ?? []).map { TileRef(kind: "app", id: $0) } }
        else { refs = state.tiles }
        return refs.compactMap { ref in
            if ref.kind == "app" {
                guard let app = apps[ref.id] else { return nil }
                return DisplayTile(ref: ref, title: title(for: ref.id), icons: [app.icon])
            }
            guard let folder = state.folders[ref.id] else { return nil }
            let icons = Array(folder.apps.compactMap { apps[$0]?.icon }.prefix(9))
            guard !icons.isEmpty else { return nil }
            return DisplayTile(ref: ref, title: folder.name, icons: icons)
        }
    }

    func hide(_ id: String) {
        state.hidden.insert(id)
        state.tiles.removeAll { $0.kind == "app" && $0.id == id }
        for folderID in state.folders.keys { state.folders[folderID]?.apps.removeAll { $0 == id } }
        save()
    }

    func unhide(_ id: String) {
        state.hidden.remove(id)
        if let app = apps[id] {
            if isUtility(app), let folderID = utilitiesFolderIDForDisplay {
                state.folders[folderID]?.apps.append(id)
            } else {
                state.tiles.append(TileRef(kind: "app", id: id))
            }
        }
        save()
    }

    func renameApp(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { state.aliases.removeValue(forKey: id) }
        else { state.aliases[id] = trimmed }
        save()
    }

    func renameFolder(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.folders[id]?.name = trimmed
        save()
    }

    func ungroup(_ id: String) {
        guard let folder = state.folders.removeValue(forKey: id),
              let index = state.tiles.firstIndex(where: { $0.kind == "folder" && $0.id == id }) else { return }
        state.tiles.remove(at: index)
        state.tiles.insert(contentsOf: folder.apps.map { TileRef(kind: "app", id: $0) }, at: index)
        save()
    }

    func move(_ source: TileRef, onto target: TileRef?, in folderID: String?, createFolder: Bool) {
        if let folderID {
            guard source.kind == "app", var folder = state.folders[folderID],
                  let from = folder.apps.firstIndex(of: source.id) else { return }
            folder.apps.remove(at: from)
            let destination = target.flatMap { folder.apps.firstIndex(of: $0.id) } ?? folder.apps.count
            folder.apps.insert(source.id, at: destination)
            state.folders[folderID] = folder
            save(); return
        }
        guard let from = state.tiles.firstIndex(of: source) else { return }
        state.tiles.remove(at: from)
        if let target {
            if target.kind == "folder", source.kind == "app" {
                state.folders[target.id]?.apps.append(source.id)
            } else if createFolder && target.kind == "app" && source.kind == "app" {
                let targetIndex = state.tiles.firstIndex(of: target) ?? state.tiles.count
                state.tiles.removeAll { $0 == target }
                let id = UUID().uuidString
                state.folders[id] = FolderRecord(name: "新建文件夹", apps: [target.id, source.id])
                let index = min(targetIndex, state.tiles.count)
                state.tiles.insert(TileRef(kind: "folder", id: id), at: index)
            } else {
                let index = state.tiles.firstIndex(of: target) ?? state.tiles.count
                state.tiles.insert(source, at: index)
            }
        } else { state.tiles.append(source) }
        save()
    }

    func moveOutOfFolder(_ appID: String, folderID: String) {
        state.folders[folderID]?.apps.removeAll { $0 == appID }
        state.tiles.append(TileRef(kind: "app", id: appID))
        save()
    }
}
