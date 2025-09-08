//
//  NotesTests.swift
//  IOCNotesUnitTests
//
//  Created by Peter Hedlund on 10/20/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Testing
@testable import iOCNotes

@Suite("Notes Management Tests")
struct NotesTests {
    var originalServer: String = ""
    var originalUser: String = ""
    var originalPassword: String = ""
    
    init() {
        // Store original values
        originalServer = KeychainHelper.server
        originalUser = KeychainHelper.username
        originalPassword = KeychainHelper.password
        
        // Set test values
        KeychainHelper.server = "http://localhost:8080"
        KeychainHelper.username = "cloudnotes"
        KeychainHelper.password = "cloudnotes"
        
        // Clear database
        CDNote.reset()
    }
    
    deinit {
        // Restore original values
        KeychainHelper.server = originalServer
        KeychainHelper.username = originalUser
        KeychainHelper.password = originalPassword
    }

    @Test("Add note")
    func addNote() async throws {
        let content = "Note added during test"
        
        return await withCheckedContinuation { continuation in
            NotesManager.shared.add(content: content, category: "") { note in
                #expect(note != nil, "Expected note to not be nil")
                #expect(note?.addNeeded == false, "Expected addNeeded to be false")
                continuation.resume()
            }
        }
    }

    @Test("Add note with category")
    func addNoteWithCategory() async throws {
        let content = "Note with category added during test"
        let category = "Test Category"
        
        return await withCheckedContinuation { continuation in
            NotesManager.shared.add(content: content, category: category) { note in
                #expect(note != nil, "Expected note to not be nil")
                #expect(note?.addNeeded == false, "Expected addNeeded to be false")
                #expect(note?.category == "Test Category", "Expected the category to be Test Category")
                continuation.resume()
            }
        }
    }

    @Test("Add and delete note")
    func addAndDeleteNote() async throws {
        let content = "Note added and deleted during test"
        
        return await withCheckedContinuation { continuation in
            NotesManager.shared.add(content: content, category: "") { note in
                #expect(note != nil, "Expected note to not be nil")
                #expect(note?.addNeeded == false, "Expected addNeeded to be false")
                if let note = note {
                    NotesManager.shared.delete(note: note) {
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    @Test("Add and delete note with category")
    func addAndDeleteNoteWithCategory() async throws {
        let content = "Note added and deleted during test"
        let category = "Test Category"
        
        return await withCheckedContinuation { continuation in
            NotesManager.shared.add(content: content, category: category) { note in
                #expect(note != nil, "Expected note to not be nil")
                #expect(note?.addNeeded == false, "Expected addNeeded to be false")
                #expect(note?.category == "Test Category", "Expected the category to be Test Category")
                if let note = note {
                    NotesManager.shared.delete(note: note) {
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    @Test("Add offline")
    func addOffline() async throws {
        let content = "Note added during offline test"
        
        return await withCheckedContinuation { continuation in
            KeychainHelper.offlineMode = true
            NotesManager.shared.add(content: content, category: "") { note in
                #expect(note != nil, "Expected note to not be nil")
                #expect(note?.addNeeded == true, "Expected addNeeded to be true")
                KeychainHelper.offlineMode = false
                NotesManager.shared.sync() {
                    if CDNote.all()?.filter( { $0.addNeeded == true }).count ?? 0 > 0 {
                        Issue.record("Expected addNeeded count to be 0")
                    }
                    continuation.resume()
                }
            }
        }
    }

    @Test("Add and reset")
    func addAndReset() async throws {
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            var completedCount = 0
            
            let contents = [
                "Note 1 added during reset test",
                "Note 2 added during reset test",
                "Note 3 added during reset test",
                "Note 4 added during reset test"
            ]
            
            for content in contents {
                group.enter()
                NotesManager.shared.add(content: content, category: "") { note in
                    #expect(note != nil, "Expected note to not be nil")
                    completedCount += 1
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                #expect(completedCount == 4, "Expected all 4 notes to be added")
                CDNote.reset()
                if CDNote.all()?.count ?? 0 > 0 {
                    Issue.record("Expected note count to be 0")
                }
                continuation.resume()
            }
        }
    }

    @Test("Add and reset with categories")
    func addAndResetWithCategories() async throws {
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            var completedCount = 0
            
            let testData = [
                ("Note 1 added during reset test", ""),
                ("Note 2 added during reset test", ""),
                ("Note 3 added during reset test", "A Category"),
                ("Note 4 added during reset test", "A Category")
            ]
            
            for (content, category) in testData {
                group.enter()
                NotesManager.shared.add(content: content, category: category) { note in
                    #expect(note != nil, "Expected note to not be nil")
                    completedCount += 1
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                #expect(completedCount == 4, "Expected all 4 notes to be added")
                CDNote.reset()
                if CDNote.all()?.count ?? 0 > 0 {
                    Issue.record("Expected note count to be 0")
                }
                continuation.resume()
            }
        }
    }

    @Test("Add and move")
    func addAndMove() async throws {
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            var notes: [CDNote?] = []
            
            let contents = [
                "Note 1 added during add and move test",
                "Note 2 added during add and move test",
                "Note 3 added during add and move test",
                "Note 4 added during add and move test"
            ]
            
            // Add all notes first
            for content in contents {
                group.enter()
                NotesManager.shared.add(content: content, category: "") { note in
                    #expect(note != nil, "Expected note to not be nil")
                    notes.append(note)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Move notes 2 and 4 to a category
                let moveGroup = DispatchGroup()
                var updateCount = 0
                
                if notes.count >= 4 {
                    let note2 = notes[1]
                    let note4 = notes[3]
                    
                    if let note2 = note2 {
                        moveGroup.enter()
                        note2.category = "Add and Move Category"
                        NotesManager.shared.update(note: note2) {
                            updateCount += 1
                            moveGroup.leave()
                        }
                    }
                    
                    if let note4 = note4 {
                        moveGroup.enter()
                        note4.category = "Add and Move Category"
                        NotesManager.shared.update(note: note4) {
                            updateCount += 1
                            moveGroup.leave()
                        }
                    }
                }
                
                moveGroup.notify(queue: .main) {
                    #expect(updateCount == 2, "Expected 2 notes to be updated")
                    if CDNote.all()?.filter( { $0.category == "Add and Move Category" }).count ?? 0 != 2 {
                        Issue.record("Expected category count to be 2")
                    }
                    continuation.resume()
                }
            }
        }
    }

    @Test("Add and move out")
    func addAndMoveOut() async throws {
        let category = "Test Category Out"
        
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            var notes: [CDNote?] = []
            
            let contents = [
                "Note 1 added during add and move test",
                "Note 2 added during add and move test",
                "Note 3 added during add and move test",
                "Note 4 added during add and move test"
            ]
            
            // Add all notes with category first
            for content in contents {
                group.enter()
                NotesManager.shared.add(content: content, category: category) { note in
                    #expect(note != nil, "Expected note to not be nil")
                    notes.append(note)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Move notes 2 and 4 out of category
                let moveGroup = DispatchGroup()
                var updateCount = 0
                
                if notes.count >= 4 {
                    let note2 = notes[1]
                    let note4 = notes[3]
                    
                    if let note2 = note2 {
                        moveGroup.enter()
                        note2.category = ""
                        NotesManager.shared.update(note: note2) {
                            updateCount += 1
                            moveGroup.leave()
                        }
                    }
                    
                    if let note4 = note4 {
                        moveGroup.enter()
                        note4.category = ""
                        NotesManager.shared.update(note: note4) {
                            updateCount += 1
                            moveGroup.leave()
                        }
                    }
                }
                
                moveGroup.notify(queue: .main) {
                    #expect(updateCount == 2, "Expected 2 notes to be updated")
                    if CDNote.all()?.filter( { $0.category == "" }).count ?? 0 != 2 {
                        Issue.record("Expected category count to be 2")
                    }
                    continuation.resume()
                }
            }
        }
    }
}