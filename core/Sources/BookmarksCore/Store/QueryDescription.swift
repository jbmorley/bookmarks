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

import Foundation

import SQLite

public protocol QueryDescription: Sectionable {

    var sql: String { get }
    var filter: String { get }
    func isEqualTo(_ other: QueryDescription) -> Bool

}

extension QueryDescription where Self: Equatable {

    public func isEqualTo(_ other: QueryDescription) -> Bool {
        guard let otherQuery = other as? Self else { return false }
        return self == otherQuery
    }

}

public struct Untagged: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }

    public var sql: String {
        "items.id NOT IN (SELECT item_id FROM items_to_tags)"
    }

    public var filter: String { "no:tag" }
    public var section: BookmarksSection { .untagged }

    public init() { }

}

public struct Unread: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }

    public var sql: String { "items.to_read = 1" }
    public var filter: String { "status:unread" }
    public var section: BookmarksSection { .unread }

    public init() { }
    
}

public struct Shared: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.shared == rhs.shared
    }

    var shared: Bool

    public var sql: String { "items.shared = \(shared ? "1" : "0")" }
    public var filter: String { "shared:\(shared ? "true" : "false")" }
    public var section: BookmarksSection { .shared(shared) }

    public init(_ shared: Bool) {
        self.shared = shared
    }

}

public struct Tag: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }

    let name: String

    public var sql: String {
        let tagsFilter = Database.Schema.name.lowercaseString == name.lowercased()
        let tagSubselect = """
            SELECT
                item_id
            FROM
                items_to_tags
            JOIN
                tags
            ON
                items_to_tags.tag_id = tags.id
            WHERE
                \(tagsFilter.asSQL())
            """
        return "items.id IN (\(tagSubselect))"
    }

    public var filter: String { "tag:\(name)" }
    public var section: BookmarksSection { .tag(name) }

    public init(_ name: String) {
        self.name = name
    }

}

public struct Like: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value
    }

    let value: String

    public var sql: String {
        let tagsColumn = Expression<String>("tags")
        let expression =
            Database.Schema.title.like("%\(filter)%") ||
            Database.Schema.url.like("%\(filter)%") ||
            tagsColumn.like("%\(filter)%") ||
            Database.Schema.notes.like("%\(filter)%")
        return expression.asSQL()
    }

    public var filter: String { value }
    public var section: BookmarksSection { .all }

    init(_ filter: String) {
        self.value = filter
    }

}

// TODO: I wonder if it might be more elegant to inject this as an 'any' expression?
public struct IconURLVersionLessThan: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version
    }

    let version: Int

    public var sql: String {
        let expression = Database.Schema.iconURLVersion < version
        return expression.asSQL()
    }

    // TODO: Check if the filter is used at all.
    public var filter: String { "" }
    public var section: BookmarksSection { .all }

    init(_ version: Int) {
        self.version = version
    }

}

public extension QueryDescription where Self: Equatable {

    func eraseToAnyQuery() -> AnyQuery {
        if Self.self == AnyQuery.self {
            return self as! AnyQuery
        }
        return AnyQuery(self)
    }

}

public struct Search: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.search == rhs.search
    }

    let search: String

    public var sql: String {
        search.tokens.map { Like($0) }.reduce(AnyQuery(True())) { AnyQuery(And($0, $1)) }.sql
    }

    public var filter: String { search }
    public var section: BookmarksSection { .all }

    init(_ search: String) {
        self.search = search
    }

}

public struct And<A, B>: QueryDescription, Equatable where A: QueryDescription & Equatable, B: QueryDescription & Equatable {

    public static func == (lhs: And, rhs: And) -> Bool {
        guard lhs.lhs == rhs.lhs else {
            return false
        }
        guard lhs.rhs == rhs.rhs else {
            return false
        }
        return true
    }

    fileprivate let lhs: A
    fileprivate let rhs: B

    public var sql: String { "(\(lhs.sql)) AND (\(rhs.sql))" }
    public var filter: String { "\(lhs.filter) \(rhs.filter)" }
    public var section: BookmarksSection { .all }

    init(_ lhs: A, _ rhs: B) {
        self.lhs = lhs
        self.rhs = rhs
    }

}

// TODO: Flatten AND queries into single arrays where possible #201
//       https://github.com/inseven/bookmarks/issues/201
func &&<T: QueryDescription, Q: QueryDescription>(lhs: T, rhs: Q) -> And<T, Q> {
    return And(lhs, rhs)
}

public struct True: QueryDescription, Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return true
    }

    public var sql: String { "1" }
    public var filter: String { "" }
    public var section: BookmarksSection { .all }

    public init() { }

}

public class Today: QueryDescription, Equatable {

    public static func == (lhs: Today, rhs: Today) -> Bool {
        return true
    }

    public var sql: String { "date >= datetime('now', '-1 day')" }
    public var filter: String { "date:today" }
    public var section: BookmarksSection { .today }

    public init() { }

}

public struct AnyQuery: QueryDescription, Equatable {

    public static func == (lhs: AnyQuery, rhs: AnyQuery) -> Bool {
        return lhs.query.isEqualTo(rhs.query)
    }

    public let query: QueryDescription

    public var sql: String { query.sql }
    public var filter: String { query.filter }
    public var section: BookmarksSection { query.section }

    init<T: QueryDescription>(_ query: T) {
        self.query = query
    }

}

extension AnyQuery {

    public static func and(_ queries: [AnyQuery]) -> AnyQuery {
        var result: AnyQuery? = nil
        for query in queries {
            if let safeResult = result {
                result = And(safeResult, query).eraseToAnyQuery()
            } else {
                result = query
            }
        }
        guard let safeResult = result else {
            return True().eraseToAnyQuery()
        }
        return safeResult
    }

    public static func parse(token: String) -> AnyQuery {
        let tagPrefix = "tag:"
        if token.hasPrefix(tagPrefix) {
            let tag = String(token.dropFirst(tagPrefix.count))
            return Tag(tag).eraseToAnyQuery()
        } else if token == "shared:false" {
            return Shared(false).eraseToAnyQuery()
        } else if token == "shared:true" {
            return Shared(true).eraseToAnyQuery()
        } else if token == "no:tag" {
            return Untagged().eraseToAnyQuery()
        } else if token == "status:unread" {
            return Unread().eraseToAnyQuery()
        } else if token == "date:today" {
            return Today().eraseToAnyQuery()
        } else {
            return Like(token).eraseToAnyQuery()
        }
    }

    public static func queries(for filter: String) -> [AnyQuery] {
        filter.tokens.map { AnyQuery.parse(token: $0) }
    }

    public static func parse(filter: String) -> AnyQuery {
        return and(queries(for: filter))
    }

}

public extension String {

    var queries: [AnyQuery] { AnyQuery.queries(for: self) }

}

extension Array: Sectionable where Element == AnyQuery {

    public var section: BookmarksSection {
        if let section = first?.section {
            return section
        }
        return .all
    }

}
