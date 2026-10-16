// SPDX-FileCopyrightText: 2018 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

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

    /// Predicate that identifies the local record for the given note.
    ///
    /// Server-backed notes (`id > 0`) are matched by id. Notes that have not been created on the server yet are
    /// matched by guid. Returns `nil` when the note carries no usable identity, so callers never fall back to
    /// matching (or inserting) a record with an empty guid.
    static func predicate(for note: NoteProtocol) -> NSPredicate? {
        if note.id > 0 {
            return NSPredicate(format: "id == %lld", note.id)
        }
        if let guid = note.guid, !guid.isEmpty {
            return NSPredicate(format: "guid == %@", guid)
        }
        return nil
    }

    /// Copies the values of the given note onto this record. The guid is local only, so the server never sends
    /// one. An absent guid must never wipe the local one, because it is what identifies unsynced notes.
    private func apply(_ note: NoteProtocol) {
        if let guid = note.guid, !guid.isEmpty {
            self.guid = guid
        }
        category = note.category
        content = note.content
        title = note.title
        favorite = note.favorite
        readOnly = note.readOnly
        modified = note.modified
        etag = note.etag
        addNeeded = note.addNeeded
        updateNeeded = note.updateNeeded
        deleteNeeded = note.deleteNeeded
    }

    /// Inserts or updates the record for the given note. Returns the record, or `nil` if the note has no usable
    /// identity. Must be called on the main thread context.
    @discardableResult
    private static func upsert(_ note: NoteProtocol, in context: NSManagedObjectContext) throws -> Note? {
        guard let predicate = predicate(for: note) else {
            print("Ignoring note without a usable identity (id: \(note.id)).")
            return nil
        }
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = predicate
        request.fetchLimit = 1
        if let existingRecord = try context.fetch(request).first {
            existingRecord.apply(note)
            return existingRecord
        }
        guard let newRecord = NSEntityDescription.insertNewObject(forEntityName: Note.entityName, into: context) as? Note else {
            return nil
        }
        newRecord.apply(note)
        if note.id > 0 {
            newRecord.id = note.id
            newRecord.addNeeded = false
        } else {
            newRecord.addNeeded = true
        }
        return newRecord
    }

    static func update(notes: [NoteProtocol]) {
        NotesData.mainThreadContext.performAndWait {
            do {
                for note in notes {
                    try upsert(note, in: NotesData.mainThreadContext)
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
            do {
                result = try upsert(note, in: NotesData.mainThreadContext)
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return result
    }

    /// Records the outcome of a failed request on the existing local record. Unlike `update(notes:)` this never
    /// inserts, so a failing request cannot create copies of a note.
    static func markPending(_ note: NoteProtocol, update: Bool = false, delete: Bool = false) {
        NotesData.mainThreadContext.performAndWait {
            guard let predicate = predicate(for: note) else { return }
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = predicate
            request.fetchLimit = 1
            do {
                guard let existingRecord = try NotesData.mainThreadContext.fetch(request).first else { return }
                existingRecord.apply(note)
                existingRecord.updateNeeded = update || existingRecord.updateNeeded
                existingRecord.deleteNeeded = delete || existingRecord.deleteNeeded
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not update \(error), \(error.userInfo)")
            }
        }
    }

    static func delete(note: NoteProtocol) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            do {
                guard let predicate = predicate(for: note) else { return }
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
