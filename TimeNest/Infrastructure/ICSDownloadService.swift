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
    case parseFailed(String)
    case tooLarge(size: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL が正しくありません。"
        case .unsupportedScheme:
            return "HTTPS または HTTP の URL を入力してください。"
        case .networkError(let error):
            return "ICS の取得に失敗しました：\(error.localizedDescription)"
        case .invalidHTTPStatus(let statusCode):
            return "ICS の取得に失敗しました。HTTP ステータス：\(statusCode)"
        case .emptyResponse:
            return "ICS データが空です。"
        case .invalidEncoding:
            return "ICS データの文字コードを読み取れませんでした。"
        case .invalidICSContent:
            return "取得したデータが有効な iCalendar 形式ではありません。"
        case .parseFailed(let reason):
            return "ICS の解析に失敗しました：\(reason)"
        case .tooLarge(let size, let limit):
            return "ICS サイズが大きすぎます（\(size) bytes > \(limit) bytes）"
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

    // 允许 http 和 https
    private let allowedSchemes = ["https", "http"]

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
            return
        }

        // 检查是否包含 iCalendar 必需的结构
        if !body.contains("BEGIN:VCALENDAR") || !body.contains("END:VCALENDAR") {
            throw EnhancedICSError.invalidICSContent
        }
    }

    /// 下载 ICS 数据
    func download(from url: URL, timeout: TimeInterval = 30, region: String? = nil, host: String? = nil) async throws -> Data {
        // 验证 URL scheme
        guard let scheme = url.scheme, allowedSchemes.contains(scheme.lowercased()) else {
            throw EnhancedICSError.unsupportedScheme
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        // 设置 User-Agent
        request.setValue("TimeNest/1.0 (iOS Calendar)", forHTTPHeaderField: "User-Agent")
        request.setValue("accept: text/calendar, */*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            // 检查响应
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[ICSDownload] 无效的响应类型: \(type(of: response))")
                throw EnhancedICSError.emptyResponse
            }

            // 检查 HTTP 状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                print("[ICSDownload] HTTP 错误：\(httpResponse.statusCode)")
                throw EnhancedICSError.invalidHTTPStatus(httpResponse.statusCode)
            }

            // 检查文件大小
            if data.count > maxFileSize {
                print("[ICSDownload] 文件过大：\(data.count) bytes")
                throw EnhancedICSError.tooLarge(size: data.count, limit: maxFileSize)
            }

            // DEBUG 日志
            #if DEBUG
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "nil"
            let bodyPrefix = String(data: data.prefix(200), encoding: .utf8) ?? ""
            print("[ICSDownload] inputURL = \(url.absoluteString)")
            print("[ICSDownload] finalURL = \(httpResponse.url?.absoluteString ?? "nil")")
            print("[ICSDownload] statusCode = \(httpResponse.statusCode)")
            print("[ICSDownload] contentType = \(contentType)")
            print("[ICSDownload] dataSize = \(data.count)")
            print("[ICSDownload] bodyPrefix = \(bodyPrefix)")
            #endif

            return data

        } catch let error as URLError {
            print("[ICSDownload] URLError: \(error.code) - \(error.localizedDescription)")
            throw EnhancedICSError.networkError(error)
        } catch {
            print("[ICSDownload] 未知错误：\(error)")
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
