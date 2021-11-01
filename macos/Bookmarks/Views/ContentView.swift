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

import Combine
import SwiftUI

import BookmarksCore
import Interact

struct ContentView: View {

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus

    @ObservedObject var selection: BookmarksSelection
    @Binding var section: BookmarksSection?
    @Binding var sheet: ApplicationState?

    @State var underlyingSection: BookmarksSection?
    @StateObject var bookmarksView: BookmarksView
    @StateObject var selectionTracker: SelectionTracker<Bookmark>
    @State var firstResponder: Bool = false
    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(selection: BookmarksSelection, section: Binding<BookmarksSection?>, database: Database, sheet: Binding<ApplicationState?>) {
        self.selection = selection
        _section = section
        let bookmarksView = Deferred(BookmarksView(database: database, query: True().eraseToAnyQuery()))
        let selectionTracker = Deferred(SelectionTracker(items: bookmarksView.get().$bookmarks))
        _bookmarksView = StateObject(wrappedValue: bookmarksView.get())
        _selectionTracker = StateObject(wrappedValue: selectionTracker.get())
        _sheet = sheet
    }

    var navigationTitle: String {
        let queries = searchDebouncer.debouncedValue.queries
        if (queries.section == .all && queries.count > 1) || queries.count > 1 {
            return "Search: \(searchDebouncer.debouncedValue)"
        }
        guard let title = section?.navigationTitle else {
            return "Unknown"
        }
        return title
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(bookmarksView.bookmarks) { bookmark in
                        BookmarkCell(bookmark: bookmark)
                            .shadow(color: .shadow, radius: 8)
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: bookmark), firstResponder: firstResponder))
                            .help(bookmark.url.absoluteString)
                            .contextMenuFocusable {
                                BookmarkOpenCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkDesctructiveCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkEditCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkShareCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkTagCommands(selection: selection, section: $section)
                                #if DEBUG
                                BookmarkDebugCommands()
                                    .leadingDivider()
                                #endif
                            } onContextMenuChange: { focused in
                                guard focused == true else {
                                    return
                                }
                                firstResponder = true
                                if !selectionTracker.isSelected(item: bookmark) {
                                    selectionTracker.handleClick(item: bookmark)
                                }
                            }
                            .menuType(.context)
                            .onDrag {
                                NSItemProvider(object: bookmark.url as NSURL)
                            }
                            .handleMouse {
                                if firstResponder || !selectionTracker.isSelected(item: bookmark) {
                                    selectionTracker.handleClick(item: bookmark)
                                }
                                firstResponder = true
                            } doubleClick: {
                                NSWorkspace.shared.open(bookmark.url)
                            } shiftClick: {
                                selectionTracker.handleShiftClick(item: bookmark)
                            } commandClick: {
                                selectionTracker.handleCommandClick(item: bookmark)
                            }
                    }
                }
                .padding()
            }
            .acceptsFirstResponder(isFirstResponder: $firstResponder)
            .handleMouse {
                firstResponder = true
                selectionTracker.clear()
            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(bookmarksView.state == .loading ? LoadingView() : nil)
        }
        .onAppear {
            bookmarksView.start()
        }
        .onDisappear {
            bookmarksView.stop()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    manager.refresh()
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ToolbarItem {
                Button {
                    guard selectionTracker.selection.count > 0 else {
                        return
                    }
                    selection.addTags()
                } label: {
                    SwiftUI.Image(systemName: "tag")
                }
                .help("Add Tags")
                .disabled(selection.isEmpty)
            }
            ToolbarItem {
                Button {
                    selection.delete(manager: manager)
                } label: {
                    SwiftUI.Image(systemName: "trash")
                }
                .help("Delete")
                .disabled(selection.isEmpty)
            }

            ToolbarItem {
                SearchField(search: $searchDebouncer.value)
                    .frame(minWidth: 100, idealWidth: 300, maxWidth: .infinity)
            }
        }
        .onReceive(searchDebouncer.$debouncedValue) { search in

            // Get the query corresponding to the current search text.
            let queries = AnyQuery.queries(for: search)

            // Update the selected section if necessary.
            let section = queries.section
            if section != section {
                underlyingSection = section
            }

            // Update the database query.
            bookmarksView.query = AnyQuery.and(queries)

        }
        .onChange(of: section) { section in

            guard underlyingSection != section,
                  let section = section else {
                return
            }

            underlyingSection = section

            selectionTracker.clear()
            bookmarksView.clear()
            let query = section.query
            searchDebouncer.value = query.filter
            bookmarksView.query = query.eraseToAnyQuery()

        }
        .onChange(of: underlyingSection, perform: { underlyingSection in

            guard section != underlyingSection else {
                return
            }

            // Bring the sidebar section in-line with the underlying section.
            section = underlyingSection

        })
        .onChange(of: selectionTracker.selection) { newSelection in
            selection.bookmarks = newSelection
        }
        .navigationTitle(navigationTitle)
    }
}
