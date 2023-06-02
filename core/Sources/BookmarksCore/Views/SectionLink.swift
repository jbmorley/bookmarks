// Copyright (c) 2020-2023 InSeven Limited
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

import Interact

class SectionLinkModel: ObservableObject, Runnable {

    @Published var count: Int = 0

    private var applicationModel: ApplicationModel
    private var section: BookmarksSection
    private var cancellables: Set<AnyCancellable> = []

    init(applicationModel: ApplicationModel, section: BookmarksSection) {
        self.applicationModel = applicationModel
        self.section = section
    }

    func start() {

        let section = section

        applicationModel.database
            .updatePublisher
            .debounce(for: 0.2, scheduler: DispatchQueue.global())
            .asyncMap { database in
                return (try? await database.count(query: section.query)) ?? 0
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.count, on: self)
            .store(in: &cancellables)

    }

    func stop() {
        cancellables.removeAll()
    }

}

public struct SectionLink: View {

    @StateObject var model: SectionLinkModel

    private var section: BookmarksSection

    public init(applicationModel: ApplicationModel, section: BookmarksSection) {
        self.section = section
        _model = StateObject(wrappedValue: SectionLinkModel(applicationModel: applicationModel, section: section))
    }

    public var body: some View {
        Label {
            Text(section.sidebarTitle)
        } icon: {
            Image(systemName: section.systemImage)
        }
        .badge(model.count)
        .runs(model)
        .tag(section)
    }

}
