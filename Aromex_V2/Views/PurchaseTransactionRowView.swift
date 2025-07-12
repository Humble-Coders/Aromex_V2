//
//  PurchaseTransactionRowView.swift
//  Aromex_V2
//
//  Created by Ansh Bajaj on 12/07/25.
//


import SwiftUI
import FirebaseFirestore

struct PurchaseTransactionRowView: View {
    let purchaseTransaction: PurchaseTransaction
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var navigationManager: CustomerNavigationManager
    
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
    }
    
    private func navigateToSupplier() {
        guard let supplierId = purchaseTransaction.supplierId else { return }
        
        // Find the supplier in the firebaseManager
        if let supplier = firebaseManager.customers.first(where: { $0.id == supplierId }) {
            navigationManager.navigateToCustomer(supplier)
        }
    }
}