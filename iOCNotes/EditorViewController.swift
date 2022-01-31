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
    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet var previewButton: UIBarButtonItem!
    @IBOutlet var undoButton: UIBarButtonItem!
    @IBOutlet var redoButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
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
        navigationItem.rightBarButtonItems = [addButton, fixedSpace, activityButton, fixedSpace, deleteButton, fixedSpace, previewButton]
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 14.0, *) {
            //
        } else {
            navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        }
        navigationItem.leftItemsSupplementBackButton = true
        #endif
        if let note = note {
            noteView.text = note.content;
            noteView.isEditable = true
            noteView.isSelectable = true
            activityButton.isEnabled = !noteView.text.isEmpty
            addButton.isEnabled = !noteView.text.isEmpty
            previewButton.isEnabled = !noteView.text.isEmpty
            deleteButton.isEnabled = true
            #if targetEnvironment(macCatalyst)
            (splitViewController as? PBHSplitViewController)?.buildMacToolbar()
            #endif
        } else {
            noteView.isEditable = false
            noteView.isSelectable = false
            noteView.text = ""
            noteView.headerLabel.text = NSLocalizedString("Select or create a note.", comment: "Placeholder text when no note is selected")
            navigationItem.title = ""
            activityButton.isEnabled = false
            addButton.isEnabled = true
            deleteButton.isEnabled = false
            previewButton.isEnabled = false
            #if targetEnvironment(macCatalyst)
            (splitViewController as? PBHSplitViewController)?.buildMacToolbar()
            #endif
        }
        #if targetEnvironment(macCatalyst)
        navigationController?.navigationBar.isHidden = true
        #else
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.delegate = self
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        #endif
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
    
    @IBAction func onAdd(_ sender: Any?) {
        NoteSessionManager.shared.add(content: "", category: "", favorite: false) { [weak self] note in
            self?.note = note
            self?.isNewNote = true
        }
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

    func keyboardWillShow(notification: Notification) {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.navigationItem.rightBarButtonItems = [self.doneButton, self.fixedSpace, self.redoButton, self.fixedSpace, self.undoButton]
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
            self.navigationItem.rightBarButtonItems = [self.addButton, self.fixedSpace, self.activityButton, self.fixedSpace, self.deleteButton, self.fixedSpace, self.previewButton];
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



/*
     - (void)noteAdded:(NSNotification*)notification {
     [self noteUpdated:notification];
     }

*/

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
        self.addButton.isEnabled = !textView.text.isEmpty
        self.previewButton.isEnabled = !textView.text.isEmpty
        self.deleteButton.isEnabled = true
        #if targetEnvironment(macCatalyst)
        (splitViewController as? PBHSplitViewController)?.buildMacToolbar()
        #endif
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

        //
        // When the user hits the return key, to initiate a new line, we will do some processing
        // to see if we are continuing a list of unordered or ordered bullet points.
        // As an extra requirement, if the user hits return on an empty bullet point, then we clear the bullet point.
        //

        if text.first == Character("\n") {

            let fullText = textView.text as NSString
            let precedingText = fullText.substring(to: range.upperBound)
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
                remainingLines = allLines.dropFirst(precedingIndex + 1)
                print("Preceding line index \(precedingLineIndex ?? -1)")
            }
            //
            // This code will check for the prescence of a filled bullet point on the preceding line,
            // in the format of `1. Bullet Point Text`, or `- A dashed bullet point`
            // If this is found, then the new line will automatically gain it's own indexed bullet point.
            //

            // Pattern: [Line Beginning] {([Numbers] [Full Stop]) or [Bullet Character: -+*]} [Single Space Character] [All Characters] [Line End]
            guard let checkboxUncheckedRegex = try? NSRegularExpression(pattern: Element.checkBoxUnchecked.rawValue, options: .anchorsMatchLines) else {
                return true
            }

            if let checkboxUncheckedMatch = checkboxUncheckedRegex.matches(in: precedingLineString, options: options, range: precedingLineRange).first {

                for i in 0..<checkboxUncheckedMatch.numberOfRanges {
                    let startIndex = textView.text.index(textView.text.startIndex, offsetBy: checkboxUncheckedMatch.range(at: i).location)
                    let endIndex = textView.text.index(textView.text.startIndex, offsetBy: checkboxUncheckedMatch.range(at: i).location + checkboxUncheckedMatch.range(at: i).length)
                    print("Unchecked checkbox matched at \(checkboxUncheckedMatch.range(at: i)) chars '\(textView.text[startIndex..<endIndex])'")
                }

                // Matched on an unordered bullet: "- Some Text"
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

                // Matched on an unordered bullet: "- Some Text"
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

                // Matched on an unordered bullet: "- Some Text"
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
                    let startIndex = textView.text.index(textView.text.startIndex, offsetBy: orderedMatch.range(at: i).location)
                    let endIndex = textView.text.index(textView.text.startIndex, offsetBy: orderedMatch.range(at: i).location + orderedMatch.range(at: i).length)
                    print("Ordered list matched at \(orderedMatch.range(at: i)) chars '\(textView.text[startIndex..<endIndex])'")
                }

                let digitPrefix = precedingLineString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(while: { $0.isASCII && $0.isNumber })
                if let digit = Int(digitPrefix), let index = precedingLineIndex {
                    print("Value: \(digit)")
                    let newLine = "\(digit + 1). "

                    var updatedLines = [String]()
                    for line in remainingLines {
                        let digitPrefix = line
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .prefix(while: { $0.isASCII && $0.isNumber })
                        if let digit = Int(digitPrefix) {
                            let updatedLine = line.replacingOccurrences(of: digitPrefix, with: "\(digit + 1)")
                            print("Updated line: \(updatedLine)")
                            updatedLines.append(updatedLine)
                        } else {
                            break
                        }
                    }
                    if !updatedLines.isEmpty {
                        let shiftedIndex = index + 1
                        allLines.replaceSubrange(shiftedIndex..<shiftedIndex + updatedLines.count, with: updatedLines)
                    }
                    allLines.insert(newLine, at: index + 1)


                    textView.text = allLines.joined(separator: "\n")
                }

                return false
                //
                // In this scenario we are checking if the user has hit return on an empty bullet point line such as
                // `1. `, `- `, or `+ `. If this is the case, the the user is signifying that they wish to insert a regular paragraph
                // and that the bullet point index should be removed.
                //

                // Matched on an ordered bullet: "1. Some Text"
//                let digitRange = orderedMatch.range(at: 2)
//                if digitRange.location != NSNotFound {
//                    let substring = precedingLineNSString.substring(with: digitRange)
//                    if let previousIndex = Int(substring.dropLast()) {
//                        let newIndex = previousIndex + 1
//                        let newText = "\(text)\(newIndex). "
//
//                        let newFullText = fullText.replacingCharacters(in: range, with: newText)
//
//                        textView.text = newFullText
//
//                        let estimatedCursor = NSMakeRange(range.location + newText.count, 0)
//                        textView.selectedRange = estimatedCursor
//
//                        return false
//                    }
//                }

                // goBackOneLine is a Boolean to indicate whether the cursor
                // should go back 1 line; set to YES in the case that the
                // user has deleted the number at the start of the line
                var goBackOneLine = false

                // Get a string representation of the current line number
                // in order to calculate cursor placement based on the
                // character count of the number
//                NSString *precedingText = [textView.text substringToIndex:range.location];
//                NSString *precedingLineNSString = [NSString stringWithFormat:@"%lu", [precedingText componentsSeparatedByString:@"\n"].count + 1];

                // If the replacement string either contains a new line
                // character or is a backspace, proceed with the following
                // block...
                if text.contains(Character("\n")) || range.length == 1 {

                    // Combine the new text with the old
                    var combinedText = fullText.replacingCharacters(in: range, with: text)

                    // Seperate the combinedText into lines
                    var lines = combinedText.components(separatedBy: "\n")

                    // To handle the backspace condition
                    if range.length == 1 {

                        // If the user deletes the number at the beginning of the line,
                        // also delete the newline character proceeding it
                        // Check to see if the user's deleting a number and
                        // if so, keep moving backwards digit by digit to see if the
                        // string's preceeded by a newline too.
                        let currentCharacter = fullText.character(at: range.location)
                        if Int(currentCharacter) >= 0 && Int(currentCharacter) <= 9 {

                            var index = 1
                            var c = currentCharacter
//                            while Int(c) >= 0 && Int(c) <= 9 {
//
//                                c = fullText.character(at: range.location - index)
//
//                                // If a newline is found directly preceding
//                                // the number, delete the number and move back
//                                // to the preceding line.
//                                if c == unichar("\n") {
//                                    combinedText = fullText.replacingCharacters(in: NSRange(location: range.location - index, length: range.length + index), with: text)
//
//                                    lines = combinedText.components(separatedBy: "\n")
//
//                                    // Set this variable so the cursor knows to back
//                                    // up one line
//                                    goBackOneLine = true
//
//                                    break
//                                }
//                                index ++
//                            }
                        }

                        // If the user attempts to delete the number 1
                        // on the first line...
                        if range.location == 1 {
                            if let firstRow = lines.first {

                                // If there's text left in the current row, don't
                                // remove the number 1
                                if firstRow.count > 3 {
                                    return false
                                }
                            }

                            // Else if there's no text left in text view other than
                            // the 1, don't let the user delete it
                            else if lines.count == 1 {
                                return false
                            }

                            // Else if there's no text in the first row, but there's text
                            // in the next, move the next row up
                            else if lines.count > 1 {
                               _ = lines.dropFirst()
                            }
                        }
                    }

                    // Using a loop, remove the numbers at the start of the lines
                    // and store the new strings in the linesWithoutLeadingNumbers array
                    var linesWithoutLeadingNumbers = [String]()

                    // Go through each line
                    for line in lines {

                        // Use the following string to make updates
                        var stringWithoutLeadingNumbers = line

                        // Go through each character
                        for index in line.indices {
                            if CharacterSet.decimalDigits.containsUnicodeScalars(of: line[index]) {
                                stringWithoutLeadingNumbers = String(stringWithoutLeadingNumbers.dropFirst())
                            } else {
                                break
                            }
                        }
                        linesWithoutLeadingNumbers.append(stringWithoutLeadingNumbers.trimmingCharacters(in: .whitespaces))
                    }

                    var linesWithUpdatedNumbers = [String]()

                    for (index, line2) in linesWithoutLeadingNumbers.enumerated() {
                        let updatedLine = ("\(index + 1) \(line2)")
                        linesWithUpdatedNumbers.append(updatedLine)
                    }

                    var combinedString = ""

                    for (index, line2) in linesWithUpdatedNumbers.enumerated() {
                        combinedString = combinedString.appending(line2)
                        if index < linesWithUpdatedNumbers.count - 1 {
                            combinedString = combinedString.appending("\n")
                        }
                    }

//                    // Set the cursor appropriately.
//                    NSRange cursor;
//                    if ([text isEqualToString:@"\n"]) {
//                       cursor = NSMakeRange(range.location + precedingLineNSString.length + 2, 0);
//                    } else if (goBackOneLine) {
//                        cursor = NSMakeRange(range.location - 1, 0);
//                    } else {
//                        cursor = NSMakeRange(range.location, 0);
//                    }
//
//                    textView.selectedRange = cursor;
//
//                    // And update the text view
                    textView.text = combinedString

                    return false
                }


        }
            guard let emptyLineRegex = try? NSRegularExpression(pattern: "^((\\d+.)|[-+*])\\s?$", options: .anchorsMatchLines) else {
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
