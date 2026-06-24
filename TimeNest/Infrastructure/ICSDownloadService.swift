import Foundation

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

    // 默认超时时间
    private let defaultTimeout: TimeInterval = 30

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

        // 尝试用 UTF-8 解码
        guard let body = String(data: data, encoding: .utf8) else {
            // 尝试其他常见编码
            guard let bodyAlt = String(data: data, encoding: .isoLatin1) else {
                throw EnhancedICSError.invalidEncoding
            }
            // 使用备用 body 检查
            if !bodyAlt.contains("BEGIN:VCALENDAR") || !bodyAlt.contains("END:VCALENDAR") {
                throw EnhancedICSError.invalidICSContent
            }
            // 检查 VEVENT
            if !bodyAlt.contains("BEGIN:VEVENT") {
                throw EnhancedICSError.noEvents
            }
            return
        }

        // 检查是否包含 iCalendar 必需的结构
        if !body.contains("BEGIN:VCALENDAR") || !body.contains("END:VCALENDAR") {
            throw EnhancedICSError.invalidICSContent
        }

        // 检查是否包含至少一个 VEVENT
        if !body.contains("BEGIN:VEVENT") {
            throw EnhancedICSError.noEvents
        }

        // DEBUG: body 级别日志
    }

    /// 检查是否为 Office Holidays URL
    private func isOfficeHolidaysURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == "www.officeholidays.com" || host == "officeholidays.com"
    }

    /// 生成带 nocache 参数的 fallback URL
    private func appendNoCacheQuery(to url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let timestamp = Int(Date().timeIntervalSince1970)
        let nocacheValue = "\(timestamp)"

        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "nocache", value: nocacheValue))
        components?.queryItems = queryItems

        return components?.url ?? url
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

        return (data, httpResponse)
    }

    /// 下载 ICS 数据
    func download(from url: URL, timeout: TimeInterval = 30, region: String? = nil, host: String? = nil) async throws -> Data {
        // 验证 URL scheme
        guard let scheme = url.scheme, allowedSchemes.contains(scheme.lowercased()) else {
            throw EnhancedICSError.unsupportedScheme
        }

        do {
            // 第一次请求
            let (data, httpResponse) = try await fetchICS(from: url, timeout: timeout)

            // 检查 HTTP 状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                // 对 HTTP 500 增加 Office Holidays fallback
                if httpResponse.statusCode == 500 && isOfficeHolidaysURL(url) {
                    let fallbackURL = appendNoCacheQuery(to: url)

                    // 重试带 nocache 参数的 URL
                    let (retryData, retryHTTPResponse) = try await fetchICS(from: fallbackURL, timeout: timeout)

                    guard (200...299).contains(retryHTTPResponse.statusCode) else {
                        throw EnhancedICSError.invalidHTTPStatus(retryHTTPResponse.statusCode)
                    }

                    return retryData
                }

                throw EnhancedICSError.invalidHTTPStatus(httpResponse.statusCode)
            }

            // 检查文件大小
            if data.count > maxFileSize {
                throw EnhancedICSError.tooLarge(size: data.count, limit: maxFileSize)
            }

            return data

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
