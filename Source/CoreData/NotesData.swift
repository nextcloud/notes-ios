//
//  NotesData.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/3/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import CoreData

class NotesData {
    private enum MigrationMapping {
        // 2.0 migration: CDNote/cd* -> Note/*
        static let v2EntityRenamingIdentifier = "CDNote"
        static let v2AttributeRenames = [
            "addNeeded": "cdAddNeeded",
            "category": "cdCategory",
            "content": "cdContent",
            "deleteNeeded": "cdDeleteNeeded",
            "error": "cdError",
            "errorMessage": "cdErrorMessage",
            "etag": "cdEtag",
            "favorite": "cdFavorite",
            "guid": "cdGuid",
            "id": "cdId",
            "modified": "cdModified",
            "readOnly": "cdReadOnly",
            "title": "cdTitle",
            "updateNeeded": "cdUpdateNeeded"
        ]
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        guard let modelURL = Bundle.main.url(forResource: "Notes", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load Notes.momd")
        }

        if let noteEntity = model.entitiesByName["Note"] {
            noteEntity.renamingIdentifier = MigrationMapping.v2EntityRenamingIdentifier
            for (newName, oldName) in MigrationMapping.v2AttributeRenames {
                noteEntity.propertiesByName[newName]?.renamingIdentifier = oldName
            }
        }

        return model
    }

    
    static var mainThreadContext: NSManagedObjectContext = {
        let persistentContainer = NSPersistentContainer(name: "Notes", managedObjectModel: makeManagedObjectModel())
        if let storeDescription = persistentContainer.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        persistentContainer.loadPersistentStores(completionHandler: { store, error in
            print(store.url as Any)
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        return persistentContainer.viewContext
    }()
    
}

extension NSManagedObjectContext {
    
    /// Executes the given `NSBatchDeleteRequest` and directly merges the changes to bring the given managed object context up to date.
    ///
    /// - Parameter batchDeleteRequest: The `NSBatchDeleteRequest` to execute.
    /// - Throws: An error if anything went wrong executing the batch deletion.
    public func executeAndMergeChanges(using batchDeleteRequest: NSBatchDeleteRequest) throws {
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        let result = try execute(batchDeleteRequest) as? NSBatchDeleteResult
        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
    }
}
