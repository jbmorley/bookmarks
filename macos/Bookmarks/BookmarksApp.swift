// Copyright (c) 2020-2022 InSeven Limited
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

import AppKit
import Combine
import SwiftUI

import BookmarksCore
import Diligence

struct FocusedWindowModel: FocusedValueKey {
    typealias Value = WindowModel
}

extension FocusedValues {
    var windowModel: FocusedWindowModel.Value? {
        get { self[FocusedWindowModel.self] }
        set { self[FocusedWindowModel.self] = newValue }
    }
}

struct FocusedSelection: FocusedValueKey {
    typealias Value = BookmarksSelection
}

extension FocusedValues {
    var selection: FocusedSelection.Value? {
        get { self[FocusedSelection.self] }
        set { self[FocusedSelection.self] = newValue }
    }
}

protocol Runnable {

    func start()
    func stop()

}

extension View {

    func run(_ runnable: Runnable) -> some View {
        self
            .onAppear {
                runnable.start()
            }
            .onDisappear {
                runnable.stop()
            }
    }

}

class TagEditorModel: ObservableObject, Runnable {

    @Published var tags: [String] = []
    @Published var filter = ""
    @Published var filteredTags: [String] = []
    @Published var selection: Set<String> = []

    var tagsView: TagsView
    var cancellables: Set<AnyCancellable> = []

    init(tagsView: TagsView) {
        self.tagsView = tagsView
    }

    @MainActor func start() {
        tagsView.$tags
            .combineLatest($filter)
            .receive(on: DispatchQueue.global())
            .map { tags, filter in
                guard !filter.isEmpty else {
                    return tags
                }
                return tags.filter { $0.localizedCaseInsensitiveContains(filter) }
            }
            .receive(on: DispatchQueue.main)
            .sink { filteredTags in
                self.filteredTags = filteredTags
            }
            .store(in: &cancellables)
    }

    @MainActor func stop() {
        cancellables.removeAll()
    }

}

struct TagsContentView: View {

    @ObservedObject var model: TagEditorModel

    init(tagsView: TagsView) {
        _model = ObservedObject(initialValue: TagEditorModel(tagsView: tagsView))
    }

    var body: some View {
        Table(model.filteredTags, selection: $model.selection) {
            TableColumn("Tag", value: \.self)
        }
        .searchable(text: $model.filter)
        .run(model)
    }

}

@main
struct BookmarksApp: App {

    @Environment(\.manager) var manager

    @StateObject var selection = BookmarksSelection()

    var body: some Scene {
        WindowGroup {
            MainWindow(manager: manager)
                .environment(\.selection, selection)
        }
        .commands {
            SidebarCommands()
            ToolbarCommands()
            SectionCommands()
            CommandGroup(after: .newItem) {
                Divider()
                Button("Refresh") {
                    manager.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Bookmark") {
                BookmarkOpenCommands()
                    .trailingDivider()
                BookmarkDesctructiveCommands(selection: selection)
                    .trailingDivider()
                BookmarkEditCommands(selection: selection)
                    .trailingDivider()
                BookmarkShareCommands(selection: selection)
                    .trailingDivider()
                BookmarkTagCommands(selection: selection)
            }
            AccountCommands()
        }
        SwiftUI.Settings {
            SettingsView()
        }

        Window("Tags", id: "tags") {
            TagsContentView(tagsView: manager.tagsView)
        }

        About {
            Action("InSeven Limited", url: URL(string: "https://inseven.co.uk")!)
            Action("Support", url: URL(address: "support@inseven.co.uk", subject: "Bookmarks Support")!)
        } acknowledgements: {
            Acknowledgements("Developers") {
                Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk"))
            }
            Acknowledgements("Thanks") {
                Credit("Blake Merryman")
                Credit("Joanne Wong")
                Credit("Lukas Fittl")
                Credit("Pavlos Vinieratos")
                Credit("Sara Frederixon")
                Credit("Sarah Barbour")
                Credit("Terrence Talbot")
            }
        } licenses: {
            License("Binding+mappedToBool", author: "Joseph Duffy", filename: "Binding+mappedToBool")
            License("Diligence", author: "InSeven Limited", filename: "Diligence")
            License("Interact", author: "InSeven Limited", filename: "interact-license")
            License("Introspect", author: "Timber Software", filename: "Introspect")
            License("SQLite.swift", author: "Stephen Celis", filename: "SQLite-swift")
            License("TFHpple", author: "Topfunky Corporation", filename: "TFHpple")
        }

    }
}
