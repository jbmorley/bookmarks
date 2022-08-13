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
import SwiftUI

import BookmarksCore
import Diligence

@main
struct BookmarksApp: App {

    @Environment(\.manager) var manager

    @StateObject var selection = BookmarksSelection()
    
    @State var section: BookmarksSection? = .all

    var body: some Scene {
        WindowGroup {
            MainWindow(manager: manager, section: $section)
                .environment(\.selection, selection)
        }
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(after: .newItem) {
                Divider()
                Button("Refresh") {
                    manager.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Go") {
                Button("All Bookmarks") {
                    section = .all
                }
                .keyboardShortcut("1", modifiers: .command)
                Button("Private") {
                    section = .shared(false)
                }
                .keyboardShortcut("2", modifiers: .command)
                Button("Public") {
                    section = .shared(true)
                }
                .keyboardShortcut("3", modifiers: .command)
                Button("Today") {
                    section = .today
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Unread") {
                    section = .unread
                }
                .keyboardShortcut("5", modifiers: .command)
                Button("Untagged") {
                    section = .untagged
                }
                .keyboardShortcut("6", modifiers: .command)
            }
            CommandMenu("Bookmark") {
                BookmarkOpenCommands(selection: selection)
                    .trailingDivider()
                BookmarkDesctructiveCommands(selection: selection)
                    .trailingDivider()
                BookmarkEditCommands(selection: selection)
                    .trailingDivider()
                BookmarkShareCommands(selection: selection)
                    .trailingDivider()
                BookmarkTagCommands(selection: selection, section: $section)
            }
            CommandMenu("Account") {
                Button("Log Out...") {
                    manager.logout { _ in }
                }
            }
            AboutCommands()
        }
        SwiftUI.Settings {
            SettingsView()
        }

        AboutWindowGroup {
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
            License("Introspect", author: "Timber Software", filename: "Introspect")
        }

    }
}
