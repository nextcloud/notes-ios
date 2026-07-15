// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import Observation

///
/// A folder in the category hierarchy shown by ``FoldersView``.
///
/// Folders are derived from note categories by splitting them on `/`, so `Work/Projects` becomes a
/// folder `Projects` nested inside `Work`.
///
struct FolderNode: Identifiable, Hashable {
    ///
    /// The last path component, shown as the folder name.
    ///
    let name: String

    ///
    /// The complete category string identifying this folder.
    ///
    let fullPath: String

    ///
    /// Number of notes assigned to exactly this category, not counting subfolders.
    ///
    let directCount: Int

    let children: [FolderNode]

    var id: String { fullPath }
}

///
/// Observable data source for the folder hierarchy.
///
/// Watches all notes through an `NSFetchedResultsController` and derives the folder tree and counts
/// from their categories. Locally created folders without notes are merged in from
/// ``KeychainHelper/localFolders`` until a note is created in them.
///
@Observable
final class FoldersModel: NSObject, Logging, NSFetchedResultsControllerDelegate {
    let logger = makeLogger()

    private(set) var tree: [FolderNode] = []
    private(set) var allCount = 0
    private(set) var favoritesCount = 0
    private(set) var uncategorizedCount = 0

    var hasUncategorized: Bool {
        uncategorizedCount > 0
    }

    @ObservationIgnored private var fetchedResultsController: NSFetchedResultsController<Note>?

    override init() {
        super.init()
        configure()
    }

    ///
    /// The direct children of the folder identified by the given category.
    ///
    /// Notes without a category cannot have subfolders, so an empty string always yields an empty array.
    ///
    func subfolders(of category: String) -> [FolderNode] {
        guard !category.isEmpty else {
            return []
        }

        var nodes = tree

        for component in category.components(separatedBy: "/") {
            let match = nodes.first { $0.name == component }

            guard let match else {
                return []
            }

            nodes = match.children
        }

        return nodes
    }

    ///
    /// Remember a locally created folder and show it in the tree until a note is created in it.
    ///
    func addLocalFolder(_ name: String) {
        let path = name
            .components(separatedBy: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        guard !path.isEmpty, !KeychainHelper.localFolders.contains(path) else {
            return
        }

        KeychainHelper.localFolders.append(path)
        rebuild()
    }

    // MARK: - Fetching

    private func configure() {
        let request = Note.fetchRequest()
        request.fetchBatchSize = 288
        request.predicate = .allNotes
        request.sortDescriptors = [
            NSSortDescriptor(key: "category", ascending: true)
        ]

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: NotesData.mainThreadContext,
            sectionNameKeyPath: "category",
            cacheName: nil
        )
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try controller.performFetch()
            rebuild()
        } catch {
            logger.error("Failed to fetch notes for folders: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func rebuild() {
        let sections = fetchedResultsController?.sections ?? []
        let notes = fetchedResultsController?.fetchedObjects ?? []

        allCount = notes.count
        favoritesCount = notes.filter(\.favorite).count
        uncategorizedCount = sections.first { $0.name.isEmpty }?.numberOfObjects ?? 0

        var countsByCategory = [String: Int]()
        for section in sections where !section.name.isEmpty {
            countsByCategory[section.name] = section.numberOfObjects
        }

        // Local folders are only needed as long as no note carries their category.
        let localFolders = KeychainHelper.localFolders.filter { countsByCategory[$0] == nil }
        if localFolders != KeychainHelper.localFolders {
            KeychainHelper.localFolders = localFolders
        }

        tree = Self.buildTree(countsByCategory: countsByCategory, localFolders: localFolders)
    }

    private static func buildTree(countsByCategory: [String: Int], localFolders: [String]) -> [FolderNode] {
        final class Builder {
            var directCount = 0
            var children = [String: Builder]()
        }

        let root = Builder()

        func builder(for path: String) -> Builder {
            var current = root
            for component in path.components(separatedBy: "/") where !component.isEmpty {
                if let child = current.children[component] {
                    current = child
                } else {
                    let child = Builder()
                    current.children[component] = child
                    current = child
                }
            }
            return current
        }

        for (category, count) in countsByCategory {
            builder(for: category).directCount = count
        }

        for folder in localFolders {
            _ = builder(for: folder)
        }

        func nodes(of builder: Builder, parentPath: String) -> [FolderNode] {
            builder.children
                .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                .map { name, child in
                    let fullPath = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
                    return FolderNode(
                        name: name,
                        fullPath: fullPath,
                        directCount: child.directCount,
                        children: nodes(of: child, parentPath: fullPath)
                    )
                }
        }

        return nodes(of: root, parentPath: "")
    }

    // MARK: - NSFetchedResultsControllerDelegate

    @objc
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuild()
    }
}
