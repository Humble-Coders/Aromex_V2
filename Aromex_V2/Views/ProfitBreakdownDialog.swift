import SwiftUI
import FirebaseFirestore

struct ProfitBreakdownDialog: View {
    let totalExchangeProfit: [String: Double]
    let totalProfitInUSD: Double
    let timeframe: AddEntryView.ProfitTimeframe
    let currencyManager: CurrencyManager
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // Theme colors
    let mainColor = Color(red: 0.23, green: 0.28, blue: 0.42)
    let sectionBg = Color.white
    
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
        return 500
        #else
        if shouldUseVerticalLayout {
            return min(UIScreen.main.bounds.height - 100, 600)
        } else {
            return min(500, UIScreen.main.bounds.height - 100)
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profit Breakdown")
                            .font(.system(size: shouldUseVerticalLayout ? 24 : 28, weight: .bold, design: .serif))
                            .foregroundColor(mainColor)
                        
                        Text("Exchange profits for \(timeframe.rawValue.lowercased())")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, shouldUseVerticalLayout ? 16 : 24)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 24)
                
                VStack(spacing: 24) {
                    // Total USD Profit Summary
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            
                            Text("Total Profit (USD)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("$\(totalProfitInUSD, specifier: "%.2f")")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(totalProfitInUSD >= 0 ? .green : .red)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Converted at")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("Market Rates")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(totalProfitInUSD >= 0 ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(totalProfitInUSD >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // Individual Currency Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            
                            Text("Currency Breakdown")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        if totalExchangeProfit.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.line.flattrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text("No exchange profits")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("No profitable exchange transactions found for \(timeframe.rawValue.lowercased())")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(totalExchangeProfit.keys.sorted()), id: \.self) { currency in
                                    if let profit = totalExchangeProfit[currency], abs(profit) >= 0.01 {
                                        CurrencyProfitRow(
                                            currency: currency,
                                            profit: profit,
                                            currencyManager: currencyManager
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.systemGray6.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // Calculation Note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            
                            Text("How it's calculated:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Individual currency profits calculated using (Custom Rate - Market Rate) × Amount")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            Text("• USD conversion uses current market exchange rates")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            Text("• Total USD profit = Sum of all currency profits converted to USD")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 32)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBg)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
        )
        .frame(width: dialogWidth, height: dialogHeight)
    }
}

struct CurrencyProfitRow: View {
    let currency: String
    let profit: Double
    let currencyManager: CurrencyManager
    
    private var profitInUSD: Double {
        // Convert profit to USD using market rate
        if let currencyData = currencyManager.allCurrencies.first(where: { $0.name == currency }) {
            return profit / currencyData.exchangeRate
        }
        return 0.0
    }
    
    private var currencySymbol: String {
        return currencyManager.allCurrencies.first(where: { $0.name == currency })?.symbol ?? currency
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Currency Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(currencySymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(currency)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                if let currencyData = currencyManager.allCurrencies.first(where: { $0.name == currency }) {
                    Text("Rate: 1 USD = \(currencyData.exchangeRate, specifier: "%.4f") \(currencySymbol)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Profit Display
            VStack(alignment: .trailing, spacing: 6) {
                // Original currency profit
                Text("\(profit > 0 ? "+" : "")\(profit, specifier: "%.2f") \(currencySymbol)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(profit >= 0 ? .green : .red)
                
                // USD equivalent
                HStack(spacing: 4) {
                    Text("≈")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(profitInUSD > 0 ? "+" : "")$\(abs(profitInUSD), specifier: "%.2f")")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(profitInUSD >= 0 ? .green : .red)
                    
                    Text("USD")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(profitInUSD >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
