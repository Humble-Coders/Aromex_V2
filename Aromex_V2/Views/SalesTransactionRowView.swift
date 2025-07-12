//
//  SalesTransactionRowView.swift
//  Aromex_V2
//
//  Created by Ansh Bajaj on 12/07/25.
//


import SwiftUI
import FirebaseFirestore

struct SalesTransactionRowView: View {
    let salesTransaction: SalesTransaction
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
    }
    
    private func navigateToCustomer() {
        guard let customerId = salesTransaction.customerId else { return }
        
        // Find the customer in the firebaseManager
        if let customer = firebaseManager.customers.first(where: { $0.id == customerId }) {
            navigationManager.navigateToCustomer(customer)
        }
    }
}