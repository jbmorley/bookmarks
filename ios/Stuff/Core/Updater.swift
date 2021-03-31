// Copyright (c) 2020-2021 Jason Barrie Morley
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

protocol UpdaterObserver: AnyObject {

}

class Updater {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let store: Store
    let token: String
    var observers: [UpdaterObserver] // Synchronized on syncQueue

    init(store: Store, token: String) {
        self.store = store
        self.token = token
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        self.observers = []
    }

    func add(observer: UpdaterObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            self.observers.append(observer)
        }
    }

    func remove(observer: UpdaterObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            self.observers.removeAll { ( $0 === observer ) }
        }
    }

    func start() {
        Pinboard(token: self.token).fetch { [weak self] (result) in
            switch (result) {
            case .failure(let error):
                print("Failed to fetch the posts with error \(error)")
            case .success(let posts):
                guard let self = self else {
                    return
                }
                var items: [Item] = []
                for post in posts {
                    guard
                        let url = post.href,
                        let date = post.time else {
                            continue
                    }
                    items.append(Item(identifier: post.hash,
                                      title: post.description ?? "",
                                      url: url,
                                      tags: post.tags,
                                      date: date))
                }
                self.store.save(items: items) { (success) in
                    print("Saved items with success \(success)")
                }
            }
        }
    }

}
