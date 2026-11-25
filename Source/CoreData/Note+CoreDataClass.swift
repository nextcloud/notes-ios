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

    ///
    /// Ids of the notes known to the server, optionally only those without unpushed local changes.
    ///
    static func syncedIds(excludingPendingChanges: Bool = false) -> Set<Int64> {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        var predicates = [NSPredicate(format: "id > 0")]

        if excludingPendingChanges {
            predicates.append(NSPredicate(format: "addNeeded == NO AND updateNeeded == NO AND deleteNeeded == NO"))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            return Set(try NotesData.mainThreadContext.fetch(request).map(\.id))
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }

        return []
    }

    static func note(id: Int64) -> Note? {
        let request: NSFetchRequest<Note> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %lld", id)
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
            do {
                for note in notes {
                    if let existingRecord = try record(for: note) {
                        existingRecord.apply(note)
                    } else {
                        insert(note)
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
            do {
                if let existingRecord = try record(for: note) {
                    existingRecord.apply(note)
                    result = existingRecord
                } else {
                    result = insert(note)
                }

                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }

        return result
    }

    ///
    /// Applies server copies of notes. Rows with unpushed local changes keep them until they are pushed.
    ///
    static func merge(remote notes: [NoteProtocol]) {
        NotesData.mainThreadContext.performAndWait {
            do {
                for note in notes {
                    if let existingRecord = try record(for: note) {
                        guard !existingRecord.hasPendingChanges else { continue }

                        existingRecord.apply(note)
                    } else {
                        insert(note)
                    }
                }

                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
    }

    var hasPendingChanges: Bool {
        addNeeded || updateNeeded || deleteNeeded
    }

    private static func record(for note: NoteProtocol) throws -> Note? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()

        if note.id >= 0 {
            request.predicate = NSPredicate(format: "id == %lld", note.id)
        } else {
            request.predicate = NSPredicate(format: "guid == %@", note.guid ?? "")
        }

        return try NotesData.mainThreadContext.fetch(request).first
    }

    @discardableResult
    private static func insert(_ note: NoteProtocol) -> Note {
        let newRecord = NSEntityDescription.insertNewObject(forEntityName: Note.entityName, into: NotesData.mainThreadContext) as! Note

        if note.id > 0 {
            newRecord.id = note.id
            newRecord.addNeeded = false
        } else {
            newRecord.addNeeded = true
        }

        newRecord.apply(note, includingIdentity: false)
        return newRecord
    }

    private func apply(_ note: NoteProtocol, includingIdentity: Bool = true) {
        // Server payloads carry no guid; keep the local one so the note stays addressable.
        guid = note.guid ?? guid ?? UUID().uuidString

        // A note the server could not read arrives with placeholder content; never let it replace the real text.
        if !note.error || content.isEmpty {
            content = note.content
        }

        category = note.category
        title = note.title
        favorite = note.favorite
        readOnly = note.readOnly
        error = note.error
        errorMessage = note.errorMessage
        modified = note.modified
        etag = note.etag
        updateNeeded = note.updateNeeded
        deleteNeeded = note.deleteNeeded

        if includingIdentity {
            addNeeded = note.addNeeded
        }
    }

    static func delete(note: NoteProtocol) {
        NotesData.mainThreadContext.performAndWait {
            do {
                if let existingRecord = try record(for: note) {
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
        // The sync validators describe the local database, so they must not outlive it.
        KeychainHelper.eTag = ""
        KeychainHelper.lastModified = 0

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
