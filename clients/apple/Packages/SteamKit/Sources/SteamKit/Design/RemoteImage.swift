import ImageIO
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Decoded, Sendable wrapper around a CGImage.
public struct DecodedImage: @unchecked Sendable {
    public let cgImage: CGImage
    public var size: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }
}

/// Loads faster than this (disk-cache hits) appear without a fade.
private let fadeThreshold = Duration.milliseconds(120)

/// Tiny image pipeline: disk cache via a large `URLCache`, in-memory cache of decoded
/// (and downsampled) bitmaps, request coalescing, decoding off the main thread.
@MainActor
public final class ImagePipeline {
    public static let shared = ImagePipeline()

    private let session: URLSession
    private let memory = NSCache<NSString, Box>()
    private var inFlight: [String: Task<DecodedImage?, Never>] = [:]

    private final class Box {
        let image: DecodedImage
        init(_ image: DecodedImage) { self.image = image }
    }

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let cache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 1024 * 1024 * 1024,
            directory: caches?.appendingPathComponent("NativeSteamImages", isDirectory: true)
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        // Steam CDN URLs are versioned (`?t=`), so cached data never goes stale.
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 8
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        memory.totalCostLimit = 384 * 1024 * 1024
    }

    private static func key(_ url: String, _ maxPixel: Int) -> String { "\(maxPixel)|\(url)" }

    public func cached(_ url: String, maxPixel: Int) -> DecodedImage? {
        memory.object(forKey: Self.key(url, maxPixel) as NSString)?.image
    }

    public func load(_ url: String, maxPixel: Int) async -> DecodedImage? {
        let key = Self.key(url, maxPixel)
        if let hit = memory.object(forKey: key as NSString) { return hit.image }
        if let task = inFlight[key] { return await task.value }
        guard let u = URL(string: url) else { return nil }
        let session = self.session
        let task = Task<DecodedImage?, Never> {
            do {
                let (data, response) = try await session.data(from: u)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
                return await Self.decode(data, maxPixel: maxPixel)
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result {
            memory.setObject(Box(result), forKey: key as NSString, cost: result.cgImage.bytesPerRow * result.cgImage.height)
        }
        return result
    }

    @concurrent
    nonisolated private static func decode(_ data: Data, maxPixel: Int) async -> DecodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return DecodedImage(cgImage: image)
    }
}

/// Async artwork with a surface-coloured placeholder (optionally showing a title),
/// aspect-fill + clip. Size it from the outside (frame / aspectRatio).
public struct RemoteImage: View {
    let url: String?
    var maxPixel: Int
    var placeholderTitle: String?
    var placeholderColor: Color
    var contentMode: ContentMode

    @State private var image: DecodedImage?
    @State private var failed = false

    public init(
        _ url: String?,
        maxPixel: Int = 1000,
        placeholder title: String? = nil,
        placeholderColor: Color = Steam.surface,
        contentMode: ContentMode = .fill
    ) {
        self.url = url
        self.maxPixel = maxPixel
        self.placeholderTitle = title
        self.placeholderColor = placeholderColor
        self.contentMode = contentMode
        if let url {
            _image = State(initialValue: ImagePipeline.shared.cached(url, maxPixel: maxPixel))
        }
    }

    public var body: some View {
        Rectangle()
            .fill(placeholderColor)
            .overlay {
                if let image {
                    Image(decorative: image.cgImage, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else if let placeholderTitle {
                    Text(placeholderTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Steam.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(8)
                }
            }
            .clipped()
            .task(id: url) {
                guard let url else { return }
                if let hit = ImagePipeline.shared.cached(url, maxPixel: maxPixel) {
                    image = hit
                    return
                }
                let started = ContinuousClock.now
                let loaded = await ImagePipeline.shared.load(url, maxPixel: maxPixel)
                // Fade in only when the image actually kept the user waiting; disk-cache
                // hits land within a few frames and should just appear.
                withAnimation(ContinuousClock.now - started > fadeThreshold ? .easeOut(duration: 0.2) : nil) {
                    image = loaded
                    failed = loaded == nil
                }
            }
            .accessibilityHidden(placeholderTitle == nil)
    }
}

/// Transparent logo image that keeps its own aspect ratio (no placeholder fill).
public struct LogoImage: View {
    let url: String?
    let fallbackTitle: String
    var maxPixel: Int = 900
    var alignment: Alignment = .bottomLeading
    var titleSize: CGFloat = 34

    @State private var image: DecodedImage?
    @State private var resolved = false

    public init(_ url: String?, fallbackTitle: String, maxPixel: Int = 900, alignment: Alignment = .bottomLeading, titleSize: CGFloat = 34) {
        self.url = url
        self.fallbackTitle = fallbackTitle
        self.maxPixel = maxPixel
        self.alignment = alignment
        self.titleSize = titleSize
        if let url, let hit = ImagePipeline.shared.cached(url, maxPixel: maxPixel) {
            _image = State(initialValue: hit)
            _resolved = State(initialValue: true)
        }
    }

    public var body: some View {
        ZStack(alignment: alignment) {
            Color.clear
            if let image {
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .shadow(color: .black.opacity(0.55), radius: 12, y: 2)
                    .transition(.opacity)
            } else if resolved || url == nil {
                Text(fallbackTitle)
                    .font(.system(size: titleSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
        }
        .task(id: url) {
            guard let url, image == nil else { return }
            let started = ContinuousClock.now
            let loaded = await ImagePipeline.shared.load(url, maxPixel: maxPixel)
            withAnimation(ContinuousClock.now - started > fadeThreshold ? .easeOut(duration: 0.2) : nil) {
                image = loaded
                resolved = true
            }
        }
        .accessibilityLabel(fallbackTitle)
    }
}
