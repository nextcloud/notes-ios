//
//  NotesFRCManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 11/5/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import CoreData

class NotesManager {
    let manager: FRCManager<CDNote>

    init() {
        let request = CDNote.fetchRequest()
        request.fetchBatchSize = 288
        request.predicate = .allNotes
        request.sortDescriptors = [NSSortDescriptor(key: "cdCategory", ascending: true),
                                   NSSortDescriptor(key: "cdModified", ascending: false)]

        manager = FRCManager(fetchRequest: request,
                   managedObjectContext: NotesData.mainThreadContext,
                   sectionNameKeyPath: "sectionName")
    }
}

enum FrcDelegateUpdate {
    case disable
    case enable(withFetch: Bool)
}

class FRCManager<ResultType> where ResultType: NSFetchRequestResult {

    var fetchedResultsController: NSFetchedResultsController<ResultType>
    var disclosureSections: DisclosureSections {
        get {
            return KeychainHelper.sectionExpandedInfo
        }
        set {
            KeychainHelper.sectionExpandedInfo = newValue
        }
    }

    public init(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext context: NSManagedObjectContext, sectionNameKeyPath: String?) {
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)

        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch in fetchedResultsControllerManager from core data:\(error)")
        }
    }
}

extension NSFetchedResultsController {

    @objc func validate(indexPath: IndexPath) -> Bool {
        if let sections = sections {
            if indexPath.section >= sections.count {
                return false
            }

            if indexPath.row >= sections[indexPath.section].numberOfObjects {
                return false
            }
        }
        return true
    }

}
