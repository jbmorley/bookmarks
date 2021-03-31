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

enum SettingsKey: String {
    case pinboardApiKey = "pinboard-api-key"
    case useInAppBrowser = "use-in-app-browser"
    case maximumConcurrentThumbnailDownloads = "maximum-concurrent-thumbnail-downloads"
}

final class Settings: ObservableObject {

    var defaults: UserDefaults {
        UserDefaults.standard
    }

    @Published var pinboardApiKey: String {
        didSet { defaults.set(pinboardApiKey, forKey: SettingsKey.pinboardApiKey.rawValue) }
    }

    @Published var useInAppBrowser: Bool {
        didSet { defaults.set(useInAppBrowser, forKey: SettingsKey.useInAppBrowser.rawValue) }
    }

    @Published var maximumConcurrentThumbnailDownloads: Int {
        didSet { defaults.set(maximumConcurrentThumbnailDownloads,
                              forKey: SettingsKey.maximumConcurrentThumbnailDownloads.rawValue) }
    }

    init() {
        let defaults = UserDefaults.standard
        pinboardApiKey = defaults.string(forKey: SettingsKey.pinboardApiKey.rawValue) ?? ""
        useInAppBrowser = defaults.bool(forKey: SettingsKey.useInAppBrowser.rawValue)
        maximumConcurrentThumbnailDownloads = defaults.integer(forKey: SettingsKey.maximumConcurrentThumbnailDownloads.rawValue)
        if maximumConcurrentThumbnailDownloads == 0 {
            maximumConcurrentThumbnailDownloads = 3
        }
    }

}
