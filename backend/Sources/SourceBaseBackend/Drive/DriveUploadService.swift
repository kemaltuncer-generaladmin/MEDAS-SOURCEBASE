import Foundation

public enum UploadError: Error, Sendable {
    case uploadFailed(statusCode: Int?)
    case timeout
    case noData
}

public struct DriveUploadService: Sendable {

    public init() {}

    public func uploadBytes(
        uploadURL: String,
        headers: [String: String],
        file: PickedDriveFile
    ) async throws {
        guard let url = URL(string: uploadURL) else {
            throw UploadError.uploadFailed(statusCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        var hasContentType = false
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
            if key.lowercased() == "content-type" {
                hasContentType = true
            }
        }

        if !hasContentType && !file.contentType.trimmingCharacters(in: .whitespaces).isEmpty {
            request.setValue(file.contentType, forHTTPHeaderField: "Content-Type")
        }

        request.setValue(String(file.sizeBytes), forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 120

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 120
        config.timeoutIntervalForRequest = 120
        let session = URLSession(configuration: config)

        let response: URLResponse
        if let fileURL = file.fileURL {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            (_, response) = try await session.upload(for: request, fromFile: fileURL)
        } else if let data = file.data {
            (_, response) = try await session.upload(for: request, from: data)
        } else {
            throw UploadError.noData
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UploadError.uploadFailed(
                statusCode: (response as? HTTPURLResponse)?.statusCode
            )
        }
    }

    public static func contentTypeFor(_ fileName: String) -> String {
        switch normalizedExtension(fileName) {
        case "pdf":
            return "application/pdf"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }

    public static let allowedExtensions = ["pdf", "pptx", "docx", "ppt", "doc"]
    public static let supportedExtensionsDisplay = "PDF, PPTX, DOCX, PPT veya DOC"
    public static let primarySupportedExtensionsDisplay = "PDF, PPTX veya DOCX"
    public static let maxSizeBytes: Int = 25 * 1024 * 1024 // 25 MB (matches server MAX_UPLOAD_BYTES)

    public static func isSupportedFileName(_ fileName: String) -> Bool {
        allowedExtensions.contains(normalizedExtension(fileName))
    }

    public static func normalizedExtension(_ fileName: String) -> String {
        URL(fileURLWithPath: fileName).pathExtension.lowercased()
    }
}
