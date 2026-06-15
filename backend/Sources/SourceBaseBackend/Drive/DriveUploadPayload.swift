import Foundation

public struct PickedDriveFile: Sendable {
    public let name: String
    public let contentType: String
    public let sizeBytes: Int
    public let data: Data?
    public let fileURL: URL?

    public init(name: String, contentType: String, sizeBytes: Int, data: Data) {
        self.name = name
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.data = data
        self.fileURL = nil
    }

    public init(name: String, contentType: String, sizeBytes: Int, fileURL: URL) {
        self.name = name
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.data = nil
        self.fileURL = fileURL
    }

    public var hasSupportedExtension: Bool {
        DriveUploadService.isSupportedFileName(name)
    }

    public var hasReadableContent: Bool {
        sizeBytes > 0 && (data?.isEmpty == false || fileURL != nil)
    }
}
