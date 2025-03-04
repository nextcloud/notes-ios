//
//  EditorViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/19/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import PKHUD

class EditorViewController: UIViewController {

    @IBOutlet var activityButton: UIBarButtonItem!
    @IBOutlet var deleteButton: UIBarButtonItem!
    @IBOutlet var previewButton: UIBarButtonItem!
    @IBOutlet var undoButton: UIBarButtonItem!
    @IBOutlet var redoButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var dismissButton: UIBarButtonItem!
    @IBOutlet var fixedSpace: UIBarButtonItem!
    
    var updatedByEditing = false
    var noteExporter: NoteExporter?
    var bottomLayoutConstraint: NSLayoutConstraint?
    var isNewNote = false

    var note: CDNote? {
        didSet {
            if note != oldValue, let note = note {
                HUD.show(.progress)
                if note.addNeeded {
                    noteView.text = note.content
                    noteView.undoManager?.removeAllActions()
                    noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                    updateHeaderLabel()
                    HUD.hide()
                } else {
                    NoteSessionManager.shared.get(note: note, completion: { [weak self] in
                        self?.noteView.text = note.content
                        self?.noteView.undoManager?.removeAllActions()
                        self?.noteView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                        self?.updateHeaderLabel()
                        HUD.hide()
                    })
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

        navigationItem.rightBarButtonItems = [
            fixedSpace,
            dismissButton,
            fixedSpace,
            activityButton,
            fixedSpace,
            deleteButton,
            fixedSpace,
            previewButton,
        ]

        navigationItem.leftItemsSupplementBackButton = true

        if let note = note {
            noteView.text = note.content;
            noteView.isEditable = true
            noteView.isSelectable = true
            activityButton.isEnabled = !noteView.text.isEmpty
            previewButton.isEnabled = !noteView.text.isEmpty
            deleteButton.isEnabled = true
        } else {
            noteView.isEditable = false
            noteView.isSelectable = false
            noteView.text = ""
            noteView.headerLabel.text = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
            navigationItem.title = ""
            activityButton.isEnabled = false
            deleteButton.isEnabled = false
            previewButton.isEnabled = false
        }
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.delegate = self
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        if let splitVC = splitViewController as? PBHSplitViewController {
            splitVC.editorViewController = self
        }
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
    
    fileprivate func updateHeaderLabel() {
        if let note = note, let date = Date(timeIntervalSince1970: note.modified) as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = false
            noteView.headerLabel.text = formatter.string(from: date)
            noteView.headerLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
            navigationItem.title = note.title
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeaderLabel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //        //TODO: This works around a Swift/Objective-C interaction issue. Verify that it is still needed.
        self.noteView.isScrollEnabled = false
        self.noteView.isScrollEnabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.updateNoteContent()
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
                preview.noteDate = noteView.headerLabel.text
            }
        }
    }
    
    // MARK: - Actions

    @IBAction func onActivities(_ sender: Any?) {
        var textToExport: String?
        if let selectedRange = noteView.selectedTextRange, let selectedText = noteView.text(in: selectedRange), !selectedText.isEmpty  {
            textToExport = selectedText
        } else {
            textToExport = noteView.text
        }
        if let text = textToExport {
            noteExporter = NoteExporter(title: note?.title ?? "Untitled", text: text, viewController: self, from: activityButton)
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
        NotificationCenter.default.post(name: .deletingNote, object: self)
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
    
    @IBAction func onDelete(_ sender: Any?) {
        if let popover = deleteAlertController.popoverPresentationController {
            popover.barButtonItem = deleteButton
        }
        present(deleteAlertController, animated: true, completion: nil)
    }

    @IBAction func onPreview(_ sender: Any?) {
        performSegue(withIdentifier: "showPreview", sender: sender)
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
            self.navigationItem.rightBarButtonItems = [
                dismissButton,
                fixedSpace,
                activityButton,
                fixedSpace,
                deleteButton,
                fixedSpace,
                previewButton
            ]
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
        self.noteView.headerLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }
}

extension EditorViewController: UITextViewDelegate {
    
    fileprivate func updateNoteContent() {
        if let note = self.note, let text = self.noteView.text, text != note.content {
            note.content = text
            if isNewNote {
                note.title = noteTitle(note)
            }
            NoteSessionManager.shared.update(note: note, completion: { [weak self] in
                self?.updateHeaderLabel()
            })
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        self.activityButton.isEnabled = !textView.text.isEmpty
        self.previewButton.isEnabled = !textView.text.isEmpty
        self.deleteButton.isEnabled = true
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
}

extension EditorViewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController == self {
            if self.traitCollection.userInterfaceIdiom == .phone, let note = self.note, note.id == 0 {
                self.view.bringSubviewToFront(self.noteView)
                self.noteView.becomeFirstResponder()
            }
        }
    }
    
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}
