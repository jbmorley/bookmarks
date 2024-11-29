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

import SwiftUI

struct SectionTableView: View {

    struct LayoutMetrics {
        static let horizontalSpacing = 16.0
    }

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif

    @EnvironmentObject var settings: Settings
    @EnvironmentObject var sectionViewModel: SectionViewModel

    var body: some View {
#if os(iOS)
        List(selection: $sectionViewModel.selection) {
            ForEach(sectionViewModel.bookmarks) { bookmark in
                HStack(spacing: LayoutMetrics.horizontalSpacing) {
                    FaviconImage(url: bookmark.iconURL)
                    VStack(alignment: .leading) {
                        HStack {
                            Text(bookmark.title)
                                .lineLimit(2)
                            Spacer()
                            Text(bookmark.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        }
                        Text(bookmark.url.formatted(.short))
                            .foregroundColor(.secondary)
                            .font(.footnote)
                        TagsView(bookmark.tags)
                    }
                    .lineLimit(1)
                }
                .padding(.all, isCompact ? 0.0 : nil)
                .swipeActions {
                    Button(role: .destructive) {
                        await sectionViewModel.delete(.items([bookmark.id]))
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        sectionViewModel.getInfo(.items([bookmark.id]))
                    } label: {
                        Image(systemName: "info")
                    }
                    .tint(.accentColor)
                }
            }
        }
        .contextMenu(forSelectionType: Bookmark.ID.self) { selection in
            sectionViewModel.contextMenu(selection)
        } primaryAction: { selection in
            sectionViewModel.open(.items(selection), browser: settings.browser)
        }
        .listStyle(.plain)
#else
        Table(sectionViewModel.bookmarks, selection: $sectionViewModel.selection) {
            TableColumn("") { bookmark in
                FaviconImage(url: bookmark.url)
            }
            .width(FaviconImage.LayoutMetrics.size.width)
            TableColumn("Title", value: \.title)
            TableColumn("Domain") { bookmark in
                Text(bookmark.url.formatted(.short))
            }
            TableColumn("Date") { bookmark in
                Text(bookmark.date.formatted(date: .long, time: .standard))
            }
            TableColumn("Notes") { bookmark in
                Text(bookmark.notes)
            }
            TableColumn("Tags") { bookmark in
                TagsView(bookmark.tags, wraps: false)
            }
        }
        .contextMenu(forSelectionType: Bookmark.ID.self) { selection in
            sectionViewModel.contextMenu(selection)
        } primaryAction: { selection in
            sectionViewModel.open(.items(selection), browser: settings.browser)
        }
#endif
    }

}
