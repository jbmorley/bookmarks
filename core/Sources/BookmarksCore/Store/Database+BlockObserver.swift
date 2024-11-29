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

    class BlockObserver: DatabaseObserver {

        let id = UUID()
        let database: Database
        var completion: ((Database.Scope) -> Void)? = nil

        init(database: Database, completion: @escaping (Database.Scope) -> Void) {
            self.database = database
            self.completion = completion
        }

        func start() {
            self.database.add(observer: self)
        }

        func cancel() {
            self.database.remove(observer: self)
        }

        func databaseDidUpdate(database: Database, scope: Database.Scope) {
            guard completion != nil else {
                return
            }
            completion?(scope)
            completion = nil
            database.remove(observer: self)
        }

    }

    func wait() async -> Database.Scope {
        // TODO: Support cancellation of this.
        await withCheckedContinuation { continuation in
            let observer = Database.BlockObserver(database: self) { scope in
                continuation.resume(returning: scope)
            }
            observer.start()
        }
    }

}
