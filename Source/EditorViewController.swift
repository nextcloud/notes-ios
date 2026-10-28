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

    private var observers = [NSObjectProtocol]()
    private let throttler = Throttler(minimumDelay: 0.5)

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
        view.addSubview(noteView)
        noteView.translatesAutoresizingMaskIntoConstraints = false
        noteView.delegate = self
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
            // Closing a new note without writing anything discards it.
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
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPreview" {
            if let preview = segue.destination as? PreviewViewController, let note = note {
                preview.content = noteView.text
                preview.noteTitle = note.title
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
        }) { (_) in
            imageView.removeFromSuperview()
            self.view.layer.setNeedsDisplay()
            self.view.layer.displayIfNeeded()
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
    
    @IBAction func onDone(_ sender: Any?) {
        noteView.endEditing(true)
    }

    @IBAction func onDismiss(_ sender: Any) {
        dismiss(animated: true)
    }

    func keyboardWillShow(notification: Notification) {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.navigationItem.rightBarButtonItems = [
                doneButton,
                fixedSpace,
                redoButton,
                fixedSpace,
                undoButton
            ]
        }

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
            if isNewNote {
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

        throttler.throttle { [weak self] in
            self?.updateNoteContent()
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
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
            var allLines = fullText.components(separatedBy: .newlines)
            let precedingLines = precedingText.components(separatedBy: .newlines)
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
                for i in 0..<checkboxUncheckedMatch.numberOfRanges {
                    let startIndex = textView.text.index(textView.text.startIndex, offsetBy: checkboxUncheckedMatch.range(at: i).location)
                    let endIndex = textView.text.index(textView.text.startIndex, offsetBy: checkboxUncheckedMatch.range(at: i).location + checkboxUncheckedMatch.range(at: i).length)
                    print("Unchecked checkbox matched at \(checkboxUncheckedMatch.range(at: i)) chars '\(textView.text[startIndex..<endIndex])'")
                }

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

                for i in 0..<checkboxCheckedMatch.numberOfRanges {
                    let startIndex = textView.text.index(textView.text.startIndex, offsetBy: checkboxCheckedMatch.range(at: i).location)
                    let endIndex = textView.text.index(textView.text.startIndex, offsetBy: checkboxCheckedMatch.range(at: i).location + checkboxCheckedMatch.range(at: i).length)
                    print("Checked checkbox matched at \(checkboxCheckedMatch.range(at: i)) chars '\(textView.text[startIndex..<endIndex])'")
                }

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

                for i in 0..<unorderedMatch.numberOfRanges {
                    let startIndex = textView.text.index(textView.text.startIndex, offsetBy: unorderedMatch.range(at: i).location)
                    let endIndex = textView.text.index(textView.text.startIndex, offsetBy: unorderedMatch.range(at: i).location + unorderedMatch.range(at: i).length)
                    print("Unordered list matched at \(unorderedMatch.range(at: i)) chars '\(textView.text[startIndex..<endIndex])'")
                }

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

                for i in 0..<orderedMatch.numberOfRanges {
                    let startIndex = precedingLineString.index(precedingLineString.startIndex, offsetBy: orderedMatch.range(at: i).location)
                    let endIndex = precedingLineString.index(precedingLineString.startIndex, offsetBy: orderedMatch.range(at: i).location + orderedMatch.range(at: i).length)
                    print("Ordered list matched at \(orderedMatch.range(at: i)) chars '\(precedingLineString[startIndex..<endIndex])'")
                }
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
                                let updatedLine = line.replacingOccurrences(of: digitString, with: "\(digit + 1)")
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
                    var allLines = fullText.components(separatedBy: .newlines)
                    let precedingLines = precedingText.components(separatedBy: .newlines)
                    guard let precedingLineString = precedingLines.last else {
                        return true
                    }
                    let precedingLineNSString = precedingLineString as NSString
                    let precedingLineRange = NSMakeRange(0, precedingLineNSString.length)
                    let options = NSRegularExpression.MatchingOptions(rawValue: 0)
                    let precedingLineIndex = allLines.firstIndex(of: precedingLineString)
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

                        for i in 0..<orderedMatch.numberOfRanges {
                            let startIndex = precedingLineString.index(precedingLineString.startIndex, offsetBy: orderedMatch.range(at: i).location)
                            let endIndex = precedingLineString.index(precedingLineString.startIndex, offsetBy: orderedMatch.range(at: i).location + orderedMatch.range(at: i).length)
                            print("Ordered list matched at \(orderedMatch.range(at: i)) chars '\(precedingLineString[startIndex..<endIndex])'")
                        }
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
                                        let updatedLine = line.replacingOccurrences(of: digitString, with: "\(digit - 1)")
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
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        noteView.settleDate(targetContentOffset: targetContentOffset)
    }
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}
