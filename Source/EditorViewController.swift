// SPDX-FileCopyrightText: 2019 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import PKHUD

class EditorViewController: UIViewController {

    @IBOutlet var undoButton: UIBarButtonItem!
    @IBOutlet var redoButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var dismissButton: UIBarButtonItem!
    @IBOutlet var fixedSpace: UIBarButtonItem!

    /// Preview, share and delete; rebuilt on every open so the disabled states follow the text.
    private lazy var moreButton: UIBarButtonItem = {
        let menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.moreMenuElements() ?? [])
            }
        ])

        let button = UIBarButtonItem(title: NSLocalizedString("More", comment: "Accessibility label of the button with more note actions"), image: UIImage(systemName: "ellipsis"), primaryAction: nil, menu: menu)
        button.tintColor = .ph_iconColor

        return button
    }()

    var updatedByEditing = false
    var noteExporter: NoteExporter?
    var bottomLayoutConstraint: NSLayoutConstraint?
    var isNewNote = false

    /// The note's own date only moves after a successful sync, so local edits are tracked here.
    private var editedDate: Date?

    private var hasFocusedNewNote = false

    private var isApplyingFormatting = false

    var note: Note? {
        didSet {
            if note != oldValue, let note = note {
                if note.addNeeded {
                    noteView.text = note.content
                    noteView.undoManager?.removeAllActions()
                    noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                    updateTitleAndDate()
                    applyReadOnlyState()
                } else {
                    HUD.show(.progress)

                    Task { [weak self] in
                        await NoteSessionManager.shared.get(note: note)

                        self?.noteView.text = note.content
                        self?.noteView.undoManager?.removeAllActions()
                        self?.noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                        self?.updateTitleAndDate()
                        self?.applyReadOnlyState()
                        HUD.hide()
                    }
                }
            }
        }
    }

    var noteView = HeaderTextView(frame: .zero)

    private lazy var undoFormattingButton = actionButton("arrow.uturn.backward", NSLocalizedString("Undo", comment: "Formatting bar button")) { [weak self] in
        self?.onUndo(nil)
    }

    private lazy var redoFormattingButton = actionButton("arrow.uturn.forward", NSLocalizedString("Redo", comment: "Formatting bar button")) { [weak self] in
        self?.onRedo(nil)
    }

    private var activeFormatChecks = [(button: UIButton, isActive: (FormattingState) -> Bool)]()

    /// The entries of Nextcloud Text's menu bar that map to Markdown, in its groups and order.
    private lazy var formattingBar: FormattingBar = {
        let format = { [weak self] (symbol: String, label: String, isActive: ((FormattingState) -> Bool)?, edit: @escaping (String, NSRange) -> MarkdownFormatter.Edit) -> UIButton in
            let button = FormattingBar.button(symbol, label)
            button.addAction(UIAction { _ in self?.applyFormatting(edit) }, for: .primaryActionTriggered)

            if let isActive {
                self?.activeFormatChecks.append((button, isActive))
            }

            return button
        }

        let headings = FormattingBar.menuButton("textformat.size", NSLocalizedString("Headings", comment: "Formatting bar button")) { [weak self] in
            let current = self?.formattingState.line.heading

            return (1...6).map { level in
                UIAction(title: String.localizedStringWithFormat(NSLocalizedString("Heading %d", comment: "Formatting menu entry"), level), state: current == level ? .on : .off) { _ in
                    self?.applyFormatting { MarkdownFormatter.toggleHeading(level, in: $0, selection: $1) }
                }
            }
        }
        activeFormatChecks.append((headings, { $0.line.heading != nil }))

        let blocks = FormattingBar.menuButton("rectangle.stack", NSLocalizedString("Blocks", comment: "Formatting bar button")) { [weak self] in
            let wrap = { (title: String, symbol: String, open: String, close: String) in
                UIAction(title: title, image: UIImage(systemName: symbol)) { _ in
                    self?.applyFormatting { MarkdownFormatter.wrapLines(open: open, close: close, in: $0, selection: $1) }
                }
            }

            let quote = UIAction(title: NSLocalizedString("Blockquote", comment: "Formatting menu entry"), image: UIImage(systemName: "text.quote"), state: self?.formattingState.line.isQuote == true ? .on : .off) { _ in
                self?.applyFormatting(MarkdownFormatter.toggleQuote)
            }

            let inlineMath = UIAction(title: NSLocalizedString("Inline math", comment: "Formatting menu entry"), image: UIImage(systemName: "function")) { _ in
                self?.applyFormatting { MarkdownFormatter.toggleWrap("$", in: $0, selection: $1) }
            }

            let callouts = [
                ("info", NSLocalizedString("Info callout", comment: "Formatting menu entry"), "info.circle"),
                ("success", NSLocalizedString("Success callout", comment: "Formatting menu entry"), "checkmark.circle"),
                ("warn", NSLocalizedString("Warning callout", comment: "Formatting menu entry"), "exclamationmark.triangle"),
                ("error", NSLocalizedString("Danger callout", comment: "Formatting menu entry"), "xmark.octagon"),
                ("question", NSLocalizedString("Question callout", comment: "Formatting menu entry"), "questionmark.circle")
            ]

            return [
                UIMenu(options: .displayInline, children: [
                    quote,
                    wrap(NSLocalizedString("Code block", comment: "Formatting menu entry"), "chevron.left.forwardslash.chevron.right", "```", "```"),
                    wrap(NSLocalizedString("Mermaid diagram", comment: "Formatting menu entry"), "flowchart", "```mermaid", "```")
                ]),
                UIMenu(options: .displayInline, children: [
                    wrap(NSLocalizedString("Details", comment: "Formatting menu entry"), "chevron.down.square", "<details>\n<summary>" + NSLocalizedString("Details", comment: "Default summary of a new details block") + "</summary>", "</details>")
                ]),
                UIMenu(options: .displayInline, children: [
                    inlineMath,
                    wrap(NSLocalizedString("Block math", comment: "Formatting menu entry"), "x.squareroot", "$$", "$$")
                ]),
                UIMenu(options: .displayInline, children: callouts.map { type, title, symbol in
                    wrap(title, symbol, "::: \(type)", ":::")
                })
            ]
        }

        let link = actionButton("link", NSLocalizedString("Insert link", comment: "Formatting bar button")) { [weak self] in
            self?.insertLink()
        }

        return FormattingBar(groups: [
            [undoFormattingButton, redoFormattingButton],
            [
                headings,
                format("bold", NSLocalizedString("Bold", comment: "Formatting bar button"), { $0.isBold }, MarkdownFormatter.toggleBold),
                format("italic", NSLocalizedString("Italic", comment: "Formatting bar button"), { $0.isItalic }, MarkdownFormatter.toggleItalic),
                format("underline", NSLocalizedString("Underline", comment: "Formatting bar button"), { $0.isUnderlined }) { MarkdownFormatter.toggleWrap("__", in: $0, selection: $1) },
                format("strikethrough", NSLocalizedString("Strikethrough", comment: "Formatting bar button"), { $0.isStruckThrough }) { MarkdownFormatter.toggleWrap("~~", in: $0, selection: $1) },
                format("highlighter", NSLocalizedString("Highlight", comment: "Formatting bar button"), { $0.isHighlighted }) { MarkdownFormatter.toggleWrap("==", in: $0, selection: $1) }
            ],
            [
                format("list.bullet", NSLocalizedString("Unordered list", comment: "Formatting bar button"), { $0.line.list == .bullet }) { MarkdownFormatter.toggleLineStyle(.bullet, in: $0, selection: $1) },
                format("list.number", NSLocalizedString("Ordered list", comment: "Formatting bar button"), { $0.line.list == .ordered }) { MarkdownFormatter.toggleLineStyle(.ordered, in: $0, selection: $1) },
                format("checklist", NSLocalizedString("To-Do list", comment: "Formatting bar button"), { $0.line.list == .checkbox }) { MarkdownFormatter.toggleLineStyle(.checkbox, in: $0, selection: $1) },
                format("decrease.indent", NSLocalizedString("Decrease indentation", comment: "Formatting bar button"), nil, MarkdownFormatter.outdent),
                format("increase.indent", NSLocalizedString("Increase indentation", comment: "Formatting bar button"), nil, MarkdownFormatter.indent)
            ],
            [
                blocks,
                format("tablecells", NSLocalizedString("Table", comment: "Formatting bar button"), nil, MarkdownFormatter.insertTable),
                link
            ]
        ])
    }()

    private func actionButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> UIButton {
        let button = FormattingBar.button(symbol, label)
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }

    private var formattingState: FormattingState {
        let selection = noteView.selectedRange
        let storage = noteView.textStorage

        // A caret takes the format of the character before it, like typing does.
        let location = selection.length > 0 ? selection.location : selection.location - 1
        let attributes = location >= 0 && location < storage.length && (storage.string as NSString).character(at: location) != 0x0A
            ? storage.attributes(at: location, effectiveRange: nil)
            : [:]

        return FormattingState(line: MarkdownFormatter.lineState(in: noteView.text, selection: selection), attributes: attributes)
    }

    private func updateFormattingBar() {
        let state = formattingState

        for (button, isActive) in activeFormatChecks {
            button.isSelected = isActive(state)
        }

        undoFormattingButton.isEnabled = noteView.undoManager?.canUndo == true
        redoFormattingButton.isEnabled = noteView.undoManager?.canRedo == true
    }

    private var observers = [NSObjectProtocol]()
    private let throttler = Throttler(minimumDelay: 0.5)
    private lazy var backSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer = {
        let gestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleBackSwipe(_:)))
        gestureRecognizer.edges = .left
        gestureRecognizer.cancelsTouchesInView = false
        return gestureRecognizer
    }()

    var screenShot: UIImage {
        var capturedScreen: UIImage?
        UIGraphicsBeginImageContextWithOptions(self.noteView.frame.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            self.noteView.layer.render(in: context)
            capturedScreen = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
        return capturedScreen ?? UIImage()
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addGestureRecognizer(backSwipeGestureRecognizer)
        view.addSubview(noteView)
        noteView.translatesAutoresizingMaskIntoConstraints = false
        noteView.delegate = self
        noteView.inputAccessoryView = formattingBar
        let bottomConstraint = noteView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        bottomLayoutConstraint = bottomConstraint
        self.view.backgroundColor = .ph_cellBackgroundColor
        NSLayoutConstraint.activate([
            noteView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            noteView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            noteView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint,
        ])

        navigationItem.leftBarButtonItem = dismissButton
        navigationItem.rightBarButtonItem = moreButton

        navigationItem.leftItemsSupplementBackButton = true

        if let note = note {
            noteView.text = note.content;
            noteView.isSelectable = true
            applyReadOnlyState()
        } else {
            noteView.isEditable = false
            noteView.isSelectable = false
            noteView.text = ""
            navigationItem.title = ""
        }
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        updatedByEditing = false
        for name in [Notification.Name.NSUndoManagerCheckpoint, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            self.observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: OperationQueue.main) { [weak self] notification in
                guard let self, notification.object as? UndoManager === noteView.undoManager else { return }

                updateFormattingBar()
            })
        }
        self.observers.append(NotificationCenter.default.addObserver(forName: UIWindow.keyboardWillShowNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
            self?.keyboardWillShow(notification: notification)
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIWindow.keyboardWillHideNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
            self?.keyboardWillHide(notification: notification)
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            self?.preferredContentSizeChanged()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            guard let self = self else { return }
            self.noteView.isScrollEnabled = false
            self.noteView.isScrollEnabled = true
            if self.noteView.selectedRange.location != 0 {
                self.noteView.scrollRangeToVisible(self.noteView.selectedRange)
            }

        }))

        if let transitionCoordinator = transitionCoordinator {
            viewWillTransition(to: UIScreen.main.bounds.size, with: transitionCoordinator)
        }
    }
    
    private func updateTitleAndDate() {
        guard let note else { return }

        let modified = Date(timeIntervalSince1970: note.modified)
        noteView.dateLabel.text = max(modified, editedDate ?? modified).formatted(date: .abbreviated, time: .omitted)
        navigationItem.title = note.title
    }

    /// Read-only notes, e.g. shared without edit permission, can be read but neither changed nor deleted.
    private func applyReadOnlyState() {
        guard let note else { return }

        noteView.isEditable = !note.readOnly
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTitleAndDate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //        //TODO: This works around a Swift/Objective-C interaction issue. Verify that it is still needed.
        self.noteView.isScrollEnabled = false
        self.noteView.isScrollEnabled = true

        if isNewNote, !hasFocusedNewNote, traitCollection.userInterfaceIdiom == .phone {
            hasFocusedNewNote = true
            noteView.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let note, isNewNote, navigationController?.isBeingDismissed == true,
           noteView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.note = nil

            Task {
                await NoteSessionManager.shared.delete(note: note)
            }
        } else {
            self.updateNoteContent()
        }

        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if traitCollection.horizontalSizeClass == .regular,
           traitCollection.userInterfaceIdiom == .pad {
            if splitViewController?.displayMode == .allVisible {
                noteView.updateInsets(size: 50)
            } else {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    noteView.updateInsets(size: 178)
                } else {
                    noteView.updateInsets(size: 50)
                }
            }
        }
    }

    @objc private func handleBackSwipe(_ gestureRecognizer: UIScreenEdgePanGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }

        let translation = gestureRecognizer.translation(in: view)
        let velocity = gestureRecognizer.velocity(in: view)
        guard translation.x > view.bounds.width * 0.15, velocity.x > 0 else { return }

        if let navigationController = navigationController,
           navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        } else if navigationController?.presentingViewController != nil {
            dismiss(animated: true)
        } else {
            splitViewController?.show(.primary)
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPreview" {
            if let preview = segue.destination as? PreviewViewController, let note = note {
                preview.content = noteView.text
                preview.noteTitle = note.title
                // A checkbox may only be ticked when the note can be written back.
                preview.allowsCheckBoxToggling = !note.readOnly
                preview.onContentChanged = { [weak self] content in
                    guard let self else { return }

                    self.noteView.text = content
                    // Ticking several checkboxes in a row turns into a single upload.
                    self.throttler.throttle {
                        self.updateNoteContent()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions

    private func moreMenuElements() -> [UIMenuElement] {
        let textAttributes: UIMenuElement.Attributes = noteView.text.isEmpty ? .disabled : []

        let previewAction = UIAction(title: NSLocalizedString("Preview", comment: "Action to preview a note"), image: UIImage(systemName: "text.page.badge.magnifyingglass"), attributes: textAttributes) { [weak self] _ in
            self?.performSegue(withIdentifier: "showPreview", sender: nil)
        }

        let shareAction = UIAction(title: NSLocalizedString("Share", comment: "Action to share a note"), image: UIImage(systemName: "square.and.arrow.up"), attributes: textAttributes) { [weak self] _ in
            self?.share()
        }

        let deleteAction = UIAction(title: NSLocalizedString("Delete", comment: "Action to delete a note"), image: UIImage(systemName: "trash"), attributes: note == nil || note?.readOnly == true ? [.destructive, .disabled] : .destructive) { [weak self] _ in
            self?.confirmDelete()
        }

        return [previewAction, shareAction, UIMenu(options: .displayInline, children: [deleteAction])]
    }

    private func share() {
        var textToExport: String?
        if let selectedRange = noteView.selectedTextRange, let selectedText = noteView.text(in: selectedRange), !selectedText.isEmpty  {
            textToExport = selectedText
        } else {
            textToExport = noteView.text
        }
        if let text = textToExport {
            noteExporter = NoteExporter(title: note?.title ?? "Untitled", text: text, viewController: self, from: moreButton)
            noteExporter?.showMenu()
        }
    }
    
    lazy var deleteAlertController: UIAlertController = {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete Note", comment: "A menu action"),
                                         style: .destructive,
                                         handler: { [weak self] action in
            self?.deleteNote(action)
        })
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "A menu action"), style: .cancel, handler: { _ in
            //
        })
        controller.addAction(deleteAction)
        controller.addAction(cancelAction)
        controller.modalPresentationStyle = .popover
        return controller
    }()
    
    func deleteNote(_ sender: Any?) {
        guard let noteToDelete = note else { return }

        // The editor no longer writes anything back while it closes; the note is about to be deleted.
        note = nil

        let imageView = UIImageView(frame: self.noteView.frame)
        imageView.image = self.screenShot
        self.noteView.addSubview(imageView)
        UIView.animate(withDuration: 0.3,
                       delay: 0.0,
                       options: [.curveEaseInOut, .allowUserInteraction],
                       animations: { [weak self] in
            let targetFrame = CGRect(x: self?.noteView.frame.size.width ?? 100 / 2, y: self?.noteView.frame.size.height ?? 100 / 2, width: 0, height: 0)
            imageView.frame = targetFrame
            imageView.alpha = 0.0
        }) { [weak self] (_) in
            imageView.removeFromSuperview()
            self?.view.layer.setNeedsDisplay()
            self?.view.layer.displayIfNeeded()

            // Confirming the deletion used to only play this animation, so the note stayed where it was.
            Task { @MainActor in
                await NoteSessionManager.shared.delete(note: noteToDelete)
                self?.navigationController?.dismiss(animated: true) ?? self?.dismiss(animated: true)
            }
        }
    }
    
    private func confirmDelete() {
        if let popover = deleteAlertController.popoverPresentationController {
            popover.barButtonItem = moreButton
        }
        present(deleteAlertController, animated: true, completion: nil)
    }

    @IBAction func onUndo(_ sender: Any?) {
        if let _ = noteView.undoManager?.canUndo {
            noteView.undoManager?.undo()
        }
    }
    
    @IBAction func onRedo(_ sender: Any?) {
        if let _ = noteView.undoManager?.canRedo {
            noteView.undoManager?.redo()
        }
    }
    
    private func insertLink() {
        let alert = UIAlertController(title: NSLocalizedString("Insert link", comment: "Title of the alert asking for a link"), message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "A menu action"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Insert", comment: "Inserts the link"), style: .default) { [weak self, weak alert] _ in
            guard let url = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !url.isEmpty else { return }

            self?.applyFormatting { MarkdownFormatter.insertLink(url, in: $0, selection: $1) }
            self?.noteView.becomeFirstResponder()
        })

        present(alert, animated: true)
    }

    /// Goes through the text input system so the edit can be undone like typing.
    private func applyFormatting(_ format: (String, NSRange) -> MarkdownFormatter.Edit) {
        guard noteView.isEditable else { return }

        let edit = format(noteView.text, noteView.selectedRange)

        guard let start = noteView.position(from: noteView.beginningOfDocument, offset: edit.range.location),
              let end = noteView.position(from: start, offset: edit.range.length),
              let range = noteView.textRange(from: start, to: end) else {
            return
        }

        // The list handling for typed returns and backspaces must not rewrite the edit.
        isApplyingFormatting = true
        noteView.replace(range, withText: edit.replacement)
        isApplyingFormatting = false

        noteView.selectedRange = edit.selection
        textViewDidChange(noteView)
    }

    @IBAction func onDone(_ sender: Any?) {
        noteView.endEditing(true)
    }

    @IBAction func onDismiss(_ sender: Any) {
        dismiss(animated: true)
    }

    func keyboardWillShow(notification: Notification) {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.navigationItem.rightBarButtonItem = doneButton
        }
        updateFormattingBar()

        if let info = notification.userInfo,
           let rect: CGRect = info[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect,
           let ar = self.view?.convert(rect, from: nil),
           let animationDuration: TimeInterval = info[UIWindow.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
            let kbHeight = ar.size.height
            var textInsets = self.noteView.textContainerInset
            textInsets.bottom = kbHeight
            self.bottomLayoutConstraint?.isActive = false
            self.bottomLayoutConstraint = noteView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -kbHeight)
            self.bottomLayoutConstraint?.isActive = true
            self.updatedByEditing = true
            UIView.animate(withDuration: animationDuration) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }

    func keyboardWillHide(notification: Notification) {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.navigationItem.rightBarButtonItem = moreButton
        }

        if let info = notification.userInfo,
           let animationDuration: TimeInterval = info[UIWindow.keyboardAnimationDurationUserInfoKey] as? TimeInterval {

            self.bottomLayoutConstraint?.isActive = false
            self.bottomLayoutConstraint = noteView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            self.bottomLayoutConstraint?.isActive = true
            self.updateViewConstraints()
            self.updatedByEditing = false
            UIView.animate(withDuration: animationDuration) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }

    func preferredContentSizeChanged() {
        self.noteView.font = UIFont.preferredFont(forTextStyle: .body)
    }
}

extension EditorViewController: UITextViewDelegate {
    
    fileprivate func updateNoteContent() {
        if let note = self.note, !note.readOnly, let text = self.noteView.text, text != note.content {
            note.content = text
            // Only a note being created takes its title from the first line, and only when the user wants that:
            // renaming a note that exists everywhere else surprises the people who share Markdown files (#58).
            if isNewNote, Store.shared.useFirstLineAsTitle {
                note.title = noteTitle(note)
            }
            Task { [weak self] in
                await NoteSessionManager.shared.update(note: note)

                self?.updateTitleAndDate()
            }
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        editedDate = Date()
        updateTitleAndDate()
        updateFormattingBar()

        throttler.throttle { [weak self] in
            self?.updateNoteContent()
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard !isApplyingFormatting else { return true }

        let textRect = textView.layoutManager.usedRect(for: textView.textContainer)
        let sizeAdjustment = textView.font?.lineHeight ?? 0.0 * UIScreen.main.scale

        if textRect.size.height >= textView.frame.size.height - textView.contentInset.bottom - sizeAdjustment {
            if text == "\n" {
                UIView.animate(withDuration: 0.2) {
                    textView.setContentOffset(CGPoint(x: textView.contentOffset.x, y: textView.contentOffset.y + sizeAdjustment), animated: true)
                }
            }
        }

        let fullText = textView.text as NSString
        if text.first == Character("\n") {
            let precedingText = fullText.substring(to: range.upperBound)
            var allLines = fullText.components(separatedBy: "\n")
            let precedingLines = precedingText.components(separatedBy: "\n")
            guard let precedingLineString = precedingLines.last else {
                return true
            }
            let precedingLineNSString = precedingLineString as NSString
            let precedingLineRange = NSMakeRange(0, precedingLineNSString.length)
            let options = NSRegularExpression.MatchingOptions(rawValue: 0)
            var lineRemainder = ""
            let precedingLineIndex = allLines.firstIndex { line in
                if line.hasPrefix(precedingLineString) {
                    let distance = precedingLineString.distance(from: precedingLineString.startIndex, to: precedingLineString.endIndex)
                    let indexSuffix = line.count - distance
                    lineRemainder = String(line.suffix(indexSuffix))
                    return true
                }
                return false
            }
            var remainingLines = Array<String>.SubSequence()
            if let precedingIndex = precedingLineIndex {
                remainingLines = allLines.dropFirst(precedingIndex + 1)
                print("Preceding line index \(precedingLineIndex ?? -1)")
            }

            guard let checkboxUncheckedRegex = try? NSRegularExpression(pattern: Element.checkBoxUnchecked.rawValue, options: .anchorsMatchLines) else {
                return true
            }

            if let checkboxUncheckedMatch = checkboxUncheckedRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {

                let checkboxRange = checkboxUncheckedMatch.range(at: 0)
                if checkboxRange.location != NSNotFound {
                    let checkboxString = precedingLineNSString.substring(with: checkboxRange)
                    let newText = "\(text)\(checkboxString) "
                    let newFullText = fullText.replacingCharacters(in: range, with: newText)

                    textView.text = newFullText

                    let estimatedCursor = NSMakeRange(range.location + newText.count, 0)
                    textView.selectedRange = estimatedCursor

                    return false
                }
            }

            guard let checkboxCheckedRegex = try? NSRegularExpression(pattern: Element.checkBoxChecked.rawValue, options: .anchorsMatchLines) else {
                return true
            }

            if let checkboxCheckedMatch = checkboxCheckedRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {


                let checkboxRange = checkboxCheckedMatch.range(at: 0)
                if checkboxRange.location != NSNotFound {
                    let checkboxString = precedingLineNSString.substring(with: checkboxRange).replacingOccurrences(of: "X", with: " ").replacingOccurrences(of: "x", with: " ")
                    let newText = "\(text)\(checkboxString) "
                    let newFullText = fullText.replacingCharacters(in: range, with: newText)

                    textView.text = newFullText

                    let estimatedCursor = NSMakeRange(range.location + newText.count, 0)
                    textView.selectedRange = estimatedCursor

                    return false
                }
            }

            guard let listItemUnorderedRegex = try? NSRegularExpression(pattern: Element.listItemUnordered.rawValue, options: .anchorsMatchLines) else {
                return true
            }

            if let unorderedMatch = listItemUnorderedRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {


                let bulletRange = NSRange(location: unorderedMatch.range(at: 0).location, length: unorderedMatch.range(at: 0).length - unorderedMatch.range(at: 3).length - 1)
                if bulletRange.location != NSNotFound {
                    let bulletString = precedingLineNSString.substring(with: bulletRange)
                    let newText = "\(text)\(bulletString) "
                    let newFullText = fullText.replacingCharacters(in: range, with: newText)

                    textView.text = newFullText

                    let estimatedCursor = NSMakeRange(range.location + newText.count, 0)
                    textView.selectedRange = estimatedCursor

                    return false
                }
            }

            guard let listItemOrderedRegex = try? NSRegularExpression(pattern: Element.listItemOrdered.rawValue, options: .anchorsMatchLines) else {
                return true
            }

            if let orderedMatch = listItemOrderedRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {

                let startIndex = precedingLineString.index(precedingLineString.startIndex, offsetBy: orderedMatch.range(at: 2).location)
                let endIndex = precedingLineString.firstIndex(of: ".")

                let digitString = precedingLineString[startIndex..<endIndex!]
                print(digitString)

                if let digit = Int(digitString), let index = precedingLineIndex {
                    print("Value: \(digit)")
                    allLines[index] = precedingLineString
                    let newLine = "\(precedingLineString[precedingLineString.startIndex..<startIndex])\(digit + 1). \(lineRemainder)"

                    var updatedLines = [String]()
                    for line in remainingLines {
                        let lineNSString = line as NSString
                        let lineRange = NSMakeRange(0, lineNSString.length)
                        if let matches = listItemOrderedRegex.matches(in: line, options: options, range: lineRange).first {
                            let startIndex = line.index(line.startIndex, offsetBy: matches.range(at: 2).location)
                            let endIndex = line.firstIndex(of: ".")

                            let digitString = line[startIndex..<endIndex!]

                            if let digit = Int(digitString) {
                                let updatedLine = line.replacingCharacters(in: startIndex..<endIndex!, with: "\(digit + 1)")
                                print("Updated line: \(updatedLine)")
                                updatedLines.append(updatedLine)
                            } else {
                                break
                            }
                        } else {
                            break
                        }
                        if !updatedLines.isEmpty {
                            let shiftedIndex = index + 1
                            allLines.replaceSubrange(shiftedIndex..<shiftedIndex + updatedLines.count, with: updatedLines)
                        }
                    }
                    allLines.insert(newLine, at: index + 1)
                    textView.text = allLines.joined(separator: "\n")
                    let estimatedCursor = NSMakeRange(range.location + newLine.count + 1, 0)
                    textView.selectedRange = estimatedCursor
                }

                return false
            }
            guard let emptyLineRegex = try? NSRegularExpression(pattern: "^((\\d+\\.)|[-+*])\\s+$", options: .anchorsMatchLines) else {
                return true
            }

            if let _ = emptyLineRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {
                let updatingRange = (precedingText as NSString).range(of: precedingLineString, options: .backwards)

                let newFullText = fullText.replacingCharacters(in: updatingRange, with: "")
                textView.text = newFullText

                let estimatedCursor = NSMakeRange(updatingRange.location, 0)
                textView.selectedRange = estimatedCursor

                return false
            }
        } else if text.isEmpty {
            if (range.upperBound > range.lowerBound) {
                print("Backspace pressed")
                if fullText.character(at: range.lowerBound) == 10 {
                    print("Moved to previous line")
                    let currentCursor = textView.selectedRange.location

                    let precedingText = fullText.substring(to: range.upperBound - 1)
                    var allLines = fullText.components(separatedBy: "\n")
                    let precedingLines = precedingText.components(separatedBy: "\n")
                    guard let precedingLineString = precedingLines.last else {
                        return true
                    }
                    let precedingLineNSString = precedingLineString as NSString
                    let precedingLineRange = NSMakeRange(0, precedingLineNSString.length)
                    let options = NSRegularExpression.MatchingOptions(rawValue: 0)
                    // The line the cursor is on follows the preceding line. Only remove it when it is empty,
                    // otherwise let UIKit join the two lines so no text is lost.
                    let precedingLineIndex: Int? = precedingLines.count - 1
                    guard let currentLineIndex = precedingLineIndex.map({ $0 + 1 }),
                          allLines.indices.contains(currentLineIndex),
                          allLines[currentLineIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return true
                    }
                    var remainingLines = Array<String>.SubSequence()
                    if let precedingIndex = precedingLineIndex {
                        allLines.remove(at: precedingIndex + 1)
                        remainingLines = allLines.dropFirst(precedingIndex + 1)
                        print("Preceding line index \(precedingLineIndex ?? -1)")
                    }
                    guard let listItemOrderedRegex = try? NSRegularExpression(pattern: Element.listItemOrdered.rawValue, options: .anchorsMatchLines) else {
                        return true
                    }
                    print("Current line: \(precedingLineString)")
                    if let orderedMatch = listItemOrderedRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {

                        let startIndex = precedingLineString.index(precedingLineString.startIndex, offsetBy: orderedMatch.range(at: 2).location)
                        let endIndex = precedingLineString.firstIndex(of: ".")

                        let digitString = precedingLineString[startIndex..<endIndex!]

                        if let digit = Int(digitString), let index = precedingLineIndex {
                            print("Value: \(digit)")
                            var updatedLines = [String]()
                            for line in remainingLines {
                                let lineNSString = line as NSString
                                let lineRange = NSMakeRange(0, lineNSString.length)
                                if let matches = listItemOrderedRegex.matches(in: line, options: options, range: lineRange).first {
                                    let startIndex = line.index(line.startIndex, offsetBy: matches.range(at: 2).location)
                                    let endIndex = line.firstIndex(of: ".")

                                    let digitString = line[startIndex..<endIndex!]

                                    if let digit = Int(digitString) {
                                        let updatedLine = line.replacingCharacters(in: startIndex..<endIndex!, with: "\(digit - 1)")
                                        print("Updated line: \(updatedLine)")
                                        updatedLines.append(updatedLine)
                                    } else {
                                        break
                                    }
                                } else {
                                    break
                                }
                            }
                            if !updatedLines.isEmpty {
                                let shiftedIndex = index + 1
                                allLines.replaceSubrange(shiftedIndex..<shiftedIndex + updatedLines.count, with: updatedLines)
                            }
                            textView.text = allLines.joined(separator: "\n")
                            let estimatedCursor = NSMakeRange(currentCursor - 1, 0)
                            textView.selectedRange = estimatedCursor
                        }

                        return false
                    }
                }
            } else if (range.upperBound == range.lowerBound) {
                print("Backspace pressed but no text to delete")
                if (textView.text.isEmpty) || (textView.text == nil) {
                    print("Text view is empty")
                }
            }
        }

        return true
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        textView.scrollRangeToVisible(textView.selectedRange)
        updateFormattingBar()
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        noteView.settleDate(targetContentOffset: targetContentOffset)
    }
}

/// What the formatting bar shows as active, read from the line's Markdown and the styling at the cursor.
private struct FormattingState {
    let line: MarkdownFormatter.LineState
    let attributes: [NSAttributedString.Key: Any]

    // Headings are bold as a whole, which says nothing about bold text in them.
    var isBold: Bool { line.heading == nil && traits.contains(.traitBold) }

    var isItalic: Bool { traits.contains(.traitItalic) }

    // Links are underlined too.
    var isUnderlined: Bool { attributes[.underlineStyle] != nil && attributes[.foregroundColor] as? UIColor != .systemBlue }

    // Checked to-dos are struck through too.
    var isStruckThrough: Bool { attributes[.strikethroughStyle] != nil && line.list != .checkbox }

    var isHighlighted: Bool { attributes[.highlight] != nil }

    private var traits: UIFontDescriptor.SymbolicTraits {
        (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
    }
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}
