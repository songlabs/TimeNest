import Foundation

/// ICS 下载错误
enum ICSDownloadError: Error {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int)
    case timeout
    case invalidResponse
    case tooLarge(size: Int, limit: Int)
    case unsupportedScheme(String)

    var errorMessage: String {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .networkError:
            return "网络错误"
        case .httpError(let code):
            return "HTTP 错误：\(code)"
        case .timeout:
            return "请求超时"
        case .invalidResponse:
            return "无效的响应"
        case .tooLarge(let size, let limit):
            return "文件大小超出限制 (\(size) bytes > \(limit) bytes)"
        case .unsupportedScheme(let scheme):
            return "不支持的 URL 方案：\(scheme)"
        }
    }
}

/// 增强错误消息的包装器
struct EnhancedICSError: Error {
    let error: ICSDownloadError
    let region: String?
    let host: String?

    var localizedDescription: String {
        var parts: [String] = []

        if let region = region, !region.isEmpty {
            parts.append(region)
        }

        parts.append(error.errorMessage)

        if let host = host, !host.isEmpty {
            parts.append(host)
        }

        return parts.joined(separator: "\n")
    }
}

/// ICS 下载服务协议
protocol ICSDownloading {
    func download(from url: URL, timeout: TimeInterval, region: String?, host: String?) async throws -> Data
    func validateURL(_ urlString: String) throws
}

/// ICS 下载服务实现
class ICSDownloadService: ICSDownloading {

    // 默认超时时间
    private let defaultTimeout: TimeInterval = 30

    // 最大文件大小限制 (10MB)
    private let maxFileSize: Int = 10 * 1024 * 1024

    // 只允许 https
    private let allowedSchemes = ["https"]

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 验证 URL
    func validateURL(_ urlString: String) throws {
        guard let url = URL(string: urlString) else {
            throw ICSDownloadError.invalidURL
        }

        // 检查 scheme
        guard let scheme = url.scheme, allowedSchemes.contains(scheme.lowercased()) else {
            throw ICSDownloadError.unsupportedScheme(urlString)
        }

        // 检查 URL 是否为空
        if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ICSDownloadError.invalidURL
        }
    }

    /// 下载 ICS 数据
    func download(from url: URL, timeout: TimeInterval = 30, region: String? = nil, host: String? = nil) async throws -> Data {
        // 验证 URL scheme
        guard let scheme = url.scheme, allowedSchemes.contains(scheme.lowercased()) else {
            throw EnhancedICSError(error: .unsupportedScheme(url.absoluteString), region: region, host: host)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        // 设置 User-Agent
        request.setValue("TimeNest/1.0 (iOS Calendar)", forHTTPHeaderField: "User-Agent")
        request.setValue("accept: text/calendar", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            // 检查 HTTP 状态码
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw EnhancedICSError(error: .httpError(statusCode: httpResponse.statusCode), region: region, host: host)
                }
            }

            // 检查文件大小
            if data.count > maxFileSize {
                throw EnhancedICSError(error: .tooLarge(size: data.count, limit: maxFileSize), region: region, host: host)
            }

            return data

        } catch let error as URLError {
            let downloadError: ICSDownloadError
            switch error.code {
            case .timedOut:
                downloadError = .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                downloadError = .networkError(error)
            default:
                downloadError = .networkError(error)
            }
            throw EnhancedICSError(error: downloadError, region: region, host: host)
        } catch {
            throw EnhancedICSError(error: .networkError(error), region: region, host: host)
        }
    }

    /// 验证 URL 字符串是否有效
    func isValidURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              allowedSchemes.contains(scheme.lowercased()) else {
            return false
        }
        return true
    }
}
