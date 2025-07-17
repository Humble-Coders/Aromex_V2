import SwiftUI
import FirebaseFirestore

struct SalesTransactionRowView: View {
    let salesTransaction: SalesTransaction
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
                Image(systemName: "cart.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                Text("SALES TRANSACTION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let orderNumber = salesTransaction.orderNumber {
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
                    gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
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
                    Text(dateFormatter.string(from: salesTransaction.date.dateValue()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(timeFormatter.string(from: salesTransaction.date.dateValue()))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                    
                    // Payment Source
                    Text(salesTransaction.paymentSource)
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
                
                // COLUMN 2: Customer & Financial Details
                VStack(alignment: .leading, spacing: 16) {
                    // Customer Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customer")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            navigateToCustomer()
                        }) {
                            Text(salesTransaction.customerName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.purple)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(salesTransaction.customerId == nil)
                    }
                    
                    // Financial Summary
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(salesTransaction.total, specifier: "%.2f")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Paid")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(salesTransaction.paid, specifier: "%.2f")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Credit")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(salesTransaction.credit, specifier: "%.2f")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 280, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 3: Tax & Supplier Info
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
                                Text("\(salesTransaction.gst, specifier: "%.1f")%")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PST")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(salesTransaction.pst, specifier: "%.1f")%")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Supplier Information
                    if let supplierName = salesTransaction.supplierName, !supplierName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Supplier")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(supplierName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(width: 160, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 4: Middleman Info (if exists)
                VStack(alignment: .leading, spacing: 12) {
                    if salesTransaction.middlemanId != nil {
                        Text("Middleman")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if let mTotal = salesTransaction.mTotal {
                                HStack(spacing: 4) {
                                    Text("Total:")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("$\(mTotal, specifier: "%.2f")")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if let mPaid = salesTransaction.mPaid {
                                HStack(spacing: 4) {
                                    Text("Paid:")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("$\(mPaid, specifier: "%.2f")")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if let mCredit = salesTransaction.mCredit {
                                HStack(spacing: 4) {
                                    Text("Credit:")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("$\(mCredit, specifier: "%.2f")")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("No Middleman")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                .frame(width: 140, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 5: Phones & Additional Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if !salesTransaction.phones.isEmpty {
                        Text("\(salesTransaction.phones.count) phone(s)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text("No items")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    if let originalPrice = salesTransaction.originalPrice {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Original Price")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("$\(originalPrice, specifier: "%.2f")")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
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
                .shadow(color: .purple.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .alert("Delete Sales Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSalesTransaction()
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Are you sure you want to delete this sales transaction?")
                Text("This will:")
                Text("• Delete the sales record")
                Text("• Reverse customer balance changes")
                Text("• Reverse middleman balance changes (if applicable)")
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func navigateToCustomer() {
        guard let customerId = salesTransaction.customerId else { return }
        
        if let customer = firebaseManager.customers.first(where: { $0.id == customerId }) {
            navigationManager.navigateToCustomer(customer)
        }
    }
    
    private func deleteSalesTransaction() {
        isDeleting = true
        deleteError = ""
        
        Task {
            do {
                try await reverseSalesTransaction()
                
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
    
    private func reverseSalesTransaction() async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        print("🔄 Starting sales transaction reversal for ID: \(salesTransaction.id ?? "unknown")")
        print("📊 Sales details: Customer: \(salesTransaction.customerName), Credit: \(salesTransaction.credit)")
        
        // Step 1: Reverse customer balance (customer received credit, so SUBTRACT it)
        if let customerId = salesTransaction.customerId, salesTransaction.credit != 0 {
            try await reverseCustomerBalance(
                customerId: customerId,
                amount: salesTransaction.credit,
                batch: batch,
                isSubtraction: true  // Remove the credit they received
            )
            print("🔄 Reversed customer balance: -\(salesTransaction.credit)")
        }
        
        // Step 2: Reverse middleman balance (if applicable - middleman received credit, so SUBTRACT it)
        if let middlemanId = salesTransaction.middlemanId, let mCredit = salesTransaction.mCredit, mCredit != 0 {
            try await reverseCustomerBalance(
                customerId: middlemanId,
                amount: mCredit,
                batch: batch,
                isSubtraction: true  // Remove the credit they received
            )
            print("🔄 Reversed middleman balance: -\(mCredit)")
        }
        
        // Step 3: Delete the sales transaction record
        if let transactionId = salesTransaction.id {
            let transactionRef = db.collection("Sales").document(transactionId)
            batch.deleteDocument(transactionRef)
        }
        
        // Step 4: Commit all changes
        try await batch.commit()
        print("✅ Sales transaction reversal completed successfully")
    }
    
    private func reverseCustomerBalance(customerId: String, amount: Double, batch: WriteBatch, isSubtraction: Bool = false) async throws {
        let db = Firestore.firestore()
        
        // Determine which collection this customer belongs to
        let customerType = try await getCustomerType(customerId: customerId)
        let collectionName = "\(customerType.rawValue)s"
        
        // Reverse CAD balance in the appropriate collection
        let customerRef = db.collection(collectionName).document(customerId)
        
        let customerDoc = try await customerRef.getDocument()
        guard customerDoc.exists else {
            throw NSError(domain: "TransactionError", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(customerType.displayName) not found"])
        }
        
        let currentBalance = customerDoc.data()?["balance"] as? Double ?? 0.0
        let newBalance = isSubtraction ? currentBalance - amount : currentBalance + amount
        
        print("🔄 Reversing \(customerType.displayName) balance: \(currentBalance) \(isSubtraction ? "-" : "+") \(amount) = \(newBalance)")
        batch.updateData(["balance": newBalance, "updatedAt": Timestamp()], forDocument: customerRef)
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
