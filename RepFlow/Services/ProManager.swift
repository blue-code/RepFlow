import Foundation
import StoreKit

/// Pro 구독/평생 구매 관리. StoreKit 2 기반.
@Observable
@MainActor
final class ProManager {

    static let shared = ProManager()

    static let monthlyID = "com.digimaru.repflow.pro.monthly"
    static let yearlyID = "com.digimaru.repflow.pro.yearly"
    static let lifetimeID = "com.digimaru.repflow.pro.lifetime"

    private static let allIDs: [String] = [monthlyID, yearlyID, lifetimeID]

    var products: [Product] = []
    var isPro: Bool = false
    var isLoading: Bool = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    nonisolated deinit {
        // Task는 자동으로 취소됨 (객체 라이프사이클 종료 시)
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Self.allIDs)
            // 정렬: 월 → 년 → 평생
            self.products = fetched.sorted { lhs, rhs in
                Self.allIDs.firstIndex(of: lhs.id) ?? 0 < Self.allIDs.firstIndex(of: rhs.id) ?? 0
            }
            await refreshEntitlement()
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, Self.allIDs.contains(tx.productID) {
                if tx.revocationDate == nil {
                    pro = true
                }
            }
        }
        self.isPro = pro
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    isPro = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        if case .verified(let tx) = update {
            await tx.finish()
            await refreshEntitlement()
        }
    }
}
