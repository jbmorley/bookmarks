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

struct BookmarkTagCommands: View {

    @Environment(\.manager) var manager
    @Environment(\.sheetHandler) var sheetHandler
    @Binding var sidebarSelection: BookmarksSection?

    var item: Item

    var body: some View {
        VStack {
            if item.tags.isEmpty {
                Button("No Tags") {}.disabled(true)
            } else {
                Menu("Tags") {
                    ForEach(Array(item.tags).sorted()) { tag in
                        Button(tag) {
                            sidebarSelection = tag.section
                        }
                    }
                }
            }
            Button("Copy Tags") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.tags.joined(separator: " "), forType: .string)
            }
            .disabled(item.tags.count < 1)
            Button("Add tags...") {
                sheetHandler(.addTags(items: [item]))
            }
        }
    }

}
