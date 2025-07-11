import SwiftUI
import FirebaseFirestore

struct AddCurrencyDialog: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var currencyManager: CurrencyManager
    
    @State private var currencyName: String = ""
    @State private var currencySymbol: String = ""
    @State private var exchangeRate: String = ""
    @State private var nameError: String = ""
    @State private var symbolError: String = ""
    @State private var rateError: String = ""
    @State private var isAdding: Bool = false
    
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
        return 600
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - 40
        } else {
            return min(600, UIScreen.main.bounds.width - 80)
        }
        #endif
    }
    
    private var dialogHeight: CGFloat {
        #if os(macOS)
        return 400
        #else
        if shouldUseVerticalLayout {
            return min(UIScreen.main.bounds.height - 100, 450)
        } else {
            return min(400, UIScreen.main.bounds.height - 100)
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
    
    private var isFormValid: Bool {
        return !currencyName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !currencySymbol.trimmingCharacters(in: .whitespaces).isEmpty &&
        !exchangeRate.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(exchangeRate.trimmingCharacters(in: .whitespaces)) != nil
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Add New Currency")
                    .font(.system(size: shouldUseVerticalLayout ? 24 : 28, weight: .bold, design: .serif))
                    .foregroundColor(mainColor)
                    .padding(.top, shouldUseVerticalLayout ? 16 : 24)
                    .padding(.leading, horizontalPadding)
                    .padding(.bottom, 16)
                
                VStack(spacing: 20) {
                    // Currency Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 2) {
                            Text("Currency Name")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(mainColor)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        TextField("Enter currency name (e.g., Japanese Yen)", text: $currencyName)
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .padding(.horizontal, 16)
                            .frame(height: fieldHeight)
                            .background(sectionBg)
                            .cornerRadius(fieldCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: fieldCornerRadius)
                                    .stroke(nameError.isEmpty ? Color.gray.opacity(0.15) : Color.red, lineWidth: 1.2)
                            )
                        if !nameError.isEmpty {
                            Text(nameError)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                                .padding(.top, 1)
                        }
                    }
                    
                    // Currency Symbol Field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 2) {
                            Text("Currency Symbol")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(mainColor)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        TextField("Enter symbol (e.g., ¥)", text: $currencySymbol)
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .padding(.horizontal, 16)
                            .frame(height: fieldHeight)
                            .background(sectionBg)
                            .cornerRadius(fieldCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: fieldCornerRadius)
                                    .stroke(symbolError.isEmpty ? Color.gray.opacity(0.15) : Color.red, lineWidth: 1.2)
                            )
                        if !symbolError.isEmpty {
                            Text(symbolError)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                                .padding(.top, 1)
                        }
                    }
                    
                    // Exchange Rate Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 2) {
                            Text("Exchange Rate")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(mainColor)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        HStack(spacing: 12) {
                            // Left side - constant
                            HStack(spacing: 4) {
                                Text("1")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("$")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: fieldHeight)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(fieldCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: fieldCornerRadius)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            
                            // Equals sign
                            Text("=")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            // Right side - editable
                            HStack(spacing: 8) {
                                TextField("0.00", text: $exchangeRate)
                                    .font(.system(size: 16, weight: .medium))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                
                                Text(currencyName.isEmpty ? "New Currency" : currencyName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(currencyName.isEmpty ? .gray : .primary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: fieldHeight)
                            .background(sectionBg)
                            .cornerRadius(fieldCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: fieldCornerRadius)
                                    .stroke(rateError.isEmpty ? Color.gray.opacity(0.15) : Color.red, lineWidth: 1.2)
                            )
                        }
                        
                        if !rateError.isEmpty {
                            Text(rateError)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                                .padding(.top, 1)
                        }
                        
                        Text("Enter how many units of your currency equals 1 US Dollar")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                
                // Action Buttons
                actionButtons
                    .padding(.top, 24)
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
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        if shouldUseVerticalLayout {
            VStack(spacing: 12) {
                // Add Currency Button
                Button(action: addCurrency) {
                    Text("Add Currency")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isFormValid && !isAdding ? mainColor.opacity(0.97) : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isFormValid || isAdding)
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
                        .opacity(isAdding ? 0.6 : 1)
                }
                .disabled(isAdding)
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
                        .opacity(isAdding ? 0.6 : 1)
                }
                .disabled(isAdding)
                .buttonStyle(PlainButtonStyle())
                
                // Add Currency Button
                Button(action: addCurrency) {
                    Text("Add Currency")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .frame(width: 140, height: 44)
                        .background(isFormValid && !isAdding ? mainColor.opacity(0.97) : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isFormValid || isAdding)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func addCurrency() {
        // Clear previous errors
        nameError = ""
        symbolError = ""
        rateError = ""
        
        let trimmedName = currencyName.trimmingCharacters(in: .whitespaces)
        let trimmedSymbol = currencySymbol.trimmingCharacters(in: .whitespaces)
        let trimmedRate = exchangeRate.trimmingCharacters(in: .whitespaces)
        
        // Validate inputs
        var hasErrors = false
        
        if trimmedName.isEmpty {
            nameError = "Currency name is required."
            hasErrors = true
        } else if currencyManager.allCurrencies.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            nameError = "A currency with this name already exists."
            hasErrors = true
        }
        
        if trimmedSymbol.isEmpty {
            symbolError = "Currency symbol is required."
            hasErrors = true
        } else if currencyManager.allCurrencies.contains(where: { $0.symbol == trimmedSymbol }) {
            symbolError = "A currency with this symbol already exists."
            hasErrors = true
        }
        
        if trimmedRate.isEmpty {
            rateError = "Exchange rate is required."
            hasErrors = true
        } else if let rate = Double(trimmedRate), rate <= 0 {
            rateError = "Exchange rate must be greater than 0."
            hasErrors = true
        } else if Double(trimmedRate) == nil {
            rateError = "Please enter a valid number."
            hasErrors = true
        }
        
        if hasErrors {
            return
        }
        
        guard let rate = Double(trimmedRate) else {
            rateError = "Invalid exchange rate format."
            return
        }
        
        isAdding = true
        
        // Create currency
        let currency = Currency(name: trimmedName, symbol: trimmedSymbol, exchangeRate: rate)
        
        // Add to Firestore
        Task {
            do {
                try await currencyManager.addCurrency(currency)
                DispatchQueue.main.async {
                    self.isAdding = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAdding = false
                    self.rateError = "Failed to add currency. Please try again."
                }
            }
        }
    }
}
