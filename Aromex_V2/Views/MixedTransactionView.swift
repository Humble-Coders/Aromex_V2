import SwiftUI

struct MixedTransactionView: View {
    let mixedTransaction: AnyMixedTransaction
    
    var body: some View {
        switch mixedTransaction.transactionType {
        case .currency:
            if let currencyTx = mixedTransaction.currencyTransaction {
                TransactionRowView(transaction: currencyTx)
                    .environmentObject(FirebaseManager.shared)
                    .environmentObject(CustomerNavigationManager.shared)
            }
        case .sales:
            if let salesTx = mixedTransaction.transaction as? SalesTransaction {
                SalesTransactionRowView(salesTransaction: salesTx)
                    .environmentObject(FirebaseManager.shared)
                    .environmentObject(CustomerNavigationManager.shared)
            }
        case .purchase:
            if let purchaseTx = mixedTransaction.purchaseTransaction {
                PurchaseTransactionRowView(purchaseTransaction: purchaseTx)
                    .environmentObject(FirebaseManager.shared)
                    .environmentObject(CustomerNavigationManager.shared)
            }
        }
    }
}
