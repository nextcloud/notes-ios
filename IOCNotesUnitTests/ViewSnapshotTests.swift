// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Testing
import UIKit
@testable import iOCNotes

///
/// Renders the redesigned screens to images under `/tmp`, so their layout can be reviewed without an account.
///
/// The app needs a signed-in account before its tab bar exists, so the screens are rendered on their own:
/// the settings page, the note rows inside a native list, and the editor in both display modes.
///
@MainActor
@Suite("View snapshots")
struct ViewSnapshotTests {
    private struct Row: Identifiable {
        let id: Int
        let title: String
        let snippet: String
        let age: TimeInterval
        let favorite: Bool
    }

    private let rows = [
        Row(id: 1, title: "Weekly review", snippet: "What went well, what did not, and what to change next week.", age: 90, favorite: true),
        Row(id: 2, title: "Groceries", snippet: "Milk, bread, tomatoes, olive oil and something for dinner on Sunday.", age: 3_600, favorite: false),
        Row(id: 3, title: "Ideas for the trip", snippet: "Train to Innsbruck, two nights, then the hut. Pack the small tent.", age: 86_400, favorite: false),
        Row(id: 4, title: "A very long note title that has to be truncated", snippet: "A long snippet that should wrap at most twice and then be cut off with an ellipsis instead of pushing the next row away.", age: 86_400 * 40, favorite: false)
    ]

    private let editorText = """
    # Groceries

    A **bold** word, an *italic* one, ==highlighted== text and `code`.

    - [ ] Milk
    - [x] Bread

    > A quote
    """

    /// The repository's own snapshot folder, so the images can be reviewed from the workspace.
    private static let outputDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(".snapshots", isDirectory: true)

    private func save(_ image: UIImage?, _ name: String) throws {
        let data = try #require(image?.pngData(), "no image for \(name)")
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)

        let url = Self.outputDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url)
        print("snapshot: \(url.path)")
    }

    /// Renders a SwiftUI view through a real hosting window, which is required for the UIKit-backed list and form.
    private func render<V: View>(_ view: V, size: CGSize, scheme: ColorScheme, type: DynamicTypeSize) -> UIImage? {
        let host = UIHostingController(rootView:
            view
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, type)
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()

        host.view.frame = window.bounds
        host.view.backgroundColor = .systemBackground
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: host.view.bounds)
        let image = renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }

        window.isHidden = true
        return image
    }

    private func image(of view: UIView) -> UIImage {
        // The editor turns off the autoresizing translation, so it needs an explicit frame in the test window.
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let window = UIWindow(frame: view.bounds)
        window.addSubview(view)
        view.frame = window.bounds
        window.makeKeyAndVisible()
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }

    @Test("Settings renders in light, dark and with large type")
    func settingsPage() throws {
        let size = CGSize(width: 393, height: 1_000)

        try save(render(SettingsView().environment(Store()), size: size, scheme: .light, type: .large), "settings-light")
        try save(render(SettingsView().environment(Store()), size: size, scheme: .dark, type: .large), "settings-dark")
        try save(render(SettingsView().environment(Store()), size: size, scheme: .light, type: .accessibility3), "settings-ax")
    }

    @Test("Note rows render in a native list")
    func noteList() throws {
        let size = CGSize(width: 393, height: 640)

        let list = List(rows) { row in
            NoteRowView(title: row.title,
                        snippet: row.snippet,
                        modified: Date.now.addingTimeInterval(-row.age).timeIntervalSince1970,
                        favorite: row.favorite)
        }
        .listStyle(.insetGrouped)

        try save(render(list, size: size, scheme: .light, type: .large), "list-light")
        try save(render(list, size: size, scheme: .dark, type: .large), "list-dark")
        try save(render(list, size: size, scheme: .light, type: .accessibility3), "list-ax")
    }

    @Test("The editor renders formatted text and the Markdown source")
    func editorModes() throws {
        let view = HeaderTextView(frame: CGRect(x: 0, y: 0, width: 393, height: 560))
        view.text = editorText
        view.backgroundColor = .systemBackground

        try save(image(of: view), "editor-reading")

        // The same text, with the Markdown characters visible.
        view.setShowsMarkdownSource(true)
        try save(image(of: view), "editor-source")

        // And back, to prove the switch does not change the text.
        view.setShowsMarkdownSource(false)
        try save(image(of: view), "editor-reading-again")

        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .systemBackground
        try save(image(of: view), "editor-reading-dark")

        #expect(view.text == editorText, "Switching the mode must not change the note")
    }
}
