//
//  Note+CoreDataProperties.swift
//
//
//  Created by Peter Hedlund on 1/23/19.
//

import CoreData
import Foundation

extension Note {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var addNeeded: Bool
    @NSManaged public var category: String
    @NSManaged public var content: String
    @NSManaged public var deleteNeeded: Bool
    @NSManaged public var error: Bool
    @NSManaged public var errorMessage: String?
    @NSManaged public var etag: String
    @NSManaged public var favorite: Bool
    @NSManaged public var guid: String?
    @NSManaged public var id: Int64
    @NSManaged public var modified: Double
    @NSManaged public var readOnly: Bool
    @NSManaged public var title: String
    @NSManaged public var updateNeeded: Bool
}

extension Note: NoteProtocol {}
