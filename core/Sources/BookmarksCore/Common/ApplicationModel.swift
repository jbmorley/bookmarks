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

import Combine
import SwiftUI

import Interact

public class ApplicationModel: ObservableObject {

    public enum State {
        case idle
        case unauthorized
    }

    @MainActor @Published public var state: State = .idle
    @MainActor @Published public var topTags: [String] = []
    @MainActor @Published public var progress: Progress = .idle

    public var imageCache: ImageCache!
    public var thumbnailManager: ThumbnailManager
    public var settings = Settings()
    public var tagsModel: TagsModel
    public var cache: NSCache = NSCache<NSString, SafeImage>()
    public var database: Database

    private var downloadManager: DownloadManager
    private var store: Store
    private var cancellables: Set<AnyCancellable> = []

    public init() {

        // Ensure the documents directory exists.
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        try! fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)

        // Clean up the legacy store if it exists.
        let legacyStoreURL = documentsURL.appendingPathComponent("store.db")
        if fileManager.fileExists(atPath: legacyStoreURL.path) {
            print("Legacy store exists; cleaning up.")
            try? fileManager.removeItem(at: legacyStoreURL)
        }

        // Create the database.
        // TODO: Handle database initialisation errors #143
        //       https://github.com/inseven/bookmarks/issues/143
        print("Opening database at '\(Database.sharedStoreURL.absoluteString)'...")
        database = try! Database(path: Database.sharedStoreURL)

        imageCache = FileImageCache(path: documentsURL.appendingPathComponent("thumbnails"))
        downloadManager = DownloadManager(limit: settings.maximumConcurrentThumbnailDownloads)
        thumbnailManager = ThumbnailManager(imageCache: imageCache, downloadManager: downloadManager)
        store = Store(database: database, settings: settings)
        tagsModel = TagsModel(database: database)

        store.delegate = self
        store.start()
        tagsModel.start()

        #if os(macOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(nsApplicationDidBecomeActive),
                                       name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),
                                       object: nil)
        #endif
    }

    public var user: String? {
        return settings.user
    }

    public func start() {

        // Fetch the top n tags.
        tagsModel
            .$tags
            .combineLatest(settings.$favoriteTags, settings.$topTagsCount)
            .receive(on: DispatchQueue.global())
            .map { tags, favoriteTags, topTagsCount in
                guard topTagsCount > 0 else {
                    return []
                }
                return tags
                    .filter { !favoriteTags.contains($0.name) }
                    .sorted { $0.count > $1.count || $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                    .prefix(topTagsCount)
                    .map { $0.name }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.topTags, on: self)
            .store(in: &cancellables)

        Task {
            let iconURLVersion = 2
            do {
                // TODO: Rename identifiers
                // TODO: Would it be better if this accepted an expression that matched the model?
                for try await var bookmark in database.identifiers(query: IconURLVersionLessThan(iconURLVersion)) {
                    print("Processing icon URL for '\(bookmark.url)'...")
                    bookmark.iconURL = bookmark.url.faviconURL
                    bookmark.iconURLVersion = iconURLVersion
                    try await database.insertOrUpdate(bookmark: bookmark)
                }
                assertionFailure("Background processor iterator failed unexpectedly.")
            } catch {
                assertionFailure("Background processor iterator failed unexpectedly with error \(error).")
            }
        }
    }

    public func authenticate(username: String,
                             password: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        store.authenticate(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.state = .idle
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        let completion = DispatchQueue.global().asyncClosure(completion)
        store.logout { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.state = .unauthorized
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func refresh() async {
        return await withCheckedContinuation { continuation in
            store.refresh(force: true) { error in
                // N.B. We ignore the error here as it is currently handled via the delegate callback mechanism.
                continuation.resume()
            }
        }
    }
    
    public func delete(bookmarks: [Bookmark]) async throws {
        try await store.delete(bookmarks: bookmarks)
    }

    public func update(bookmarks: [Bookmark]) async throws {
        try await store.update(bookmarks: bookmarks)
    }

    public func rename(tag: String, to newTag: String) async throws {
        try await store.rename(tag: tag, to: newTag)
    }

    public func delete(tags: [String]) async throws {
        try await store.delete(tags: tags)
    }

    @MainActor public func open(_ bookmarks: Set<Bookmark>,
                                location: Bookmark.Location = .web) {
        open(Array(bookmarks), location: location)
    }

    @MainActor public func open(_ bookmarks: [Bookmark], location: Bookmark.Location = .web) {
        do {
            for url in try bookmarks.map({ try $0.url(location) }) {
                Application.open(url)
            }
        } catch {
            print("Failed to open bookmarks with error \(error)")
        }
    }

    @MainActor public func isFavorite(_ tag: String) -> Bool {
        return settings.favoriteTags.contains(tag)
    }

    @MainActor public func removeFavorite(_ tag: String) {
        settings.favoriteTags = settings.favoriteTags.filter { $0 != tag }
    }

    @MainActor public func addFavorite(_ tag: String) {
        settings.favoriteTags.append(tag)
    }

    @objc func nsApplicationDidBecomeActive() {
        self.store.refresh()
    }

}

extension ApplicationModel: StoreDelegate {

    func store(_ store: Store, didProgress progress: Progress) {
        Task { @MainActor in
            self.progress = progress
            switch progress {
            case .idle, .active, .value:
                break
            case .done(let date):
                print("Completed at \(date).")
            case .failure(let error):
                switch error {
                case BookmarksError.httpError(.unauthorized), BookmarksError.unauthorized:
                    self.state = .unauthorized
                default:
                    break
                }
            }
        }
    }

}
