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

import Foundation

// TODO: Switch to the new async await Swift concurrency model (when it becomes available)


// TODO: Timeout error?

// TODO: This feels icky icky icky
// TODO: Make it a try??
public class AsyncOperation<T> {

    var semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error> = .failure(DatabaseError.unknown)

    init(_ operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) {
        operation(self.completion)
    }

    func completion(_ result: Result<T, Error>) -> Void {
        self.result = result
        semaphore.signal()
    }

    func wait() throws -> T {
        semaphore.wait()  // TODO: Timeout
        switch self.result {
        case .failure(let error):
            throw error
        case .success(let value):
            return value
        }
    }

}

public class Updater {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let database: Database
    let token: String

    public init(database: Database, token: String) {
        self.database = database
        self.token = token
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
    }

    // TODO: Start is kind of misleading in terms of terminology since you might want this to be a periodic updater?
    // TODO: The udpater should be able to store and clear its last error for reporting it to the user; or maybe there's an infrastructure piece and a wrapper that stores that? (BETTER?)
    //       This could use classic callbacks which are then wrapped?
    public func start() {
        print("Updating bookmarks...")
        Pinboard(token: self.token).posts_all { [weak self] (result) in
            switch (result) {
            case .failure(let error):
                print("Failed to fetch the posts with error \(error)")
            case .success(let posts):
                guard let self = self else {
                    return
                }

                // Store the seen identifiers to determine what to delete.
                var identifiers = Set<String>()

                // Insert or update items.
                for post in posts {
                    guard
                        let url = post.href,
                        let date = post.time else {
                            continue
                    }
                    // TODO: Perhaps this mapping could be extracted to make it clearer what's going on?
                    let item = Item(identifier: post.hash,
                                    title: post.description ?? "",
                                    url: url,
                                    tags: post.tags,
                                    date: date)
                    identifiers.insert(item.identifier)
                    _ = try! self.database.insertOrUpdate(item) // TODO: Handle a failure here.
                }

                // Delete missing items.
                do {
                    let allIdentifiers = try AsyncOperation(self.database.allIdentifiers).wait()
                    let deletedIdentifiers = Set(allIdentifiers).subtracting(identifiers)
                    for identifier in deletedIdentifiers {
                        print("deleting \(identifier)...")
                        let item = try AsyncOperation({ self.database.item(identifier: identifier, completion: $0) }).wait()
                        print(item)
                    }

                } catch {
                    print("Failed to delete items with error \(error)")
                }

            }
        }
    }

}
