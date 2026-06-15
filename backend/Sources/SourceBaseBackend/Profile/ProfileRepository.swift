import Foundation
import Supabase

public struct ProfileSnapshot: Sendable {
    public let displayName: String
    public let email: String
    public let faculty: String
    public let department: String
    public let className: String
    public let walletBalance: Double?
    public let courseCount: Int
    public let fileCount: Int
    public let generatedCount: Int
    public let collectionCount: Int
    public let avatarURL: String?

    public init(
        displayName: String,
        email: String,
        faculty: String,
        department: String,
        className: String,
        walletBalance: Double?,
        courseCount: Int,
        fileCount: Int,
        generatedCount: Int,
        collectionCount: Int,
        avatarURL: String? = nil
    ) {
        self.displayName = displayName
        self.email = email
        self.faculty = faculty
        self.department = department
        self.className = className
        self.walletBalance = walletBalance
        self.courseCount = courseCount
        self.fileCount = fileCount
        self.generatedCount = generatedCount
        self.collectionCount = collectionCount
        self.avatarURL = avatarURL
    }

    public static let empty = ProfileSnapshot(
        displayName: "", email: "", faculty: "", department: "",
        className: "", walletBalance: nil, courseCount: 0,
        fileCount: 0, generatedCount: 0, collectionCount: 0,
        avatarURL: nil
    )
}

public struct ProfileRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadProfile(
        userId: String,
        workspace: DriveWorkspaceData
    ) async throws -> ProfileSnapshot {
        let row = await loadProfileRow(userId: userId)
        let user = client.auth.currentUser
        let metadata = user?.userMetadata ?? [:]
        let walletBalance = await loadWalletBalance(userId: userId, profileRow: row)

        return ProfileSnapshot(
            displayName: metadata["display_name"]?.stringValue
                ?? metadata["full_name"]?.stringValue
                ?? row?.displayName
                ?? row?.fullName
                ?? user?.email ?? "",
            email: user?.email ?? "",
            faculty: metadata["sourcebase_faculty"]?.stringValue
                ?? row?.sourcebaseFaculty
                ?? row?.faculty
                ?? "",
            department: metadata["sourcebase_department"]?.stringValue
                ?? row?.sourcebaseDepartment
                ?? row?.department
                ?? "",
            className: metadata["sourcebase_class"]?.stringValue
                ?? row?.sourcebaseClass
                ?? row?.classYear
                ?? row?.grade
                ?? "",
            walletBalance: walletBalance,
            courseCount: workspace.courses.count,
            fileCount: workspace.courses.reduce(0) { $0 + $1.fileCount },
            generatedCount: workspace.courses.reduce(0) { sum, course in
                sum + course.sections.reduce(0) { secSum, section in
                    secSum + section.files.reduce(0) { fileSum, file in
                        fileSum + file.generated.count
                    }
                }
            },
            collectionCount: workspace.collections.count,
            avatarURL: metadata["avatar_url"]?.stringValue
                ?? metadata["picture"]?.stringValue
                ?? row?.avatarURL
        )
    }

    public func uploadProfileAvatar(
        data: Data,
        fileName: String,
        contentType: String
    ) async throws -> String {
        let api = DriveAPI(client: client)
        let file = PickedDriveFile(
            name: fileName,
            contentType: contentType,
            sizeBytes: data.count,
            data: data
        )
        let session = try await api.createProfileAvatarUploadSession(
            fileName: fileName,
            contentType: contentType,
            sizeBytes: data.count
        )
        try await DriveUploadService().uploadBytes(
            uploadURL: session.uploadURL,
            headers: session.headers,
            file: file
        )
        let response = try await api.completeProfileAvatarUpload(objectName: session.objectName)
        let dataDict = response["data"]?.dictValue
        let avatarURL = dataDict?["avatarUrl"]?.stringValue
            ?? dataDict?["avatar_url"]?.stringValue
            ?? dataDict?["publicUrl"]?.stringValue
            ?? ""
        guard !avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError(message: "Profil fotoğrafı bağlantısı alınamadı.")
        }
        return avatarURL
    }

    private func loadProfileRow(userId: String) async -> ProfileRow? {
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    private func loadWalletBalance(userId: String, profileRow: ProfileRow?) async -> Double? {
        if let balance = await loadWalletBalanceFromEntitlements(userId: userId) {
            return balance
        }
        return profileRow?.bestBalance
    }

    private func loadWalletBalanceFromEntitlements(userId: String) async -> Double? {
        do {
            let rows: [WalletEntitlementRow] = try await client
                .from("wallet_entitlements")
                .select("remaining_coin_amount")
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .gt("expires_at", value: Date().ISO8601Format())
                .execute()
                .value
            return rows.reduce(0) { $0 + $1.remainingCoinAmount }
        } catch {
            return nil
        }
    }
}

private struct ProfileRow: Decodable, Sendable {
    let displayName: String?
    let fullName: String?
    let faculty: String?
    let department: String?
    let sourcebaseFaculty: String?
    let sourcebaseDepartment: String?
    let sourcebaseClass: String?
    let classYear: String?
    let grade: String?
    let avatarURL: String?
    let creditBalance: Double?
    let walletBalance: Double?
    let medasiCoinBalance: Double?
    let coinBalance: Double?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case fullName = "full_name"
        case faculty
        case department
        case sourcebaseFaculty = "sourcebase_faculty"
        case sourcebaseDepartment = "sourcebase_department"
        case sourcebaseClass = "sourcebase_class"
        case classYear = "class_year"
        case grade
        case avatarURL = "avatar_url"
        case creditBalance = "credit_balance"
        case walletBalance = "wallet_balance"
        case medasiCoinBalance = "medasicoin_balance"
        case coinBalance = "coin_balance"
    }

    var bestBalance: Double? {
        let balances = [medasiCoinBalance, walletBalance, coinBalance, creditBalance]
        for case let balance? in balances where balance != 0 {
            return balance
        }
        return balances.contains { $0 == 0 } ? 0 : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        faculty = try container.decodeIfPresent(String.self, forKey: .faculty)
        department = try container.decodeIfPresent(String.self, forKey: .department)
        sourcebaseFaculty = try container.decodeIfPresent(String.self, forKey: .sourcebaseFaculty)
        sourcebaseDepartment = try container.decodeIfPresent(String.self, forKey: .sourcebaseDepartment)
        sourcebaseClass = try container.decodeIfPresent(String.self, forKey: .sourcebaseClass)
        classYear = try container.decodeIfPresent(String.self, forKey: .classYear)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        creditBalance = Self.decodeDouble(container, .creditBalance)
        walletBalance = Self.decodeDouble(container, .walletBalance)
        medasiCoinBalance = Self.decodeDouble(container, .medasiCoinBalance)
        coinBalance = Self.decodeDouble(container, .coinBalance)
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}

private struct WalletEntitlementRow: Decodable, Sendable {
    let remainingCoinAmount: Double

    enum CodingKeys: String, CodingKey {
        case remainingCoinAmount = "remaining_coin_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remainingCoinAmount = Self.decodeDouble(container, .remainingCoinAmount)
            ?? 0
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}
