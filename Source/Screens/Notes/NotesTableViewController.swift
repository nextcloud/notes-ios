//
//  NotesTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import CoreData
import MobileCoreServices
import PKHUD
import SwiftMessages
import UIKit
import NextcloudKit
import SwiftyJSON
import Alamofire
import SwiftUI

let detailSegueIdentifier = "showDetail"
let categorySegueIdentifier = "SelectCategorySegue"
let directeditingSe6436gueIdentifier = "directEditing"

class NotesTableViewController: BaseUITableViewController {
    @IBOutlet var addBarButton: UIBarButtonItem!
    @IBOutlet weak var refreshBarButton: UIBarButtonItem!

    var notes: [CDNote]?
    var searchController: UISearchController?
    var editorViewController: EditorViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    private var networkHasBeenUnreachable = false
    private var searchResult: [CDNote]?
    private var launching = true

    private let notesManager = NotesManager()

    private var observers = [NSObjectProtocol]()
    private var noteToAddOnViewDidLoad: String?
    var isAddingFromButton = false

    private var contextMenuIndexPath: IndexPath?
    private var noteExporter: NoteExporter?

    private var dateFormat: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none;
        df.doesRelativeDateFormatting = true
        return df
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        clearsSelectionOnViewWillAppear = false

        self.observers.append(NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
            self?.tableView.reloadData()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            self?.didBecomeActive()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .offlineModeChanged,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .deletingNote,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            if let editor = self?.editorViewController,
               let note = editor.note,
               let currentIndexPath = self?.notesManager.manager.fetchedResultsController.indexPath(forObject: note), let tableView = self?.tableView {
                self?.tableView(tableView, commit: .delete, forRowAt: currentIndexPath)
            }
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .syncNotes,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            self?.onRefresh(sender: nil)
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .doneSelectingCategory,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            self?.tableView.reloadData()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .networkSuccess,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
            HUD.hide()
            self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
            self?.addBarButton.isEnabled = true
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .networkError,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
            HUD.hide()
            self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
            self?.addBarButton.isEnabled = true
            if let title = notification.userInfo?["Title"] as? String,
               let message = notification.userInfo?["Message"] as? String {
                var config = SwiftMessages.defaultConfig
                config.interactiveHide = true
                config.duration = .forever
                config.preferredStatusBarStyle = .default
                SwiftMessages.show(config: config, viewProvider: {
                    let view = MessageView.viewFromNib(layout: .cardView)
                    view.configureTheme(.error, iconStyle: .default)
                    view.configureDropShadow()
                    view.configureContent(title: title,
                                          body: message,
                                          iconImage: Icon.error.image,
                                          iconText: nil,
                                          buttonImage: nil,
                                          buttonTitle: nil,
                                          buttonTapHandler: nil
                    )
                    return view
                })
            }
        })
        )

        let nib = UINib(nibName: "CollapsibleTableViewHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderView")
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.searchBar.directionalLayoutMargins = .init(top: 0, leading: 15, bottom: 0, trailing: 15)
        notesManager.manager.delegate = self
        updateFrcDelegate(update: .enable(withFetch: true))
        tableView.tableHeaderView = searchController?.searchBar

        tableView.backgroundView = UIView()
        tableView.dropDelegate = self
        updateSectionExpandedInfo()
        if let noteToAddOnViewDidLoad = noteToAddOnViewDidLoad {
            addNote(content: noteToAddOnViewDidLoad)
            self.noteToAddOnViewDidLoad = nil
        }
        tableView.reloadData()
        definesPresentationContext = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
//        tableView.backgroundColor = .systemBackground
        if let splitVC = splitViewController as? PBHSplitViewController {
            splitVC.notesTableViewController = self
        }

        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addBarButton.isEnabled = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
        startObservingSynchronizationState()
    }

    override func viewDidAppear(_ animated: Bool) {
        if launching {
            didBecomeActive()
        }
        launching = false
    }

    // MARK: - Store Observation

    private var observation: NSKeyValueObservation?
    private var trackingToken: Any?

    func startObservingSynchronizationState() {
        // Register a tracking block that re-runs when the observed value changes
        trackingToken = withObservationTracking {
            _ = Store.shared.isSynchronizing
        } onChange: { [weak self] in
            guard let self = self else {
                return
            }

            Task { @MainActor in
                self.handleSynchronizationStateChange()
            }
        }
    }

    func handleSynchronizationStateChange() {
        if Store.shared.isSynchronizing {
            beginRefreshing()
        } else {
            endRefreshing()
        }
    }

    ///
    /// Update the user interface to reflect the active update.
    ///
    /// Outsourced into dedicated methods due to multiple callers.
    ///
    func beginRefreshing() {
        refreshBarButton.isEnabled = false
        addBarButton.isEnabled = false
        notesManager.manager.isSyncing = true
    }

    ///
    /// Update the user interface to reflect the completed update.
    ///
    /// Outsourced into dedicated methods due to multiple callers.
    ///
    func endRefreshing() {
        notesManager.manager.isSyncing = false
        addBarButton.isEnabled = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    // MARK: - Public functions

    func updateFrcDelegate(update: FrcDelegateUpdate) {
        switch update {
        case .disable:
            notesManager.manager.fetchedResultsController.delegate = nil
        case .enable(let withFetch):
            notesManager.manager.fetchedResultsController.delegate = notesManager.manager
            if withFetch {
                do {
                    try notesManager.manager.fetchedResultsController.performFetch()
                    tableView.reloadData()
                } catch { }
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = notesManager.manager.fetchedResultsController.sections {
            return sections.count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var title = ""
        if let sections = notesManager.manager.fetchedResultsController.sections {
            let currentSection = sections[section]
            if !currentSection.name.isEmpty {
                title = currentSection.name
            }
            let collapsed = notesManager.manager.disclosureSections.first(where: { $0.title == title })?.collapsed ?? false
            if !collapsed { // expanded
                return currentSection.numberOfObjects
            } else { // collapsed
                return 0
            }
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionHeaderView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as! CollapsibleTableViewHeaderView
        var displayTitle = ""
        var title = ""
        if let sections = notesManager.manager.fetchedResultsController.sections {
            let currentSection = sections[section]
            if !currentSection.name.isEmpty {
                displayTitle = currentSection.name
            }
            title = currentSection.name
        }
        sectionHeaderView.sectionTitle = title
        sectionHeaderView.sectionIndex = section
        sectionHeaderView.delegate = self
        sectionHeaderView.titleLabel.text = displayTitle
        sectionHeaderView.collapsed = notesManager.manager.disclosureSections.first(where: { $0.title == title })?.collapsed ?? false
        return sectionHeaderView
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let label = UILabel(frame: CGRect(origin: .zero, size: CGSize(width: Int.max, height: Int.max)))
        label.text = "test"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.sizeToFit()
        let height1 = label.frame.size.height

        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.sizeToFit()
        let height2 = label.frame.size.height

        return (height1 + height2) * 1.7
    }

    fileprivate func configureCell(_ cell: NoteTableViewCell, at indexPath: IndexPath) {
        guard notesManager.manager.fetchedResultsController.validate(indexPath: indexPath) else {
            return
        }

        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cell.backgroundColor = .ph_cellBackgroundColor
        cell.contentView.backgroundColor = .ph_cellBackgroundColor
        let selectedBackgroundView = UIView(frame: cell.frame)
        selectedBackgroundView.backgroundColor = UIColor.ph_cellSelectionColor
        cell.selectedBackgroundView = selectedBackgroundView

        let note = notesManager.manager.fetchedResultsController.object(at: indexPath)
        cell.textLabel?.text = note.title
        cell.backgroundColor = .clear
        let date = Date(timeIntervalSince1970: note.modified)
        cell.detailTextLabel?.text = dateFormat.string(from: date as Date)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = .secondaryLabel
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteTableViewCell
        configureCell(cell, at: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let note = notesManager.manager.fetchedResultsController.object(at: indexPath)
            HUD.show(.progress)
            if note == self.editorViewController?.note {
                self.editorViewController?.note = nil
            }

            if let sections = notesManager.manager.fetchedResultsController.sections {
                notesManager.manager.currentSectionObjectCount = sections[indexPath.section].numberOfObjects
            }

            NoteSessionManager.shared.delete(note: note, completion: { [weak self] in
                if self?.notesManager.manager.fetchedResultsController.validate(indexPath: indexPath) ?? false {
                    var newIndex = 0
                    if indexPath.row >= 0 {
                        newIndex = indexPath.row
                    }
                    var noteCount = 0
                    if let sections = self?.notesManager.manager.fetchedResultsController.sections,
                       sections.count >= indexPath.section {
                        noteCount = sections[indexPath.section].numberOfObjects
                    }
                    if newIndex >= noteCount {
                        newIndex = noteCount - 1
                    }

                    if newIndex >= 0 && newIndex < noteCount,
                       let newNote = self?.notesManager.manager.fetchedResultsController.sections?[indexPath.section].objects?[newIndex] as? CDNote {
                        self?.editorViewController?.note = newNote
                        DispatchQueue.main.async {
                            self?.tableView.selectRow(at: IndexPath(row: newIndex, section: indexPath.section), animated: false, scrollPosition: .none)
                        }
                    } else {
                        self?.editorViewController?.note = nil
                    }
                }
                HUD.hide()
            })
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    // MARK: - Navigation

    func isAvailableDirectEditing(identifier: String) -> Bool {

        if !KeychainHelper.internalEditor && identifier == detailSegueIdentifier && KeychainHelper.directEditing && KeychainHelper.directEditingSupportsFileId && (appDelegate.networkReachability == NKCommon.TypeReachability.reachableCellular || appDelegate.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi) {
            return true
        }

        return false
    }

    func openTextWebView(note: CDNote) {
        guard let account = KeychainHelper.account else {
            return
        }

        let notesPath = KeychainHelper.notesPath
        NextcloudKit.shared.NCTextOpenFile(fileNamePath: notesPath, fileId: String(note.cdId), editor: "text", account: account) { account, url, data, error in
            if error == .success, let url = url, let viewController: NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText {
                viewController.editor = "text"
                viewController.link = url
                viewController.fileName = note.cdTitle
                viewController.modalPresentationStyle = .fullScreen
                self.navigationController?.present(viewController, animated: true)
            } else {
                //
            }
        }

    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {

        if isAvailableDirectEditing(identifier: identifier), let cell = sender as? UITableViewCell, let cellIndexPath = tableView.indexPath(for: cell) {
            let note = notesManager.manager.fetchedResultsController.object(at: cellIndexPath)
            openTextWebView(note: note)
            return false
        } else {
            return true
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case detailSegueIdentifier:
            var selectedIndexPath = IndexPath(row: 0, section: 0)
            if let cell = sender as? UITableViewCell, let cellIndexPath = tableView.indexPath(for: cell) {
                selectedIndexPath = cellIndexPath
            }
            if let navigationController = segue.destination as? UINavigationController,
               let editorController = navigationController.topViewController as? EditorViewController {
                editorViewController = editorController
                let note = notesManager.manager.fetchedResultsController.object(at: selectedIndexPath)
                editorController.note = note
                editorController.isNewNote = isAddingFromButton
                isAddingFromButton = false
                editorController.navigationItem.leftItemsSupplementBackButton = true
                editorController.navigationItem.title = note.title
                if splitViewController?.displayMode == .allVisible || splitViewController?.displayMode == .primaryOverlay {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.splitViewController?.preferredDisplayMode = .primaryHidden
                    }, completion: nil)
                }
            }
//        case settingsSegueIdentifier:
//            if let navigationController = segue.destination as? UINavigationController,
//               let controller = navigationController.topViewController as? SettingsTableViewController {
//                controller.presentationController?.delegate = self
//                navigationController.presentationController?.delegate = self
//            }
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        editorViewController?.isNewNote = false
    }

    private func showRenameAlert(for indexPath: IndexPath) {
        var nameTextField: UITextField?
        let note = notesManager.manager.fetchedResultsController.object(at: indexPath)
        let alertController = UIAlertController(title: NSLocalizedString("Note Title", comment: "Title of alert to change title"),
                                                message: NSLocalizedString("Rename the note", comment: "Message of alert to change title"),
                                                preferredStyle: .alert)
        alertController.addTextField { textField in
            nameTextField = textField
            textField.text = note.title
            textField.keyboardType = .default
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Caption of Cancel button"), style: .cancel, handler: nil)
        let renameAction = UIAlertAction(title: NSLocalizedString("Rename", comment: "Caption of Rename button"), style: .default) { (action) in
            guard let newName = nameTextField?.text,
                  !newName.isEmpty,
                  newName != note.title else {
                return
            }
            note.title = newName
            NoteSessionManager.shared.update(note: note, completion: nil)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(renameAction)
        present(alertController, animated: true, completion: nil)
    }

    public override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard notesManager.manager.fetchedResultsController.validate(indexPath: indexPath) else {
            return nil
        }
        contextMenuIndexPath = indexPath
        let note = notesManager.manager.fetchedResultsController.object(at: indexPath)
        var actions = [UIAction]()

        if isNextcloud(),
           KeychainHelper.notesApiVersion != Router.defaultApiVersion {
            let renameAction = UIAction(title: NSLocalizedString("Rename…", comment: "Action to change title of a note"), image: UIImage(systemName: "square.and.pencil")) { [weak self] action in
                self?.showRenameAlert(for: indexPath)
            }
            actions.append(renameAction)
        }
        if isNextcloud() {
            let categoryAction = UIAction(title: NSLocalizedString("Category…", comment: "Action to change category of a note"), image: UIImage(named: "categories")) { [weak self] _ in
                self?.showCategories(indexPath: indexPath)
            }
            actions.append(categoryAction)
        }
        let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] action in
            guard let self = self,
                  !note.content.isEmpty else {
                return
            }
            self.noteExporter = NoteExporter(title: note.title, text: note.content, viewController: self, from: CGRect(origin: point, size: CGSize(width: 3, height: 3)), in: tableView)
            self.noteExporter?.showMenu()
        }
        actions.append(shareAction)

        let deleteAction = UIAction(title: NSLocalizedString("Delete", comment: "Action to delete a note"), image: (UIImage(systemName: "trash")), identifier: UIAction.Identifier("deleteAction"), discoverabilityTitle: nil, attributes: .destructive, state: .off, handler: { [weak self] _ in
            self?.tableView(tableView, commit: .delete, forRowAt: indexPath)
        })
        actions.append(deleteAction)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ -> UIMenu? in
            return UIMenu(title: "", children: actions)
        }

    }

    @IBAction func onPullToRefresh(_ sender: Any) {
        onRefresh(sender: sender)
    }

    @IBAction func onRefresh(sender: Any?) {
        guard NoteSessionManager.isOnline else {
            refreshControl?.endRefreshing()
            return
        }

        beginRefreshing()

        NoteSessionManager.shared.sync { [weak self] in
            self?.endRefreshing()
        }
    }

    @IBAction func onAdd(sender: Any?) {
        isAddingFromButton = true
        addNote(content: "")
    }

    func addNote(content: String) {
        guard isViewLoaded else {
            noteToAddOnViewDidLoad = content
            return
        }
        HUD.show(.progress)
        NoteSessionManager.shared.add(content: content, category: "", completion: { [weak self] note in
            if note != nil {
                let indexPath = IndexPath(row: 0, section: 0)
                if self?.notesManager.manager.fetchedResultsController.validate(indexPath: indexPath) ?? false,
                   let collapsedInfo = self?.notesManager.manager.disclosureSections.first(where: { $0.title == Constants.noCategory }),
                   !collapsedInfo.collapsed {
                    self?.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
                }
                self?.editorViewController?.isNewNote = true
                if (self?.isAvailableDirectEditing(identifier: detailSegueIdentifier)) ?? false, let note = note {
                    self?.openTextWebView(note: note)
                } else {
                    self?.performSegue(withIdentifier: detailSegueIdentifier, sender: self)
                }
            }
            HUD.hide()
        })
    }

    func updateSectionExpandedInfo() {
        let knownSectionTitles = Set(notesManager.manager.disclosureSections.map({ $0.title }))
        if let sections = notesManager.manager.fetchedResultsController.sections {
            if sections.isEmpty {
                notesManager.manager.disclosureSections = []
            } else {
                let newSectionTitles = Set(sections.map({ $0.name }))
                let deleted = knownSectionTitles.subtracting(newSectionTitles)
                let added = newSectionTitles.subtracting(knownSectionTitles)
                var sectionCollapsedInfo = notesManager.manager.disclosureSections.filter({ !deleted.contains($0.title) })
                for newSection in added {
                    sectionCollapsedInfo.append(DisclosureSection(title: newSection, collapsed: false))
                }
                notesManager.manager.disclosureSections = sectionCollapsedInfo
            }
        }
    }

    // MARK:  Notification Callbacks

    private func reachabilityChanged() {
        //
    }

    private func didBecomeActive() {
        if KeychainHelper.server.isEmpty {
//            performSegue(withIdentifier: "ShowSettings", sender: self)
        } else if KeychainHelper.syncOnStart {
            onRefresh(sender: nil)
        } else if KeychainHelper.dbReset {
            CDNote.reset()
            KeychainHelper.dbReset = false
            try? notesManager.manager.fetchedResultsController.performFetch()
            tableView.reloadData()
        }
        addBarButton.isEnabled = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
    }

    fileprivate func showCategories(indexPath: IndexPath) {
        let categories = notesManager.manager.fetchedResultsController.fetchedObjects?.compactMap({ (note) -> String? in
            return note.category
        })
        let storyboard = UIStoryboard(name: "Categories", bundle: Bundle.main)
        if let navController = storyboard.instantiateViewController(withIdentifier: "CategoryNavigationController") as? UINavigationController,
           let categoryController = navController.topViewController as? CategoryTableViewController,
           let categories = categories {
            let note = notesManager.manager.fetchedResultsController.object(at: indexPath)
            categoryController.categories = categories.removingDuplicates()
            if let section = notesManager.manager.fetchedResultsController.sections?.first(where: { $0.name == note.category }) {
                notesManager.manager.currentSectionObjectCount = section.numberOfObjects
            }
            categoryController.note = note
            self.present(navController, animated: true, completion: nil)
        }
    }

    override func applyTheme(brandColor: UIColor, brandTextColor: UIColor) {
        addBarButton.tintColor = brandColor
        refreshBarButton.tintColor = brandColor
    }
}

// MARK: - FRCManagerDelegate

extension NotesTableViewController: FRCManagerDelegate {
    func managerDidChangeContent(_ controller: NSObject, change: NotesFRCManagerChange) {
        change.applyChanges(tableView: tableView, animation: .fade)
    }
}

// MARK: - UISearchResultsUpdating

extension NotesTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        var predicate: NSPredicate?
        if let text = searchController.searchBar.text, !text.isEmpty {
            let matchingText = NSPredicate(format: "(cdTitle contains[c] %@) || (cdContent contains[cd] %@)", text, text)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [.allNotes, matchingText])
        } else {
            predicate = .allNotes
        }
        notesManager.manager.fetchedResultsController.fetchRequest.predicate = predicate
        do {
            try notesManager.manager.fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch { }
    }

}

// MARK: - UITableViewDropDelegate

extension NotesTableViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        if !session.items.isEmpty,
           session.hasItemsConforming(toTypeIdentifiers: [kUTTypeText as String,
                                                          kUTTypeXML as String,
                                                          kUTTypeHTML as String,
                                                          kUTTypeJSON as String,
                                                          kUTTypePlainText as String]) {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if destinationIndexPath?.section != 0 {
            return UITableViewDropProposal(operation: .forbidden, intent: .automatic)
        } else {
            return UITableViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
        }
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        for item in coordinator.session.items {
            item.itemProvider.loadDataRepresentation(forTypeIdentifier: kUTTypeText as String) { (data, _) in
                if let contentData = data,
                   let content = String(bytes: contentData, encoding: .utf8) {
                    NoteSessionManager.shared.add(content: content, category: "")
                }
            }
        }
    }

}

// MARK: - CollapsibleTableViewHeaderViewDelegate

extension NotesTableViewController: CollapsibleTableViewHeaderViewDelegate {
    func toggleSection(_ header: CollapsibleTableViewHeaderView, sectionTitle: String, sectionIndex: Int) {
        var sectionCollapsedInfo = notesManager.manager.disclosureSections
        if  let info = sectionCollapsedInfo.first(where: { $0.title == sectionTitle }),
            let index = sectionCollapsedInfo.firstIndex(where: { $0.title == sectionTitle }) {
            let collapsed = info.collapsed
            sectionCollapsedInfo.remove(at: index)
            sectionCollapsedInfo.insert(DisclosureSection(title: info.title, collapsed: !collapsed), at: index)
            notesManager.manager.disclosureSections = sectionCollapsedInfo
            header.collapsed = !collapsed
            self.tableView.reloadSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .automatic)
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension NotesTableViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        addBarButton.isEnabled = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
    }
}

// MARK: - Equatable

extension Array where Element: Equatable {
    func removingDuplicates() -> Array {
        return reduce(into: []) { result, element in
            if !result.contains(element) {
                result.append(element)
            }
        }
    }
}

// MARK: - allNotes

extension NSPredicate {
    static var allNotes: NSPredicate {
        return NSPredicate(format: "cdDeleteNeeded == %@", NSNumber(value: false))
    }

}

// MARK: - UIViewControllerRepresentable

struct NotesTableViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var addNote: Bool

    class Coordinator: NSObject {
        var parent: NotesTableViewControllerRepresentable
        weak var viewController: NotesTableViewController?

        init(_ parent: NotesTableViewControllerRepresentable) {
            self.parent = parent
        }

        func addNote() {
            viewController?.isAddingFromButton = true
            viewController?.addNote(content: "")

            parent.addNote = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main_iPhone", bundle: nil)

        let viewController = storyboard.instantiateViewController(withIdentifier: "Notes") as? NotesTableViewController
        context.coordinator.viewController = viewController

        return viewController ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {

        if addNote {
            context.coordinator.addNote()
        }
    }
}
