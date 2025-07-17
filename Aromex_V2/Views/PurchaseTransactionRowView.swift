import SwiftUI
import FirebaseFirestore

struct PurchaseTransactionRowView: View {
    let purchaseTransaction: PurchaseTransaction
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var navigationManager: CustomerNavigationManager
    
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError = ""
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Badge
            HStack {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                Text("PURCHASE TRANSACTION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let orderNumber = purchaseTransaction.orderNumber {
                    Text(orderNumber)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Delete Button in Header
                if isDeleting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .foregroundColor(.white)
                } else {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Error Message
            if !deleteError.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text(deleteError)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
            }
            
            // Main Content
            HStack(spacing: 0) {
                // COLUMN 1: Date & Time
                VStack(alignment: .leading, spacing: 8) {
                    Text(dateFormatter.string(from: purchaseTransaction.date.dateValue()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(timeFormatter.string(from: purchaseTransaction.date.dateValue()))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    
                    // Payment Source
                    Text(purchaseTransaction.paymentSource)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .frame(width: 120, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 2: Supplier & Financial Details
                VStack(alignment: .leading, spacing: 16) {
                    // Supplier Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supplier")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            navigateToSupplier()
                        }) {
                            Text(purchaseTransaction.supplierName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(purchaseTransaction.supplierId == nil)
                    }
                    
                    // Financial Summary
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(purchaseTransaction.total, specifier: "%.2f")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Paid")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(purchaseTransaction.paid, specifier: "%.2f")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Credit")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(purchaseTransaction.credit, specifier: "%.2f")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 280, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 3: Tax Information
                VStack(alignment: .leading, spacing: 16) {
                    // Tax Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Taxes")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GST")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(purchaseTransaction.gst, specifier: "%.1f")%")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PST")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(purchaseTransaction.pst, specifier: "%.1f")%")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Purchase Type Badge
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Purchase")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                }
                .frame(width: 160, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 4: Purchase Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Purchase Info")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let originalPrice = purchaseTransaction.originalPrice {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Original Price")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(originalPrice, specifier: "%.2f")")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("$\(purchaseTransaction.amount, specifier: "%.2f")")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                .frame(width: 140, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 5: Items & Additional Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if !purchaseTransaction.phones.isEmpty {
                        Text("\(purchaseTransaction.phones.count) phone(s)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text("No items")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Purchase Direction Indicator
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green.opacity(0.7))
                        
                        Text("Incoming")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
                .frame(width: 140, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .background(Color.systemBackgroundColor)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .green.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .alert("Delete Purchase Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePurchaseTransaction()
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Are you sure you want to delete this purchase transaction?")
                Text("This will:")
                Text("• Delete the purchase record")
                Text("• Reverse supplier balance changes")
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func navigateToSupplier() {
        guard let supplierId = purchaseTransaction.supplierId else { return }
        
        if let supplier = firebaseManager.customers.first(where: { $0.id == supplierId }) {
            navigationManager.navigateToCustomer(supplier)
        }
    }
    
    private func deletePurchaseTransaction() {
        isDeleting = true
        deleteError = ""
        
        Task {
            do {
                try await reversePurchaseTransaction()
                
                DispatchQueue.main.async {
                    self.isDeleting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDeleting = false
                    self.deleteError = "Failed to delete"
                }
            }
        }
    }
    
    private func reversePurchaseTransaction() async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        print("🔄 Starting purchase transaction reversal for ID: \(purchaseTransaction.id ?? "unknown")")
        print("📊 Purchase details: Supplier: \(purchaseTransaction.supplierName), Credit: \(purchaseTransaction.credit)")
        
        // Step 1: Reverse supplier balance (supplier was owed money, so ADD back what they're owed)
        // In purchases, credit represents how much we owe the supplier (negative to our balance, positive to theirs)
        if let supplierId = purchaseTransaction.supplierId, purchaseTransaction.credit != 0 {
            try await reverseSupplierBalance(
                supplierId: supplierId,
                amount: purchaseTransaction.credit,
                batch: batch,
                isSubtraction: true  // Remove the debt we owed them
            )
            print("🔄 Reversed supplier balance: -\(purchaseTransaction.credit)")
        }
        
        // Step 2: Delete the purchase transaction record
        if let transactionId = purchaseTransaction.id {
            let transactionRef = db.collection("Purchases").document(transactionId)
            batch.deleteDocument(transactionRef)
        }
        
        // Step 3: Commit all changes
        try await batch.commit()
        print("✅ Purchase transaction reversal completed successfully")
    }
    
    private func reverseSupplierBalance(supplierId: String, amount: Double, batch: WriteBatch, isSubtraction: Bool = false) async throws {
        let db = Firestore.firestore()
        
        // Determine which collection this supplier belongs to
        let customerType = try await getCustomerType(customerId: supplierId)
        let collectionName = "\(customerType.rawValue)s"
        
        // Reverse CAD balance in the appropriate collection
        let supplierRef = db.collection(collectionName).document(supplierId)
        
        let supplierDoc = try await supplierRef.getDocument()
        guard supplierDoc.exists else {
            throw NSError(domain: "TransactionError", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(customerType.displayName) not found"])
        }
        
        let currentBalance = supplierDoc.data()?["balance"] as? Double ?? 0.0
        let newBalance = isSubtraction ? currentBalance - amount : currentBalance + amount
        
        print("🔄 Reversing \(customerType.displayName) balance: \(currentBalance) \(isSubtraction ? "-" : "+") \(amount) = \(newBalance)")
        batch.updateData(["balance": newBalance, "updatedAt": Timestamp()], forDocument: supplierRef)
    }
    
    private func getCustomerType(customerId: String) async throws -> CustomerType {
        let db = Firestore.firestore()
        
        // Check in Customers collection first
        let customersRef = db.collection("Customers").document(customerId)
        let customersDoc = try await customersRef.getDocument()
        if customersDoc.exists {
            return .customer
        }
        
        // Check in Middlemen collection
        let middlemenRef = db.collection("Middlemen").document(customerId)
        let middlemenDoc = try await middlemenRef.getDocument()
        if middlemenDoc.exists {
            return .middleman
        }
        
        // Check in Suppliers collection
        let suppliersRef = db.collection("Suppliers").document(customerId)
        let suppliersDoc = try await suppliersRef.getDocument()
        if suppliersDoc.exists {
            return .supplier
        }
        
        throw NSError(domain: "TransactionError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Customer not found in any collection"])
    }
}
