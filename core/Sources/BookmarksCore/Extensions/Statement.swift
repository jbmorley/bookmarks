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

import Foundation

import SQLite

extension Statement.Element {

    func string(_ index: Int) throws -> String {
        guard let value = self[index] as? String else {
            throw BookmarksError.corrupt
        }
        return value
    }

    func optionalString(_ index: Int) throws -> String? {
        guard let value = self[index] as? String? else {
            throw BookmarksError.corrupt
        }
        return value
    }

    func url(_ index: Int) throws -> URL {
        try string(index).url
    }

    func optionalURL(_ index: Int) throws -> URL? {
        try optionalString(index)?.url
    }

    func set(_ index: Int) throws -> Set<String> {
        guard let value = self[index] as? String? else {
            throw BookmarksError.corrupt
        }
        guard let safeValue = value else {
            return Set()
        }
        return Set(safeValue.components(separatedBy: ","))
    }

    func date(_ index: Int) throws -> Date {
        Date.fromDatatypeValue(try string(index))
    }

    func bool(_ index: Int) throws -> Bool {
        guard let value = self[index] as? Int64 else {
            throw BookmarksError.corrupt
        }
        return value > 0
    }

    func integer(_ index: Int) throws -> Int {
        guard let value = self[index] as? Int64 else {
            throw BookmarksError.corrupt
        }
        return Int(value)
    }

}
