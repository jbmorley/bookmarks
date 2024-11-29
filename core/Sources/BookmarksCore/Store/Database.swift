// Copyright (c) 2020-2024 Jason Morley
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Combine
import Foundation
import SwiftUI

import SQLite

public protocol DatabaseObserver {
    var id: UUID { get }
    func databaseDidUpdate(database: Database, scope: Database.Scope)
}

// TODO: Priority queues?
extension Bookmark {

    init(row: Row) throws {
        self.init(identifier: try row.get(Database.Schema.identifier),
                  title: try row.get(Database.Schema.title),
                  url: try row.get(Database.Schema.url).url,
                  tags: [],
                  date: try row.get(Database.Schema.date),
                  toRead: try row.get(Database.Schema.toRead),
                  shared: try row.get(Database.Schema.shared),
                  notes: try row.get(Database.Schema.notes),
                  iconURL: try row.get(Database.Schema.iconURL)?.url,
                  iconURLVersion: try row.get(Database.Schema.iconURLVersion))
    }

}

extension Connection {

    // TODO: Check if this is already supported in SQLite.swift
    public var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue)") }
    }

}

extension String {

    func and(_ statement: String) -> String {
        return "(\(self)) AND (\(statement))"
    }

    static func &&(lhs: String, rhs: String) -> String {
        return lhs.and(rhs)
    }

}

public class Database {

    public enum Scope {
        case bookmark(Bookmark.ID)
        case all
        case tag(String)
    }

    class Schema {

        static let items = Table("items")
        static let tags = Table("tags")
        static let items_to_tags = Table("items_to_tags")

        static let id = Expression<Int64>("id")
        static let identifier = Expression<String>("identifier")
        static let title = Expression<String>("title")
        static let url = Expression<String>("url")
        static let date = Expression<Date>("date")
        static let toRead = Expression<Bool>("to_read")
        static let shared = Expression<Bool>("shared")
        static let notes = Expression<String>("notes")
        static let iconURL = Expression<String?>("icon_url")
        static let iconURLVersion = Expression<Int>("icon_url_version")
        static let name = Expression<String>("name")
        static let itemId = Expression<Int64>("item_id")
        static let tagId = Expression<Int64>("tag_id")

    }

    // Default store location.
    // Unfortunately, when running unsigned under test, the group container creation fails so this code silently fails
    // over to using the documents directory. This is pretty inelegant as we'd really want a hard failure so it's not
    // possible to use the incorrect location in production but, absent a better solution, this will have to do.
    public static let sharedStoreURL: URL = {
        let fileManager = FileManager.default
        let identifier = "group.uk.co.jbmorley.bookmarks"
        let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directoryURL = groupURL ?? documentsURL
        try? fileManager.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("store.db")
    }()

    static var migrations: [Int32:(Connection) throws -> Void] = [
        1: { _ in },
        2: { _ in },
        3: { db in },
        4: { db in },
        5: { db in },
        6: { db in },
        7: { db in },
        8: { db in },
        9: { db in

            // Since there's no truly persistent information in the database up to this point, it's safe to entirely
            // delete and recreate the database. It also has the happy side effect that it brings the base schema into
            // one common place to make it easier to read.

            // Clean up the existing tables.
            try db.run(Schema.items.drop(ifExists: true))
            try db.run(Schema.items_to_tags.drop(ifExists: true))
            try db.run(Schema.tags.drop(ifExists: true))

            print("create the items table...")
            try db.run(Schema.items.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.identifier, unique: true)
                t.column(Schema.title)
                t.column(Schema.url, unique: true)
                t.column(Schema.date)
            })
            try db.run(Schema.items.createIndex(Schema.identifier, ifNotExists: true))

            print("create the tags table...")
            try db.run(Schema.tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.name, unique: true, collate: .nocase)
            })

            print("create the items_to_tags table...")
            try db.run(Schema.items_to_tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.itemId)
                t.column(Schema.tagId)
                t.unique(Schema.itemId, Schema.tagId)
                t.foreignKey(Schema.itemId, references: Schema.items, Schema.id, delete: .cascade)
                t.foreignKey(Schema.tagId, references: Schema.tags, Schema.id, delete: .cascade)
            })

        },
        10: { db in
            print("add the to_read column...")
            try db.run(Schema.items.addColumn(Schema.toRead, defaultValue: false))
        },
        11: { db in
            print("add the shared column...")
            try db.run(Schema.items.addColumn(Schema.shared, defaultValue: false))
        },
        12: { db in
            print("add the notes column...")
            try db.run(Schema.items.addColumn(Schema.notes, defaultValue: ""))
        },
        13: { db in
            print("add index on items.url...")
            try db.run(Schema.items.createIndex(Schema.url))
        },
        14: { db in
            print("add the icon column...")
            try db.run(Schema.items.addColumn(Schema.iconURL))
            try db.run(Schema.items.addColumn(Schema.iconURLVersion, defaultValue: 0))
        },
    ]

    static var schemaVersion: Int32 = Array(migrations.keys).max() ?? 0

    let path: URL
    let syncQueue = DispatchQueue(label: "Database.syncQueue")
    let targetQueue = DispatchQueue(label: "Database.targetQueue")
    var db: Connection  // Synchronized on syncQueue
    var observers: [DatabaseObserver] = []  // Synchronized on syncQueue

    var updatePublisher: Publishers.Concatenate<Publishers.Sequence<Array<Database>, Never>, DatabasePublisher> {
        return DatabasePublisher(database: self)
            .prepend(self)
    }

    public init(path: URL) throws {
        self.path = path
        self.db = try Connection(path.path)
        try syncQueue.sync {
            try self.syncQueue_migrate()
            try self.syncQueue_enableForeignKeys()
        }
    }

    public func add(observer: DatabaseObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.append(observer)
        }
    }

    public func remove(observer: DatabaseObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.removeAll { observer.id == $0.id }
        }
    }

    private func run<T>(operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            syncQueue.async {
                let result = Swift.Result<T, Error> {
                    try Task.checkCancellation()
                    return try operation()
                }
                continuation.resume(with: result)
            }
        }
    }

    private func syncQueue_migrate() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try db.transaction {
            let currentVersion = db.userVersion
            print("version \(currentVersion)")
            guard currentVersion < Self.schemaVersion else {
                print("schema up to date")
                return
            }
            for version in currentVersion + 1 ... Self.schemaVersion {
                print("migrating to \(version)...")
                guard let migration = Self.migrations[version] else {
                    throw BookmarksError.unknownMigration(version: version)
                }
                try migration(self.db)
                db.userVersion = version
            }
        }
    }

    private func syncQueue_enableForeignKeys() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try db.run("PRAGMA foreign_keys = ON")
    }

    private func syncQueue_notifyObservers(scope: Scope) {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let observers = Array(self.observers)
        // We use the serial `targetQueue` to notify our observers to ensure they don't need to worry about thread
        // safety issues arising from mutating internal state in the callback. For example, this makes it much easier
        // for an observer wishing to receive a single change to safely update its state when a change has been received
        // so it can ignore subsequent changes.
        targetQueue.async {
            for observer in observers {
                observer.databaseDidUpdate(database: self, scope: scope)
            }
        }
    }

    private func syncQueue_bookmark(identifier: String) throws -> Bookmark {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let run = try db.prepare(Schema.items.filter(Schema.identifier == identifier).limit(1)).map(Bookmark.init)
        guard let result = run.first else {
            throw BookmarksError.bookmarkNotFoundByIdentifier(identifier)
        }
        let tags = try syncQueue_tags(bookmarkIdentifier: result.identifier)
        return Bookmark(identifier: result.identifier,
                        title: result.title,
                        url: result.url,
                        tags: Set(tags),
                        date: result.date,
                        toRead: result.toRead,
                        shared: result.shared,
                        notes: result.notes)
    }

    private func syncQueue_fetchOrInsertTag(name: String) throws -> Int64 {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        if let id = try? syncQueue_tag(name: name) {
            return id
        }
        let id = try db.run(Schema.tags.insert(
            Schema.name <- name
        ))
        return id
    }

    private func syncQueue_tag(name: String) throws -> Int64 {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let results = try db.prepare(Schema.tags.filter(Schema.name == name).limit(1)).map { row in
            try row.get(Schema.id)
        }
        guard let result = results.first else {
            throw BookmarksError.tagNotFound(name: name)
        }
        return result
    }

    private func syncQueue_tags(bookmarkIdentifier: String) throws -> Set<String> {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        return Set(try self.db.prepare(Schema.items_to_tags
            .join(Schema.items, on: Schema.items_to_tags[Schema.itemId] == Schema.items[Schema.id])
            .join(Schema.tags, on: Schema.items_to_tags[Schema.tagId] == Schema.tags[Schema.id])
            .filter(Schema.identifier == bookmarkIdentifier))
            .map { row -> String in
                try row.get(Schema.tags[Schema.name])
            })
    }

    public func tags() async throws -> [Tag] {
        try await run {
            try self.syncQueue_tags()
        }
    }

    public func bookmark(identifier: String) async throws -> Bookmark {
        try await run {
            try self.syncQueue_bookmark(identifier: identifier)
        }
    }

    private func syncQueue_insertOrReplace(bookmark: Bookmark) throws {
        let tags = try bookmark.tags.map { try syncQueue_fetchOrInsertTag(name: $0) }
        let itemId = try self.db.run(Schema.items.insert(or: .replace,
                                                         Schema.identifier <- bookmark.identifier,
                                                         Schema.title <- bookmark.title,
                                                         Schema.url <- bookmark.url.absoluteString,
                                                         Schema.date <- bookmark.date,
                                                         Schema.toRead <- bookmark.toRead,
                                                         Schema.shared <- bookmark.shared,
                                                         Schema.notes <- bookmark.notes,
                                                         Schema.iconURL <- bookmark.iconURL?.absoluteString,
                                                         Schema.iconURLVersion <- bookmark.iconURLVersion))
        for tagId in tags {
            _ = try self.db.run(Schema.items_to_tags.insert(or: .replace,
                                                            Schema.itemId <- itemId,
                                                            Schema.tagId <- tagId))
        }
        try syncQueue_pruneTags()
    }

    private func syncQueue_insertOrUpdate(bookmark: Bookmark) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try self.db.transaction {
            // N.B. While it would be possible to use an insert or replace strategy directly, we want to ensure
            // we only notify observers if the data has actually changed so we instead fetch the item and
            // compare.
            if let existingBookmark = try? self.syncQueue_bookmark(identifier: bookmark.identifier) {

                // TODO: This is quite inelegant, but...
                // Derived data should be stable for a given URL and should never be overwritten even
                // if we've already got an existing bookmark. The better solution would be for the
                // updater to decide what to do; right now we're relying on a replacement strategy
                // because, up until now, there was no data stored on our bookmarks that wasn't
                // downloaded from Pinboard; it was essentially a local cache. With derived data that
                // changes and a better solution would be to get each bookmark in turn and update it
                // which would also give us the freedom to make more informed choices in the future.
                // Until now, we clone across cached data that has a different version.
                // This might definitely make sense to use in-memory objects to store these tuples.
                // Perhaps 'VersionedProperty'?
                var bookmark = bookmark
                if bookmark.iconURLVersion < existingBookmark.iconURLVersion {
                    print("Keeping cached icon URL")
                    bookmark.iconURL = existingBookmark.iconURL
                } else {
                    print("Using new icon URL for '\(bookmark.url)'")
                }

                if existingBookmark != bookmark {
                    try self.syncQueue_insertOrReplace(bookmark: bookmark)
                    self.syncQueue_notifyObservers(scope: .bookmark(bookmark.id))
                }
            } else {
                try self.syncQueue_insertOrReplace(bookmark: bookmark)
                self.syncQueue_notifyObservers(scope: .bookmark(bookmark.id))
            }
        }
    }

    public func insertOrUpdate(bookmark: Bookmark) async throws {
        try await run {
            try self.syncQueue_insertOrUpdate(bookmark: bookmark)
        }
    }

    public func insertOrUpdateBookmarks(_ bookmarks: [Bookmark]) async throws {
        for bookmark in bookmarks {
            try await insertOrUpdate(bookmark: bookmark)
        }
    }

    fileprivate func syncQueue_pruneTags() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try self.db.run("""
            DELETE
            FROM
                tags
            WHERE
                id NOT IN (
                    SELECT
                        tag_id
                    FROM
                        items_to_tags
                )
            """)
    }

    public func clear(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { () -> Void in
                        try self.db.run(Schema.items.delete())
                        try self.db.run(Schema.tags.delete())
                        try self.db.run(Schema.items_to_tags.delete())
                    }
                    self.syncQueue_notifyObservers(scope: .all)
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func syncQueue_delete(bookmark identifier: Bookmark.ID) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try db.transaction {
            let count = try db.run(Schema.items.filter(Schema.identifier == identifier).delete())
            if count == 0 {
                throw BookmarksError.bookmarkNotFoundByIdentifier(identifier)
            }
            try syncQueue_pruneTags()
            syncQueue_notifyObservers(scope: .bookmark(identifier))
        }
    }

    public func delete(bookmark identifier: Bookmark.ID) async throws {
        try await run {
            try self.syncQueue_delete(bookmark: identifier)
        }
    }

    public func delete(bookmarks: [Bookmark]) async throws {
        for bookmark in bookmarks {
            try await delete(bookmark: bookmark.identifier)
        }
    }

    private func syncQueue_delete(tag: String) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try self.db.transaction {
            try self.db.run(Schema.tags.filter(Schema.name == tag).delete())
            self.syncQueue_notifyObservers(scope: .tag(tag))
        }
    }

    public func delete(tag: String) async throws {
        try await run {
            try self.syncQueue_delete(tag: tag)
        }
    }

    public func syncQueue_tags() throws -> [Tag] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let selectQuery = """
            SELECT
                LOWER(name),
                COUNT(name)
            FROM
                items_to_tags
            JOIN
                tags
            ON
                tags.id == items_to_tags.tag_id
            GROUP BY
                LOWER(name)
            """

        let statement = try db.prepare(selectQuery)
        let tags = try statement.map { row in
            return Tag(name: try row.string(0),
                       count: try row.integer(1))
        }

        return tags
    }

    public func syncQueue_bookmarks(where whereClause: String, limit: Int?) throws -> [Bookmark] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        // TODO: Can I create this in SQLite's expression syntax? Do I want to?
        var selectQuery = """
            SELECT
                identifier,
                title,
                url,
                date,
                to_read,
                shared,
                notes,
                icon_url,
                icon_url_version
            FROM
                items
            WHERE \(whereClause)
            ORDER BY
                date DESC
            """

        if let limit {
            selectQuery += " LIMIT \(limit)"
        }

        let statement = try db.prepare(selectQuery)
        let bookmarks = try statement.map { row in
            return Bookmark(identifier: try row.string(0),
                            title: try row.string(1),
                            url: try row.url(2),
                            tags: [],
                            date: try row.date(3),
                            toRead: try row.bool(4),
                            shared: try row.bool(5),
                            notes: try row.string(6),
                            iconURL: try row.optionalURL(7),
                            iconURLVersion: try row.integer(8))
        }

        return bookmarks
    }

    public func syncQueue_count(where whereClause: String) throws -> Int {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let selectQuery = """
            SELECT
                COUNT(*)
            FROM
                items
            LEFT JOIN
                (
                    SELECT
                        item_id,
                        GROUP_CONCAT(tags.name) AS tags
                    FROM
                        items_to_tags
                    INNER JOIN
                        tags
                    ON
                        tags.id == items_to_tags.tag_id
                    GROUP BY
                        item_id
                )
            ON
                items.id == item_id
            WHERE \(whereClause)
            ORDER BY
                date DESC
            """

        return Int(try db.scalar(selectQuery) as! Int64)
    }

    public func bookmarks<T: QueryDescription>(query: T = True(), limit: Int? = nil) async throws -> [Bookmark] {
        try await run {
            try self.syncQueue_bookmarks(where: query.sql, limit: limit)
        }
    }

    public func count<T: QueryDescription>(query: T) async throws -> Int {
        try await run {
            try self.syncQueue_count(where: query.sql)
        }
    }

    private func syncQueue_identifiers() throws -> [String] {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        return try self.db.prepare(Schema.items.select(Schema.identifier)).map { row -> String in
            try row.get(Schema.identifier)
        }
    }

    public func identifiers() async throws -> [String] {
        try await run {
            try self.syncQueue_identifiers()
        }
    }

}
