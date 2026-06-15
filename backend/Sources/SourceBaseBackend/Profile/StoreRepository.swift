import Foundation
import Supabase

public struct StoreProductSnapshot: Sendable {
    public let code: String
    public let coin: Int
    public let priceCents: Int
    public let title: String
    public let description: String
    public let currency: String
    public let sortOrder: Int

    public init(
        code: String,
        coin: Int,
        priceCents: Int,
        title: String,
        description: String,
        currency: String,
        sortOrder: Int
    ) {
        self.code = code
        self.coin = coin
        self.priceCents = priceCents
        self.title = title
        self.description = description
        self.currency = currency
        self.sortOrder = sortOrder
    }
}

public struct StoreRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadProducts() async throws -> [StoreProductSnapshot] {
        let attempts: [ProductTableAttempt] = [
            ProductTableAttempt(table: "store_products", schema: nil, filterKey: "is_active", filterValue: .bool(true)),
            ProductTableAttempt(table: "products", schema: nil, filterKey: "status", filterValue: .string("published")),
            ProductTableAttempt(table: "store_products", schema: "sourcebase", filterKey: "is_active", filterValue: .bool(true)),
            ProductTableAttempt(table: "products", schema: "sourcebase", filterKey: "status", filterValue: .string("published"))
        ]

        var lastError: Error?
        for attempt in attempts {
            do {
                let rows = try await loadRows(attempt)
                let snapshots = rows.map { $0.toSnapshot() }
                let products = snapshots
                    .filter { product in
                        !product.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && product.coin > 0
                    }
                    .sorted { lhs, rhs in
                        lhs.sortOrder == rhs.sortOrder
                            ? lhs.coin < rhs.coin
                            : lhs.sortOrder < rhs.sortOrder
                    }
                if !products.isEmpty {
                    return products
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        return []
    }

    public func purchaseMedasiCoin(
        productCode: String,
        successURL: String,
        cancelURL: String
    ) async throws -> [String: AnyJSON] {
        try await DriveRepository(api: DriveAPI(client: client)).purchaseMedasiCoin(
            productCode: productCode,
            successURL: successURL,
            cancelURL: cancelURL
        )
    }

    private func loadRows(_ attempt: ProductTableAttempt) async throws -> [StoreProductRow] {
        let builder = attempt.schema.map { client.schema($0).from(attempt.table) }
            ?? client.from(attempt.table)

        switch attempt.filterValue {
        case .bool(let value):
            return try await builder
                .select()
                .eq(attempt.filterKey, value: value)
                .execute()
                .value
        case .string(let value):
            return try await builder
                .select()
                .eq(attempt.filterKey, value: value)
                .execute()
                .value
        }
    }
}

private struct ProductTableAttempt: Sendable {
    enum FilterValue: Sendable {
        case bool(Bool)
        case string(String)
    }

    let table: String
    let schema: String?
    let filterKey: String
    let filterValue: FilterValue
}

private struct StoreProductRow: Decodable, Sendable {
    let code: String?
    let slug: String?
    let productCode: String?
    let coins: Int
    let priceCents: Int
    let title: String?
    let name: String?
    let description: String?
    let currency: String?
    let sortOrder: Int
    let metadata: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case code
        case slug
        case productCode = "product_code"
        case coins
        case coin
        case coinAmount = "coin_amount"
        case amount
        case mcAmount = "mc_amount"
        case medasiCoinAmount = "medasicoin_amount"
        case priceCents = "price_cents"
        case price
        case unitAmount = "unit_amount"
        case title
        case name
        case description
        case currency
        case sortOrder = "sort_order"
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        productCode = try container.decodeIfPresent(String.self, forKey: .productCode)
        metadata = (try? container.decodeIfPresent([String: AnyJSON].self, forKey: .metadata)) ?? [:]
        coins = Self.decodeInt(container, .coins)
            ?? Self.decodeInt(container, .coin)
            ?? Self.decodeInt(container, .coinAmount)
            ?? Self.decodeInt(container, .mcAmount)
            ?? Self.decodeInt(container, .medasiCoinAmount)
            ?? Self.decodeInt(container, .amount)
            ?? Self.metadataInt(metadata, "coin_amount")
            ?? Self.metadataInt(metadata, "coins")
            ?? Self.metadataInt(metadata, "medasicoin_amount")
            ?? 0
        priceCents = Self.decodeInt(container, .priceCents)
            ?? Self.decodePriceAsCents(container, .price)
            ?? Self.decodeInt(container, .unitAmount)
            ?? Self.metadataInt(metadata, "price_cents")
            ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        sortOrder = Self.decodeInt(container, .sortOrder) ?? Self.metadataInt(metadata, "sort_order") ?? 99
    }

    func toSnapshot() -> StoreProductSnapshot {
        StoreProductSnapshot(
            code: productCode ?? code ?? slug ?? "",
            coin: coins,
            priceCents: priceCents,
            title: title ?? name ?? Self.metadataString(metadata, "title") ?? "\(coins) MC Paketi",
            description: description ?? Self.metadataString(metadata, "description") ?? "MC onaylı ödeme sonrası hesabınıza eklenir.",
            currency: currency ?? Self.metadataString(metadata, "currency") ?? "TRY",
            sortOrder: sortOrder
        )
    }

    private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    private static func decodePriceAsCents(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int((value * 100).rounded())
        }
        if let value = try? container.decode(String.self, forKey: key),
           let numeric = Double(value.replacingOccurrences(of: ",", with: ".")) {
            return Int((numeric * 100).rounded())
        }
        return nil
    }

    private static func metadataInt(_ metadata: [String: AnyJSON], _ key: String) -> Int? {
        guard let value = metadata[key] else { return nil }
        switch value {
        case .integer(let raw): return raw
        case .double(let raw): return Int(raw)
        case .string(let raw): return Int(raw)
        default: return nil
        }
    }

    private static func metadataString(_ metadata: [String: AnyJSON], _ key: String) -> String? {
        guard let value = metadata[key] else { return nil }
        switch value {
        case .string(let raw): return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        case .integer(let raw): return String(raw)
        case .double(let raw): return String(raw)
        default: return nil
        }
    }
}
