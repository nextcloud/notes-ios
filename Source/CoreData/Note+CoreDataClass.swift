//
//  Note+CoreDataClass.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Note)
public class Note: NSManagedObject {

    static private let entityName = "Note"

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = -1
        self.guid = UUID().uuidString
        self.content = ""
        self.category = ""
        self.addNeeded = true
        self.updateNeeded = false
        self.deleteNeeded = false
        self.modified = Date().timeIntervalSince1970
    }

    @objc var sectionName: String {
        if self.category.isEmpty {
            return Constants.noCategory
        } else {
            return self.category
        }
    }

    static func all() -> [Note]? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        let property = "deleteNeeded"
        request.predicate = NSPredicate(format: "%K == %@", property, NSNumber(value: false))
        var noteList = [Note]()
        do {
            let results  = try NotesData.mainThreadContext.fetch(request)
            for record in results {
                noteList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return noteList
    }

    static func starred() -> [Note]? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        let predicate1 = NSPredicate(format: "favorite == %@", NSNumber(value: true))
        let property = "deleteNeeded"
        let predicate2 = NSPredicate(format: "%K == %@", property, NSNumber(value: false))
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        do {
            return try NotesData.mainThreadContext.fetch(request)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func categories() -> [String]? {
        if let notes = Note.all() {
            let rawCategories = notes.compactMap({ (note) -> String? in
                return note.category
            })
            return Array(Set(rawCategories)).sorted()
        }
        return nil
    }
        
    static func notes(property: String) -> [Note]? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", property, NSNumber(value: true))
        do {
            return try NotesData.mainThreadContext.fetch(request)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func notes(category: String) -> [Note]? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        let predicate1 = NSPredicate(format: "category == %@", category)
        let property = "deleteNeeded"
        let predicate2 = NSPredicate(format: "%K == %@", property, NSNumber(value: false))
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        do {
            return try NotesData.mainThreadContext.fetch(request)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func note(id: Int32) -> Note? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %d", id)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NotesData.mainThreadContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }
    
    static func note(guid: String) -> Note? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        let predicate = NSPredicate(format: "guid == %@", guid)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NotesData.mainThreadContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func update(notes: [NoteProtocol]) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            do {
                for note in notes {
                    let predicate: NSPredicate
                    if note.id >= 0 {
                        predicate = NSPredicate(format: "id == %d", note.id)
                    } else {
                        predicate = NSPredicate(format: "guid == %@", note.guid ?? "")
                    }
                    request.predicate = predicate
                    let records = try NotesData.mainThreadContext.fetch(request)
                    if let existingRecord = records.first {
                        existingRecord.guid = note.guid
                        existingRecord.category = note.category
                        existingRecord.content = note.content
                        existingRecord.title = note.title
                        existingRecord.favorite = note.favorite
                        existingRecord.readOnly = note.readOnly
                        existingRecord.modified = note.modified
                        existingRecord.etag = note.etag
                        existingRecord.addNeeded = note.addNeeded
                        existingRecord.updateNeeded = note.updateNeeded
                        existingRecord.deleteNeeded = note.deleteNeeded
                    } else {
                        let newRecord = NSEntityDescription.insertNewObject(forEntityName: Note.entityName, into: NotesData.mainThreadContext) as! Note
                        newRecord.guid = note.guid
                        newRecord.category = note.category
                        newRecord.content = note.content
                        if note.id > 0 {
                            newRecord.id = note.id
                            newRecord.addNeeded = false
                        } else {
                            newRecord.addNeeded = true
                        }
                        newRecord.title = note.title
                        newRecord.favorite = note.favorite
                        newRecord.readOnly = note.readOnly
                        newRecord.modified = note.modified
                        newRecord.etag = note.etag
                        newRecord.updateNeeded = note.updateNeeded
                        newRecord.deleteNeeded = note.deleteNeeded
                    }
                }
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
    }

    static func update(note: NoteProtocol) -> Note? {
        var result: Note?
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            do {
                let predicate: NSPredicate
                if note.id >= 0 {
                    predicate = NSPredicate(format: "id == %d", note.id)
                } else {
                    predicate = NSPredicate(format: "guid == %@", note.guid ?? "")
                }
                request.predicate = predicate
                let records = try NotesData.mainThreadContext.fetch(request)
                if let existingRecord = records.first {
                    existingRecord.guid = note.guid
                    existingRecord.category = note.category
                    existingRecord.content = note.content
                    existingRecord.title = note.title
                    existingRecord.favorite = note.favorite
                    existingRecord.readOnly = note.readOnly
                    existingRecord.modified = note.modified
                    existingRecord.etag = note.etag
                    existingRecord.addNeeded = note.addNeeded
                    existingRecord.updateNeeded = note.updateNeeded
                    existingRecord.deleteNeeded = note.deleteNeeded
                    result = existingRecord
                } else {
                    let newRecord = NSEntityDescription.insertNewObject(forEntityName: Note.entityName, into: NotesData.mainThreadContext) as! Note
                    newRecord.guid = note.guid
                    newRecord.category = note.category
                    newRecord.content = note.content
                    if note.id > 0 {
                        newRecord.id = note.id
                        newRecord.addNeeded = false
                    } else {
                        newRecord.addNeeded = true
                    }
                    newRecord.title = note.title
                    newRecord.favorite = note.favorite
                    newRecord.readOnly = note.readOnly
                    newRecord.modified = note.modified
                    newRecord.etag = note.etag
                    newRecord.updateNeeded = note.updateNeeded
                    newRecord.deleteNeeded = note.deleteNeeded
                    result = newRecord
                }
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return result
    }

    static func delete(note: NoteProtocol) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            do {
                let predicate: NSPredicate
                if note.id >= 0 {
                    predicate = NSPredicate(format: "id == %d", note.id)
                } else {
                    predicate = NSPredicate(format: "guid == %@", note.guid ?? "")
                }
                request.predicate = predicate
                let records = try NotesData.mainThreadContext.fetch(request)
                if let existingRecord = records.first {
                    NotesData.mainThreadContext.delete(existingRecord)
                    try NotesData.mainThreadContext.save()
                }
            } catch let error as NSError {
                print("Could not perform deletion \(error), \(error.userInfo)")
            }
        }
    }

    static func delete(ids: [Int64]) {
        NotesData.mainThreadContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let predicate = NSPredicate(format: "id IN %@", ids)
            request.predicate = predicate
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
            do {
                try NotesData.mainThreadContext.executeAndMergeChanges(using: deleteRequest)
            } catch let error as NSError {
                print("Could not perform deletion \(error), \(error.userInfo)")
            }
        }
    }

    static func reset() {
        NotesData.mainThreadContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
            do {
                try NotesData.mainThreadContext.executeAndMergeChanges(using: deleteRequest)
            } catch {
                let updateError = error as NSError
                print("\(updateError), \(updateError.userInfo)")
            }
        }
    }

}
