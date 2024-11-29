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

import Foundation

extension Database {

//    public func bookmarks<T: QueryDescription>(query: T) async throws -> [Bookmark] {

    // TODO: Await new data should be an option?
    struct Bookmarks<T: QueryDescription>: AsyncSequence {
        typealias Element = Bookmark

        let database: Database
        let query: T

        struct AsyncIterator: AsyncIteratorProtocol {

            let database: Database
            let query: T

            mutating func next() async throws -> Bookmark? {
                while true {
                    // TODO: This is fetching EVERYTHING and we should definitely not do this.
                    if let bookmark = try await database.bookmarks(query: query, limit: 1).first {
                        return bookmark
                    }

                    // TODO: Since we're not observing until we've processed the last element this can drop chanegs.
                    _ = await database.wait()
                }
            }
        }

        func makeAsyncIterator() -> AsyncIterator {
            return AsyncIterator(database: database, query: query)
        }
    }

    func identifiers<T: QueryDescription>(query: T = True()) -> Bookmarks<T> {
        return Bookmarks(database: self, query: query)
    }

}
