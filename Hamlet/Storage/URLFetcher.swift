import Foundation

enum URLFetchError: LocalizedError {
    case invalidURL
    case fetchFailed(String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "网址格式不正确"
        case .fetchFailed(let msg): return "抓取失败: \(msg)"
        case .emptyContent: return "未能提取到有效内容"
        }
    }
}

// Structured result of a URL fetch
struct WebPageContent {
    let url: String
    let title: String
    let text: String           // main body text
    let imageURLs: [String]    // found image src values
    let videoURLs: [String]    // found video/iframe src values (YouTube, etc.)
    let audioURLs: [String]    // found audio src values

    // Compact description to pass to AI
    var aiContext: String {
        var parts: [String] = []
        parts.append("[网页: \(url)]")
        if !title.isEmpty { parts.append("标题: \(title)") }
        if !text.isEmpty { parts.append("正文:\n\(text)") }
        if !imageURLs.isEmpty {
            parts.append("图片 (\(imageURLs.count) 张): \(imageURLs.prefix(5).joined(separator: ", "))")
        }
        if !videoURLs.isEmpty {
            parts.append("视频/嵌入内容: \(videoURLs.prefix(3).joined(separator: ", "))")
        }
        if !audioURLs.isEmpty {
            parts.append("音频: \(audioURLs.prefix(3).joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }
}

struct URLFetcher {
    static let shared = URLFetcher()
    private init() {}

    func fetch(from urlString: String) async throws -> WebPageContent {
        guard let url = URL(string: urlString),
              url.scheme == "https" || url.scheme == "http" else {
            throw URLFetchError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLFetchError.fetchFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""

        guard !html.isEmpty else { throw URLFetchError.emptyContent }

        let baseURL = url.scheme.map { "\($0)://\(url.host ?? "")" } ?? urlString
        return parseHTML(html, baseURL: baseURL, originalURL: urlString)
    }

    // Convenience: returns plain text for backward compatibility
    func fetchText(from urlString: String) async throws -> String {
        let page = try await fetch(from: urlString)
        return page.aiContext
    }

    // MARK: - HTML Parsing

    private func parseHTML(_ html: String, baseURL: String, originalURL: String) -> WebPageContent {
        let title = extractTitle(from: html)
        let imageURLs = extractMediaURLs(from: html, baseURL: baseURL,
                                         pattern: #"<img[^>]+src\s*=\s*["']([^"']+)["']"#)
        let videoURLs = extractVideoURLs(from: html, baseURL: baseURL)
        let audioURLs = extractMediaURLs(from: html, baseURL: baseURL,
                                         pattern: #"<(?:audio|source)[^>]+src\s*=\s*["']([^"']+)["']"#)
        let bodyText = extractBodyText(html)

        return WebPageContent(
            url: originalURL,
            title: title,
            text: bodyText,
            imageURLs: imageURLs,
            videoURLs: videoURLs,
            audioURLs: audioURLs
        )
    }

    private func extractTitle(from html: String) -> String {
        let pattern = #"<title[^>]*>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html)
        else { return "" }
        return String(html[range])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractMediaURLs(from html: String, baseURL: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            let src = String(html[r])
            return absoluteURL(src, baseURL: baseURL)
        }
    }

    private func extractVideoURLs(from html: String, baseURL: String) -> [String] {
        var urls: [String] = []

        // <video src=...> and <source src=...> in video context
        let videoPattern = #"<(?:video|source)[^>]+src\s*=\s*["']([^"']+)["']"#
        urls += extractMediaURLs(from: html, baseURL: baseURL, pattern: videoPattern)

        // <iframe src=...> — catches YouTube, Vimeo embeds
        let iframePattern = #"<iframe[^>]+src\s*=\s*["']([^"']+)["']"#
        let iframeURLs = extractMediaURLs(from: html, baseURL: baseURL, pattern: iframePattern)
            .filter { url in
                let lower = url.lowercased()
                return lower.contains("youtube") || lower.contains("youtu.be")
                    || lower.contains("vimeo") || lower.contains("bilibili")
                    || lower.contains("video") || lower.contains("player")
            }
        urls += iframeURLs

        // og:video meta tag
        let ogVideoPattern = #"<meta[^>]+(?:property|name)\s*=\s*["']og:video["'][^>]+content\s*=\s*["']([^"']+)["']"#
        urls += extractMediaURLs(from: html, baseURL: baseURL, pattern: ogVideoPattern)

        return Array(Set(urls)) // deduplicate
    }

    private func absoluteURL(_ src: String, baseURL: String) -> String? {
        let trimmed = src.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("data:") else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.hasPrefix("//") {
            return "https:\(trimmed)"
        }
        if trimmed.hasPrefix("/") {
            return "\(baseURL)\(trimmed)"
        }
        return "\(baseURL)/\(trimmed)"
    }

    // MARK: - Body Text Extraction

    private func extractBodyText(_ html: String) -> String {
        var result = html

        // Remove non-content blocks
        for tag in ["script", "style", "nav", "footer", "header", "aside", "noscript"] {
            result = result.replacingOccurrences(
                of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Strip remaining tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode HTML entities
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")

        // Collapse whitespace
        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Limit to ~3000 chars
        return String(result.prefix(3000))
    }
}
