// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Faris Armoush
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import Foundation
import Testing
@testable import iOCNotes

/// Covers the identity matching which keeps sync from creating copies of a note (#221).
@Suite("Note identity", .serialized)
@MainActor
struct NoteIdentityTests {
    private let originalContext = NotesData.mainThreadContext

    init() {
        NotesData.mainThreadContext = NotesData.makeInMemoryContext()
    }

    private func restoreContext() {
        NotesData.mainThreadContext = originalContext
    }

    private func count() -> Int {
        (try? NotesData.mainThreadContext.count(for: Note.fetchRequest())) ?? -1
    }

    /// A note as the server returns it: no guid, never flagged for sync.
    private func serverNote(id: Int64, content: String = "server") -> NoteStruct {
        var note = NoteStruct(content: content, category: "")
        note.id = id
        note.guid = nil
        note.addNeeded = false
        return note
    }

    private func localNote(guid: String?, id: Int64 = -1) -> NoteStruct {
        var note = NoteStruct(content: "local", category: "")
        note.id = id
        note.guid = guid
        return note
    }

    @Test("Notes without a usable identity are never inserted", arguments: [
        (Int64(0), String?.none),
        (Int64(-1), String?.none),
        (Int64(-1), String?.some(""))
    ])
    func skipsNotesWithoutIdentity(id: Int64, guid: String?) {
        defer { restoreContext() }
        var note = localNote(guid: guid, id: id)
        note.guid = guid

        Note.update(notes: [note])
        _ = Note.update(note: note)

        #expect(count() == 0)
    }

    @Test("Notes with a guid or a server id are inserted once", arguments: [
        (Int64(-1), String?.some("guid-1")),
        (Int64(42), String?.none),
        (Int64(42), String?.some("guid-1"))
    ])
    func insertsNotesWithIdentity(id: Int64, guid: String?) {
        defer { restoreContext() }
        let note = localNote(guid: guid, id: id)

        Note.update(notes: [note])
        Note.update(notes: [note])

        #expect(count() == 1)
    }

    @Test("A server payload without a guid keeps the local guid", arguments: [1, 2, 14])
    func keepsLocalGuid(repeats: Int) throws {
        defer { restoreContext() }
        let created = try #require(Note.update(note: localNote(guid: "guid-1")))
        created.id = 7
        created.addNeeded = false

        for _ in 0..<repeats {
            Note.update(notes: [serverNote(id: 7, content: "from server")])
        }

        #expect(count() == 1)
        #expect(created.guid == "guid-1")
        #expect(created.content == "from server")
    }

    @Test("Repeated updates of an unsynced note never duplicate it", arguments: [1, 2, 14])
    func unsyncedNoteStaysSingle(repeats: Int) throws {
        defer { restoreContext() }
        let created = try #require(Note.update(note: localNote(guid: "guid-1")))

        for _ in 0..<repeats {
            Note.update(notes: [created])
            // What a failed request used to do with a note whose guid was wiped.
            Note.markPending(created, update: true)
        }

        #expect(count() == 1)
        #expect(created.guid == "guid-1")
    }

    @Test("markPending never inserts")
    func markPendingDoesNotInsert() {
        defer { restoreContext() }
        Note.markPending(localNote(guid: "missing"), update: true)
        Note.markPending(serverNote(id: 99), delete: true)

        #expect(count() == 0)
    }

    @Test("markPending flags an existing note without duplicating it")
    func markPendingFlagsExisting() throws {
        defer { restoreContext() }
        let created = try #require(Note.update(note: serverNote(id: 5)))
        #expect(created.updateNeeded == false)

        Note.markPending(created, update: true)

        #expect(count() == 1)
        #expect(created.updateNeeded)
        #expect(created.deleteNeeded == false)
    }

    @Test("Deleting a note without identity removes nothing")
    func deleteWithoutIdentity() throws {
        defer { restoreContext() }
        _ = try #require(Note.update(note: localNote(guid: "guid-1")))

        Note.delete(note: localNote(guid: nil, id: 0))

        #expect(count() == 1)
    }
}
