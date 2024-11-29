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

public struct Bookmark: Equatable {

    public enum Location {
        case web
        case internetArchive
    }

    static var placeholder: Self {
        return Self(identifier: "",
                    title: "",
                    url: URL(string: "https://jbmorley.co.uk")!,
                    tags: [],
                    date: .now,
                    toRead: false,
                    shared: false,
                    notes: "")
    }

    public let identifier: String
    public var title: String
    public var url: URL
    public var tags: Set<String>
    public var date: Date
    public var toRead: Bool
    public var shared: Bool
    public var notes: String
    public var iconURL: URL?
    public var iconURLVersion: Int
    public var thumbnail: SafeImage?

    init(identifier: String,
         title: String,
         url: URL,
         tags: Set<String>,
         date: Date,
         toRead: Bool,
         shared: Bool,
         notes: String,
         thumbnail: SafeImage? = nil,
         iconURL: URL? = nil,
         iconURLVersion: Int = 0) {
        self.identifier = identifier
        self.title = title
        self.url = url
        self.tags = Set(tags.map { $0.lowercased() })
        self.date = date
        self.toRead = toRead
        self.shared = shared
        self.notes = notes
        self.thumbnail = thumbnail
        self.iconURL = iconURL
        self.iconURLVersion = iconURLVersion
    }

    public static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        guard lhs.identifier == rhs.identifier else {
            return false
        }
        guard lhs.title == rhs.title else {
            return false
        }
        guard lhs.url == rhs.url else {
            return false
        }
        guard lhs.tags == rhs.tags else {
            return false
        }
        guard lhs.date == rhs.date else {
            return false
        }
        guard lhs.toRead == rhs.toRead else {
            return false
        }
        guard lhs.shared == rhs.shared else {
            return false
        }
        guard lhs.notes == rhs.notes else {
            return false
        }
        guard lhs.iconURL == rhs.iconURL else {
            return false
        }
        guard lhs.iconURLVersion == rhs.iconURLVersion else {
            return false
        }
        return true
    }

    public func setting(toRead: Bool) -> Bookmark {
        var bookmark = self
        bookmark.toRead = true
        return bookmark
    }

    public func setting(shared: Bool) -> Bookmark {
        var bookmark = self
        bookmark.shared = true
        return bookmark
    }

    public func url(_ location: Location) throws -> URL {
        switch location {
        case .web:
            return url
        case .internetArchive:
            return try "https://web.archive.org/web/*/".url.appendingPathComponent(url.absoluteString)
        }
    }

}

extension Bookmark: Identifiable {

    public var id: String { identifier }

}

extension Bookmark: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

}

extension Bookmark: CustomStringConvertible {

    public var description: String {
        "\(url.absoluteString) (title: \(title), tags: [\(tags.joined(separator: ", "))], date: \(date), toRead: \(toRead), notes: '\(self.notes)', iconURLVersion: \(iconURLVersion)"
    }

}

extension Array where Element == Bookmark {

    public var containsUnreadBookmark: Bool {
        self.first { $0.toRead } != nil
    }

    public var containsPublicBookmark: Bool {
        self.first { $0.shared } != nil
    }

    public var tags: Set<String> {
        reduce(Set<String>()) { result, bookmark in
            result.union(bookmark.tags)
        }
    }

}

extension Pinboard.Post {

    // TODO: Review the nullability of the properties on the Pinboard.Post struct #216
    //       https://github.com/inseven/bookmarks/issues/216
    init(_ bookmark: Bookmark) {
        self.init(href: bookmark.url,
                  description: bookmark.title,
                  extended: bookmark.notes,
                  hash: "",
                  meta: "",
                  shared: bookmark.shared,
                  tags: Array(bookmark.tags),
                  time: bookmark.date,
                  toRead: bookmark.toRead)
    }

}
