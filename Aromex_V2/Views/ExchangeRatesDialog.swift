import SwiftUI
import FirebaseFirestore

struct ExchangeRatesDialog: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var currencyManager: CurrencyManager
    
    @State private var updatedRates: [String: String] = [:]
    @State private var isUpdating: Bool = false
    @State private var updateError: String = ""
    @State private var successMessage: String = ""
    
    // Theme colors
    let mainColor = Color(red: 0.23, green: 0.28, blue: 0.42)
    let sectionBg = Color.white
    let fieldCornerRadius: CGFloat = 10
    let fieldHeight: CGFloat = 50
    
    // Responsive properties
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    private var dialogWidth: CGFloat {
        #if os(macOS)
        return 700
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - 40
        } else {
            return min(700, UIScreen.main.bounds.width - 80)
        }
        #endif
    }
    
    private var dialogHeight: CGFloat {
        #if os(macOS)
        return 600
        #else
        if shouldUseVerticalLayout {
            return min(UIScreen.main.bounds.height - 100, 700)
        } else {
            return min(600, UIScreen.main.bounds.height - 100)
        }
        #endif
    }
    
    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        return shouldUseVerticalLayout ? 20 : 24
        #endif
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Exchange Rates")
                    .font(.system(size: shouldUseVerticalLayout ? 24 : 28, weight: .bold, design: .serif))
                    .foregroundColor(mainColor)
                    .padding(.top, shouldUseVerticalLayout ? 16 : 24)
                    .padding(.leading, horizontalPadding)
                    .padding(.bottom, 16)
                
                // Description
                Text("Update exchange rates relative to USD. These rates will be used for profit calculations.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 24)
                
                VStack(spacing: 20) {
                    // CAD Rate (Fixed)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CAD (Canadian Dollar)")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(mainColor)
                            
                            Spacer()
                            
                            Text("Base Currency")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        
                        HStack(spacing: 12) {
                            Text("1 USD =")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 80, alignment: .leading)
                            
                            Text("1.0000")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .frame(height: fieldHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(fieldCornerRadius)
                            
                            Text("CAD")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 60, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    
                    // Other Currencies
                    ForEach(currencyManager.allCurrencies.filter { $0.name != "CAD" }) { currency in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(currency.name)")
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundColor(mainColor)
                                
                                Spacer()
                                
                                Text("\(currency.symbol)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(6)
                            }
                            
                            HStack(spacing: 12) {
                                Text("1 USD =")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 80, alignment: .leading)
                                
                                TextField("Rate", text: Binding(
                                    get: {
                                        if let currencyId = currency.id {
                                            return updatedRates[currencyId] ?? "\(currency.exchangeRate)"
                                        }
                                        return "\(currency.exchangeRate)"
                                    },
                                    set: { newValue in
                                        if let currencyId = currency.id {
                                            updatedRates[currencyId] = newValue
                                        }
                                    }
                                ))
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 16)
                                .frame(height: fieldHeight)
                                .background(sectionBg)
                                .cornerRadius(fieldCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: fieldCornerRadius)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                                )
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                
                                Text(currency.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 60, alignment: .leading)
                            }
                            
                            // Show current vs new rate comparison
                            if let currencyId = currency.id,
                               let newRateText = updatedRates[currencyId],
                               let newRate = Double(newRateText),
                               abs(newRate - currency.exchangeRate) >= 0.0001 {
                                HStack(spacing: 12) {
                                    Text("Current:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(currency.exchangeRate, specifier: "%.4f")")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    
                                    Text("→")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    Text("New:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                    Text("\(newRate, specifier: "%.4f")")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    let difference = newRate - currency.exchangeRate
                                    Text("\(difference > 0 ? "+" : "")\(difference, specifier: "%.4f")")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(difference > 0 ? .green : .red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((difference > 0 ? Color.green : Color.red).opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                }
                
                // Status Messages
                if !updateError.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(updateError)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 16)
                }
                
                if !successMessage.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text(successMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 16)
                }
                
                // Action Buttons
                actionButtons
                    .padding(.top, 32)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBg)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
        )
        .frame(width: dialogWidth, height: dialogHeight)
        .onAppear {
            initializeRates()
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        if shouldUseVerticalLayout {
            VStack(spacing: 12) {
                // Update Rates Button
                Button(action: updateRates) {
                    Text(isUpdating ? "Updating..." : "Update Rates")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(hasChanges() && !isUpdating ? mainColor.opacity(0.97) : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!hasChanges() || isUpdating)
                .buttonStyle(PlainButtonStyle())
                
                // Cancel Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .opacity(isUpdating ? 0.6 : 1)
                }
                .disabled(isUpdating)
                .buttonStyle(PlainButtonStyle())
            }
        } else {
            HStack(spacing: 16) {
                Spacer()
                
                // Cancel Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .frame(width: 120, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .opacity(isUpdating ? 0.6 : 1)
                }
                .disabled(isUpdating)
                .buttonStyle(PlainButtonStyle())
                
                // Update Rates Button
                Button(action: updateRates) {
                    Text(isUpdating ? "Updating..." : "Update Rates")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .frame(width: 140, height: 44)
                        .background(hasChanges() && !isUpdating ? mainColor.opacity(0.97) : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!hasChanges() || isUpdating)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func initializeRates() {
        for currency in currencyManager.allCurrencies {
            if currency.name != "CAD", let currencyId = currency.id {
                updatedRates[currencyId] = "\(currency.exchangeRate)"
            }
        }
    }
    
    private func hasChanges() -> Bool {
        for currency in currencyManager.allCurrencies {
            if currency.name != "CAD",
               let currencyId = currency.id,
               let newRateText = updatedRates[currencyId],
               let newRate = Double(newRateText),
               abs(newRate - currency.exchangeRate) >= 0.0001 {
                return true
            }
        }
        return false
    }
    
    private func updateRates() {
        updateError = ""
        successMessage = ""
        isUpdating = true
        
        let db = Firestore.firestore()
        let batch = db.batch()
        var updatesCount = 0
        
        for currency in currencyManager.allCurrencies {
            if currency.name != "CAD",
               let currencyId = currency.id,
               let newRateText = updatedRates[currencyId],
               let newRate = Double(newRateText),
               newRate > 0,
               abs(newRate - currency.exchangeRate) >= 0.0001 {
                
                let currencyRef = db.collection("Currencies").document(currencyId)
                batch.updateData([
                    "exchangeRate": newRate,
                    "updatedAt": Timestamp()
                ], forDocument: currencyRef)
                updatesCount += 1
            }
        }
        
        guard updatesCount > 0 else {
            isUpdating = false
            updateError = "No valid changes to update."
            return
        }
        
        batch.commit { error in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if let error = error {
                    self.updateError = "Failed to update rates: \(error.localizedDescription)"
                } else {
                    self.successMessage = "Successfully updated \(updatesCount) exchange rate(s)!"
                    
                    // Refresh currency manager data
                    self.currencyManager.fetchCurrencies()
                    
                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
