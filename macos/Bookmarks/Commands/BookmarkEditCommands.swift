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

import BookmarksCore

struct BookmarkEditCommands: View {

    @Environment(\.manager) var manager: BookmarksManager

    @ObservedObject var selection: BookmarksSelection

    var body: some View {
        Button(selection.containsUnreadBookmark ? "Mark as Read" : "Mark as Unread") {
            let toRead = !selection.containsUnreadBookmark
            selection.update(manager: manager, toRead: toRead)
        }
        .keyboardShortcut("U", modifiers: [.command, .shift])
        .disabled(selection.isEmpty)
        Button(selection.containsPublicBookmark ? "Make Private" : "Make Public") {
            let shared = !selection.containsPublicBookmark
            selection.update(manager: manager, shared: shared)
        }
        .disabled(selection.isEmpty)
        Button("Edit on Pinboard") {
            selection.editOnPinboard(manager: manager)
        }
        .disabled(selection.isEmpty)
    }
}
