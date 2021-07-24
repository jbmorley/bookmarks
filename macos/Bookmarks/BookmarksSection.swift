// Copyright (c) 2020-2021 InSeven Limited
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

import SwiftUI

enum BookmarksSection {
    case all
    case untagged
    case favorite(tag: String)
    case tag(tag: String)
}

extension BookmarksSection: CustomStringConvertible, Hashable, Identifiable {

    var id: String { String(describing: self) }

    var description: String {
        switch self {
        case .all:
            return "uk.co.inseven.bookmarks.all-bookmarks"
        case .untagged:
            return "uk.co.inseven.bookmarks.untagged"
        case .favorite(let tag):
            return "uk.co.inseven.bookmarks.favorites.\(tag)"
        case .tag(let tag):
            return "uk.co.inseven.bookmarks.tags.\(tag)"
        }
    }

}

extension String {

    var favoriteId: BookmarksSection { .favorite(tag: self) }
    var tagId: BookmarksSection { .tag(tag: self) }

}

struct FocusedMessageKey : FocusedValueKey {
        typealias Value = Binding<BookmarksSection?>
}

extension FocusedValues {
    var sidebarSelection: FocusedMessageKey.Value? {
        get { self[FocusedMessageKey.self] }
        set { self[FocusedMessageKey.self] = newValue }
    }
}