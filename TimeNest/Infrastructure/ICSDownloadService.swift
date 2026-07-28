import Foundation

/// Shared ICS body decoder used by validation and parsing.
///
/// RFC 5545 content is commonly UTF-8, while some legacy feeds still use
/// ISO-8859-1. Keeping this policy in one place prevents validation from
/// accepting data that the parser cannot decode.
enum ICSContentDecoder {
    static func decode(_ data: Data) throws -> String {
        if let utf8Content = String(data: data, encoding: .utf8) {
            return utf8Content
        }
        if let latin1Content = String(data: data, encoding: .isoLatin1) {
            return latin1Content
        }
        throw EnhancedICSError.invalidEncoding
    }
}

/// ICS 下载/解析错误类型
enum EnhancedICSError: Error, LocalizedError {
    case invalidURL
    case unsupportedScheme
    case networkError(Error)
    case invalidHTTPStatus(Int)
    case emptyResponse
    case invalidEncoding
    case invalidICSContent
    case noEvents
    case parseFailed(String)
    case tooLarge(size: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return LocalizationManager.shared.localized(.icsErrorInvalidURL)
        case .unsupportedScheme:
            return LocalizationManager.shared.localized(.icsErrorUnsupportedScheme)
        case .networkError(let error):
            return String(format: LocalizationManager.shared.localized(.icsErrorNetwork), error.localizedDescription)
        case .invalidHTTPStatus(let statusCode):
            return String(format: LocalizationManager.shared.localized(.icsErrorInvalidHTTPStatus), statusCode)
        case .emptyResponse:
            return LocalizationManager.shared.localized(.icsErrorEmptyResponse)
        case .invalidEncoding:
            return LocalizationManager.shared.localized(.icsErrorInvalidEncoding)
        case .invalidICSContent:
            return LocalizationManager.shared.localized(.icsErrorInvalidContent)
        case .noEvents:
            return LocalizationManager.shared.localized(.icsErrorNoEvents)
        case .parseFailed(let reason):
            return String(format: LocalizationManager.shared.localized(.icsErrorParseFailed), reason)
        case .tooLarge(let size, let limit):
            return String(format: LocalizationManager.shared.localized(.icsErrorTooLarge), size, limit)
        }
    }
}

/// ICS 下载服务协议
protocol ICSDownloading {
    func download(from url: URL, timeout: TimeInterval, region: String?, host: String?) async throws -> Data
    func validateURL(_ urlString: String) throws
    func validateICSContent(_ data: Data) throws
}

/// ICS 下载服务实现
class ICSDownloadService: ICSDownloading {

    // 最大文件大小限制 (10MB)
    private let maxFileSize: Int = 10 * 1024 * 1024

    // App Store/ATS 向けに、外部 ICS 取得は HTTPS のみに制限します。
    private let allowedSchemes = ["https"]

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 验证 URL 格式
    func validateURL(_ urlString: String) throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EnhancedICSError.invalidURL
        }

        guard let url = URL(string: trimmed) else {
            throw EnhancedICSError.invalidURL
        }

        guard let scheme = url.scheme, allowedSchemes.contains(scheme.lowercased()) else {
            throw EnhancedICSError.unsupportedScheme
        }
    }

    /// 验证 ICS 内容是否有效（基于 body 内容）
    func validateICSContent(_ data: Data) throws {
        guard !data.isEmpty else {
            throw EnhancedICSError.emptyResponse
        }

        let body = try ICSContentDecoder.decode(data)

        // 检查是否包含 iCalendar 必需的结构
        if !body.contains("BEGIN:VCALENDAR") || !body.contains("END:VCALENDAR") {
            throw EnhancedICSError.invalidICSContent
        }

        // 检查是否包含至少一个 VEVENT
        if !body.contains("BEGIN:VEVENT") {
            throw EnhancedICSError.noEvents
        }
    }

    /// 下载 ICS 数据（内部方法，带 headers 的单个请求）
    private func fetchICS(from url: URL, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        // 设置请求头，使其更像浏览器/日历客户端
        request.setValue("TimeNest/1.0 iOS Calendar Client", forHTTPHeaderField: "User-Agent")
        request.setValue("text/calendar, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("ja,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancedICSError.emptyResponse
        }

        if httpResponse.expectedContentLength > Int64(maxFileSize) {
            throw EnhancedICSError.tooLarge(
                size: Int(httpResponse.expectedContentLength),
                limit: maxFileSize
            )
        }

        // Apply the same limit to every HTTP response, including non-2xx
        // responses. URLSession.data(for:) buffers the body before this check;
        // strict streaming limits are intentionally outside this minimal fix.
        if data.count > maxFileSize {
            throw EnhancedICSError.tooLarge(size: data.count, limit: maxFileSize)
        }

        return (data, httpResponse)
    }

    /// 下载 ICS 数据
    func download(from url: URL, timeout: TimeInterval = 30, region: String? = nil, host: String? = nil) async throws -> Data {
        // 验证 URL scheme
        guard let scheme = url.scheme, allowedSchemes.contains(scheme.lowercased()) else {
            throw EnhancedICSError.unsupportedScheme
        }

        do {
            let (data, httpResponse) = try await fetchICS(from: url, timeout: timeout)

            // 检查 HTTP 状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                throw EnhancedICSError.invalidHTTPStatus(httpResponse.statusCode)
            }

            return data

        } catch let error as EnhancedICSError {
            throw error
        } catch let error as URLError {
            throw EnhancedICSError.networkError(error)
        } catch {
            throw EnhancedICSError.networkError(error)
        }
    }

    /// 验证 URL 字符串是否有效
    func isValidURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme,
              allowedSchemes.contains(scheme.lowercased()) else {
            return false
        }
        return true
    }
}
