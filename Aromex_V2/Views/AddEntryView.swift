import SwiftUI
#if os(macOS)
import AppKit
#endif
import FirebaseFirestore

// Color extension for cross-platform compatibility
extension Color {
    static var systemBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    static var systemGray6: Color {
        #if os(macOS)
        return Color(NSColor.controlColor)
        #else
        return Color(.systemGray6)
        #endif
    }
    
    static var systemGray5: Color {
        #if os(macOS)
        return Color(NSColor.unemphasizedSelectedContentBackgroundColor)
        #else
        return Color(.systemGray5)
        #endif
    }
}

struct CustomerBalancesView: View {
    let customer: Customer
    @State private var currencyBalances: [String: Double] = [:]
    @State private var isLoading = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        HStack(spacing: 8) {
            // Always show CAD balance first
            let roundedCADBalance = round(customer.balance * 100) / 100
            HStack(spacing: 2) {
                Text("CAD")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(roundedCADBalance, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(abs(roundedCADBalance) < 0.01 ? .gray : (roundedCADBalance > 0 ? .green : .red))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // Show other currencies only if they have non-zero balances
            ForEach(Array(currencyBalances.keys.sorted()), id: \.self) { currencyName in
                if let balance = currencyBalances[currencyName] {
                    let roundedBalance = round(balance * 100) / 100
                    if abs(roundedBalance) >= 0.01 { // Only show if not effectively zero
                        HStack {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 2) {
                                Text(currencyName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(roundedBalance, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(roundedBalance > 0 ? .green : .red)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchCurrencyBalances()
        }
    }
    
    private func fetchCurrencyBalances() {
        guard let customerId = customer.id, customerId != "myself_special_id" else {
            return
        }
        
        isLoading = true
        
        db.collection("CurrencyBalances").document(customerId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Error fetching currency balances for \(customer.name): \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("📄 No currency balances found for \(customer.name)")
                    return
                }
                
                var balances: [String: Double] = [:]
                for (key, value) in data {
                    if key != "updatedAt", let doubleValue = value as? Double {
                        balances[key] = doubleValue
                    }
                }
                
                self.currencyBalances = balances
                print("💰 Loaded currency balances for \(customer.name): \(balances)")
            }
        }
    }
}

struct AddEntryView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var currencyManager = CurrencyManager.shared
    @StateObject private var transactionManager = TransactionManager.shared
    @State private var selectedFromCustomer: Customer?
    @State private var selectedToCustomer: Customer?
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var isExchangeOn: Bool = false
    @State private var showingAddCustomerDialog: Bool = false
    @State private var showingAddCurrencyDialog: Bool = false
    @State private var isProcessingTransaction: Bool = false
    @State private var transactionError: String = ""
    @State private var showTransactionsTab: Bool = false
    @State private var showingExchangeRatesDialog: Bool = false
    @State private var totalExchangeProfit: [String: Double] = [:]
    
    // Exchange-specific fields
    @State private var selectedReceivingCurrency: Currency?
    @State private var customExchangeRate: String = ""
    @State private var showReceivingCurrencyDropdown: Bool = false
    @State private var receivingCurrencyButtonFrame: CGRect = .zero
    
    // Dropdown states
    @State private var selectedFromDropdownOpen: Bool = false
    @State private var selectedToDropdownOpen: Bool = false
    @State private var currencyDropdownOpen: Bool = false
    @State private var fromButtonFrame: CGRect = .zero
    @State private var toButtonFrame: CGRect = .zero
    @State private var currencyButtonFrame: CGRect = .zero
    
    // Separate search text for each dropdown
    @State private var fromSearchText: String = ""
    @State private var toSearchText: String = ""
    
    // Focus states for dropdown search fields
    @FocusState private var isFromFieldFocused: Bool
    @FocusState private var isToFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool
    
    // Environment to detect size class
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    
    @State private var selectedProfitTimeframe: ProfitTimeframe = .all
    @State private var showingTimeframeMenu: Bool = false
    
    @EnvironmentObject var navigationManager: CustomerNavigationManager
    
    enum ProfitTimeframe: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All"
        
        var icon: String {
            switch self {
            case .day: return "calendar"
            case .week: return "calendar.badge.clock"
            case .month: return "calendar.badge.plus"
            case .year: return "calendar.circle"
            case .all: return "infinity"
            }
        }
    }
    
    // Computed properties for responsive design
    private var isCompact: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        if horizontalSizeClass == .regular {
            return 24
        } else {
            return 16
        }
        #endif
    }
    
    private var dropdownWidth: CGFloat {
        #if os(macOS)
        return 200
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - (horizontalPadding * 2) - 40
        } else {
            return 200
        }
        #endif
    }
    
    private var amountFieldWidth: CGFloat {
        #if os(macOS)
        return 140
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - (horizontalPadding * 2) - 40
        } else {
            return 140
        }
        #endif
    }
    
    // Computed properties for validation
    private var isTransactionValid: Bool {
        let basicValidation = selectedFromCustomer != nil &&
               selectedToCustomer != nil &&
               !amount.trimmingCharacters(in: .whitespaces).isEmpty &&
               Double(amount.trimmingCharacters(in: .whitespaces)) != nil &&
               Double(amount.trimmingCharacters(in: .whitespaces))! > 0 &&
               currencyManager.selectedCurrency != nil &&
               selectedFromCustomer?.id != selectedToCustomer?.id
        
        if isExchangeOn {
            return basicValidation &&
                   selectedReceivingCurrency != nil &&
                   !customExchangeRate.trimmingCharacters(in: .whitespaces).isEmpty &&
                   Double(customExchangeRate.trimmingCharacters(in: .whitespaces)) != nil &&
                   Double(customExchangeRate.trimmingCharacters(in: .whitespaces))! > 0 &&
                   selectedReceivingCurrency?.id != currencyManager.selectedCurrency?.id
        }
        
        return basicValidation
    }
    
    // Filtered customers with "Myself" option
    private var filteredFromCustomers: [Customer] {
        var customers = [myselfCustomer]
        if fromSearchText.isEmpty {
            customers.append(contentsOf: firebaseManager.customers)
        } else {
            if "Myself".localizedCaseInsensitiveContains(fromSearchText) {
                // Keep "Myself" if search matches
            } else {
                customers.removeFirst() // Remove "Myself" if search doesn't match
            }
            customers.append(contentsOf: firebaseManager.customers.filter {
                $0.name.localizedCaseInsensitiveContains(fromSearchText)
            })
        }
        return customers
    }
    
    private var filteredToCustomers: [Customer] {
        var customers = [myselfCustomer]
        if toSearchText.isEmpty {
            customers.append(contentsOf: firebaseManager.customers)
        } else {
            if "Myself".localizedCaseInsensitiveContains(toSearchText) {
                // Keep "Myself" if search matches
            } else {
                customers.removeFirst() // Remove "Myself" if search doesn't match
            }
            customers.append(contentsOf: firebaseManager.customers.filter {
                $0.name.localizedCaseInsensitiveContains(toSearchText)
            })
        }
        return customers
    }
    
    // Create "Myself" customer instance
    private var myselfCustomer: Customer {
        Customer(
            id: "myself_special_id",
            name: "Myself",
            phone: "",
            email: "",
            address: "",
            notes: "",
            balance: 0.0,
            type: .customer,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Transaction Section
                        transactionSection
                        
                        // All Transactions Section
                        allTransactionsSection
                        
                        
                        // Status indicators
                        statusIndicators
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 40)
                }
                .background(Color.systemBackground)
            }
            
            // Dropdown overlays
            if selectedFromDropdownOpen {
                CustomerDropdownOverlay(
                    isOpen: $selectedFromDropdownOpen,
                    selectedCustomer: $selectedFromCustomer,
                    customers: filteredFromCustomers,
                    buttonFrame: fromButtonFrame
                )
            }
            
            if selectedToDropdownOpen {
                CustomerDropdownOverlay(
                    isOpen: $selectedToDropdownOpen,
                    selectedCustomer: $selectedToCustomer,
                    customers: filteredToCustomers,
                    buttonFrame: toButtonFrame
                )
            }
            
            if currencyDropdownOpen {
                CurrencyDropdownOverlay(
                    isOpen: $currencyDropdownOpen,
                    selectedCurrency: $currencyManager.selectedCurrency,
                    currencies: currencyManager.allCurrencies,
                    buttonFrame: currencyButtonFrame,
                    onAddCurrency: {
                        currencyDropdownOpen = false
                        showingAddCurrencyDialog = true
                    }
                )
            }
            
            if showReceivingCurrencyDropdown {
                CurrencyDropdownOverlay(
                    isOpen: $showReceivingCurrencyDropdown,
                    selectedCurrency: $selectedReceivingCurrency,
                    currencies: currencyManager.allCurrencies,
                    buttonFrame: receivingCurrencyButtonFrame,
                    onAddCurrency: {
                        showReceivingCurrencyDropdown = false
                        showingAddCurrencyDialog = true
                    }
                )
            }
        }
        .onAppear {
            isAmountFieldFocused = false
            currencyManager.fetchCurrencies()
            transactionManager.fetchTransactions()
            refreshEntireScreen()
            // Remove the immediate call: calculateTotalExchangeProfit()
        }
        .onChange(of: selectedFromDropdownOpen) { isOpen in
            isFromFieldFocused = isOpen
            if isOpen {
                isAmountFieldFocused = false
                currencyDropdownOpen = false
            }
        }
        .onChange(of: selectedToDropdownOpen) { isOpen in
            isToFieldFocused = isOpen
            if isOpen {
                isAmountFieldFocused = false
                currencyDropdownOpen = false
            }
        }
        .onChange(of: currencyDropdownOpen) { isOpen in
            if isOpen {
                isAmountFieldFocused = false
                selectedFromDropdownOpen = false
                selectedToDropdownOpen = false
                showReceivingCurrencyDropdown = false
            }
        }
        .onChange(of: showReceivingCurrencyDropdown) { isOpen in
            if isOpen {
                isAmountFieldFocused = false
                selectedFromDropdownOpen = false
                selectedToDropdownOpen = false
                currencyDropdownOpen = false
            }
        }
        .onChange(of: isExchangeOn) { isOn in
            if !isOn {
                selectedReceivingCurrency = nil
                customExchangeRate = ""
            }
        }
        .sheet(isPresented: $showingAddCustomerDialog) {
            AddCustomerDialog()
        }
        .sheet(isPresented: $showingAddCurrencyDialog) {
            AddCurrencyDialog()
                .environmentObject(currencyManager)
        }
        .sheet(isPresented: $showingExchangeRatesDialog) {
            ExchangeRatesDialog()
                .environmentObject(currencyManager)
        }
    }
    
    private var headerView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.5),
                    Color(red: 0.3, green: 0.4, blue: 0.6)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
            if shouldUseVerticalLayout {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("AROMEX")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Refresh Button
                        Button(action: refreshEntireScreen) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text("Transaction Entry")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Exchange Rates Bar (Vertical)
                    exchangeRatesBarVertical
                    
                    // Total Exchange Profit Bar (Vertical)
                    totalExchangeProfitBarVertical
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 16) {
                    HStack {
                        HStack(spacing: 16) {
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            
                            Text("AROMEX")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("Transaction Entry")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Refresh Button
                            Button(action: refreshEntireScreen) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.body)
                                    Text("Refresh")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {}) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Exchange Rates Bar (Horizontal)
                    exchangeRatesBarHorizontal
                    
                    // Total Exchange Profit Bar (Horizontal)
                    totalExchangeProfitBarHorizontal
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
            }
        }
        .frame(height: shouldUseVerticalLayout ? 240 : 180)
    }
    
    // ADDED: Missing transactionSection
    private var transactionSection: some View {
        VStack(spacing: 40) {
            // Section Header
            HStack {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(shouldUseVerticalLayout ? .title2 : .title)
                        .foregroundColor(.gray)
                    
                    Text("New Transaction")
                        .font(shouldUseVerticalLayout ? .title2 : .title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Text("Exchange")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: $isExchangeOn)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .scaleEffect(shouldUseVerticalLayout ? 1.0 : 1.2)
                        .labelsHidden()
                }
            }
            .padding(.horizontal, horizontalPadding)
            
            // Transaction Form
            VStack(spacing: 32) {
                if shouldUseVerticalLayout {
                    verticalTransactionForm
                } else {
                    horizontalTransactionForm
                }
            }
            .padding(.vertical, 32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    private var allTransactionsSection: some View {
        VStack(spacing: 24) {
            // Section Header
            HStack {
                HStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(shouldUseVerticalLayout ? .title2 : .title)
                        .foregroundColor(.blue)
                    
                    Text("All Transactions")
                        .font(shouldUseVerticalLayout ? .title2 : .title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if !transactionManager.transactions.isEmpty {
                    Text("\(transactionManager.transactions.count) transactions")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, horizontalPadding)
            
            // Transactions List
            VStack(spacing: 16) {
                if transactionManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading transactions...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if transactionManager.transactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No transactions yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start by adding your first transaction above")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(transactionManager.transactions) { transaction in
                            TransactionRowView(transaction: transaction)
                                .environmentObject(firebaseManager)
                                .environmentObject(navigationManager)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    private var horizontalTransactionForm: some View {
        VStack(spacing: 32) {
            // Main Transaction Row - Everything in One Line - CENTERED
            HStack(alignment: .top, spacing: 20) {
                Spacer() // Left spacer to center content
                
                // FROM Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    SimpleDropdownButton(
                        selectedCustomer: selectedFromCustomer,
                        placeholder: "Select customer",
                        isOpen: $selectedFromDropdownOpen,
                        buttonFrame: $fromButtonFrame,
                        searchText: $fromSearchText,
                        isFocused: $isFromFieldFocused
                    )
                    .frame(width: 180, height: 44)
                }
                
                // Arrow Connector
                VStack(spacing: 4) {
                    Spacer().frame(height: 18) // Align with dropdowns
                    HStack(spacing: 4) {
                        Text("gives to")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .frame(width: 100)
                
                // TO Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("To")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    SimpleDropdownButton(
                        selectedCustomer: selectedToCustomer,
                        placeholder: "Select customer",
                        isOpen: $selectedToDropdownOpen,
                        buttonFrame: $toButtonFrame,
                        searchText: $toSearchText,
                        isFocused: $isToFieldFocused
                    )
                    .frame(width: 180, height: 44)
                }
                
                // AMOUNT Section (Combined Currency + Amount)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    combinedAmountCurrencyField
                        .frame(width: 200, height: 44)
                }
                
                // EXCHANGE RATE Section (only if exchange is on)
                if isExchangeOn {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exchange Rate")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        exchangeRateCompactField
                            .frame(width: 220, height: 44)
                    }
                }
                
                // ACTION BUTTONS
                HStack(spacing: 12) {
                    // Add Customer Button
                    VStack(spacing: 4) {
                        Spacer().frame(height: 18) // Align with other elements
                        Button(action: { showingAddCustomerDialog = true }) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add Transaction Button
                    VStack(spacing: 4) {
                        Spacer().frame(height: 18) // Align with other elements
                        Button(action: { addTransaction() }) {
                            Text(isProcessingTransaction ? "⏳" : "Add")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 44)
                                .background(
                                    isTransactionValid && !isProcessingTransaction ?
                                    Color(red: 0.3, green: 0.4, blue: 0.6) : Color.gray.opacity(0.5)
                                )
                                .cornerRadius(8)
                        }
                        .disabled(!isTransactionValid || isProcessingTransaction)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer() // Right spacer to center content
            }
            
            // Customer Balances Row (shown below main row when customers are selected) - CENTERED
            if selectedFromCustomer != nil || selectedToCustomer != nil {
                HStack {
                    Spacer()
                    customerBalancesRow
                    Spacer()
                }
            }
            
            // Exchange Details Row (shown below when exchange is on and values are entered) - CENTERED
            if isExchangeOn && shouldShowExchangeDetails {
                HStack {
                    Spacer()
                    exchangeDetailsRow
                    Spacer()
                }
            }
            
            // Notes Row - CENTERED
            HStack {
                Spacer()
                notesRow
                Spacer()
            }
        }
    }

    private var verticalTransactionForm: some View {
        VStack(spacing: 24) {
            // FROM Section
            VStack(alignment: .leading, spacing: 12) {
                Text("From")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                SimpleDropdownButton(
                    selectedCustomer: selectedFromCustomer,
                    placeholder: "Select customer",
                    isOpen: $selectedFromDropdownOpen,
                    buttonFrame: $fromButtonFrame,
                    searchText: $fromSearchText,
                    isFocused: $isFromFieldFocused
                )
                .frame(height: 50)
                
                // Show balance immediately below
                if let customer = selectedFromCustomer {
                    compactCustomerBalance(for: customer)
                }
            }
            .padding(.horizontal, 20)
            
            // Arrow
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("gives to")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            
            // TO Section
            VStack(alignment: .leading, spacing: 12) {
                Text("To")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                SimpleDropdownButton(
                    selectedCustomer: selectedToCustomer,
                    placeholder: "Select customer",
                    isOpen: $selectedToDropdownOpen,
                    buttonFrame: $toButtonFrame,
                    searchText: $toSearchText,
                    isFocused: $isToFieldFocused
                )
                .frame(height: 50)
                
                // Show balance immediately below
                if let customer = selectedToCustomer {
                    compactCustomerBalance(for: customer)
                }
            }
            .padding(.horizontal, 20)
            
            // AMOUNT Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Amount")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                combinedAmountCurrencyField
                    .frame(height: 50)
            }
            .padding(.horizontal, 20)
            
            // EXCHANGE RATE Section
            if isExchangeOn {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exchange Rate")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    exchangeRateCompactField
                        .frame(height: 50)
                    
                    // Show profit/loss immediately below
                    if shouldShowExchangeDetails {
                        exchangeProfitLossDisplay
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Notes Section
            notesRow
            
            // Action Buttons
            VStack(spacing: 16) {
                Button(action: { showingAddCustomerDialog = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.body)
                        Text("Add Customer")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { addTransaction() }) {
                    Text(isProcessingTransaction ? "Processing..." : "Add Entry")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .background(
                            isTransactionValid && !isProcessingTransaction ?
                            Color(red: 0.3, green: 0.4, blue: 0.6) : Color.gray.opacity(0.5)
                        )
                        .cornerRadius(10)
                }
                .disabled(!isTransactionValid || isProcessingTransaction)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
        }
    }

    // Combined Amount and Currency Field (Compact)
    private var combinedAmountCurrencyField: some View {
        HStack(spacing: 0) {
            // Currency Button (Left)
            Button(action: { currencyDropdownOpen.toggle() }) {
                HStack(spacing: 4) {
                    Text(currencyManager.selectedCurrency?.symbol ?? "$")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(currencyManager.selectedCurrency?.name ?? "CAD")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: currencyDropdownOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        currencyButtonFrame = geometry.frame(in: .global)
                    }
                }
            )
            
            // Amount Input (Right)
            TextField("0.00", text: $amount)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .focused($isAmountFieldFocused)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    // Compact Exchange Rate Field
    private var exchangeRateCompactField: some View {
        HStack(spacing: 8) {
            // 1 Currency =
            HStack(spacing: 4) {
                Text("1")
                    .font(.system(size: 14, weight: .semibold))
                Text(currencyManager.selectedCurrency?.name ?? "CAD")
                    .font(.system(size: 12, weight: .medium))
                Text("=")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            
            // Rate Input
            TextField("Rate", text: $customExchangeRate)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .padding(.horizontal, 8)
                .frame(width: 60, height: 44)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Receiving Currency
            Button(action: { showReceivingCurrencyDropdown.toggle() }) {
                Text(selectedReceivingCurrency?.name ?? "Select")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 44)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        receivingCurrencyButtonFrame = geometry.frame(in: .global)
                    }
                }
            )
        }
    }

    // Customer Balances Row
    private var customerBalancesRow: some View {
        HStack(spacing: 40) {
            // From Customer Balance
            if let customer = selectedFromCustomer {
                HStack(spacing: 12) {
                    Text("\(customer.name) balances:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    CustomerBalancesView(customer: customer)
                }
            }
            
            Spacer()
            
            // To Customer Balance
            if let customer = selectedToCustomer {
                HStack(spacing: 12) {
                    Text("\(customer.name) balances:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    CustomerBalancesView(customer: customer)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }

    // Exchange Details Row
    private var exchangeDetailsRow: some View {
        exchangeProfitLossDisplay
            .padding(.horizontal, 20)
    }

    // Compact Customer Balance (for vertical layout)
    private func compactCustomerBalance(for customer: Customer) -> some View {
        HStack(spacing: 8) {
            Text("Balances:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            CustomerBalancesView(customer: customer)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }

    // ADDED: Missing calculateMarketRate function
    private func calculateMarketRate(from: Currency, to: Currency) -> Double {
        // Both currencies have exchange rates relative to USD
        // To convert from currency A to currency B:
        // 1 A = (1 / A.exchangeRate) USD = (1 / A.exchangeRate) * B.exchangeRate B
        return (1.0 / from.exchangeRate) * to.exchangeRate
    }

    // Exchange Profit/Loss Display
    private var exchangeProfitLossDisplay: some View {
        Group {
            if let givingCurrency = currencyManager.selectedCurrency,
               let receivingCurrency = selectedReceivingCurrency,
               let customRate = Double(customExchangeRate.trimmingCharacters(in: .whitespaces)),
               let transactionAmount = Double(amount.trimmingCharacters(in: .whitespaces)),
               customRate > 0 && transactionAmount > 0 {
                
                let marketRate = calculateMarketRate(from: givingCurrency, to: receivingCurrency)
                let profitRate = customRate - marketRate
                let totalProfitLoss = profitRate * transactionAmount
                
                HStack(spacing: 20) {
                    // Market Rate
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Market Rate")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("1 \(givingCurrency.name) = \(marketRate, specifier: "%.4f") \(receivingCurrency.name)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Profit/Loss
                    if abs(totalProfitLoss) >= 0.01 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(totalProfitLoss > 0 ? "Your Profit" : "Your Loss")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(totalProfitLoss > 0 ? .green : .red)
                            Text("\(totalProfitLoss > 0 ? "+" : "")\(totalProfitLoss, specifier: "%.2f") \(receivingCurrency.name)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(totalProfitLoss > 0 ? .green : .red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(totalProfitLoss > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Break Even")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                            Text("No profit/loss")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }

    // Notes Row
    private var notesRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            
            TextField("Add notes (optional)", text: $notes)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }

    // Helper computed property
    private var shouldShowExchangeDetails: Bool {
        return !customExchangeRate.trimmingCharacters(in: .whitespaces).isEmpty &&
               !amount.trimmingCharacters(in: .whitespaces).isEmpty &&
               selectedReceivingCurrency != nil &&
               currencyManager.selectedCurrency != nil
    }
    
    private var statusIndicators: some View {
        Group {
            if !transactionError.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .foregroundColor(.red)
                    Text(transactionError)
                        .font(.body)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, horizontalPadding)
            }
            
            if firebaseManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading customers...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            if !firebaseManager.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.body)
                        .foregroundColor(.red)
                    Text("No internet connection")
                        .font(.body)
                        .foregroundColor(.red)
                    
                    Button("Retry") {
                        firebaseManager.retryConnection()
                    }
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, horizontalPadding)
            }
            
            if !firebaseManager.errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .foregroundColor(.orange)
                    Text(firebaseManager.errorMessage)
                        .font(.body)
                        .foregroundColor(.orange)
                    
                    Button("Retry") {
                        firebaseManager.retryConnection()
                    }
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, horizontalPadding)
            }
            
            HStack {
                Image(systemName: firebaseManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.body)
                    .foregroundColor(firebaseManager.isConnected ? .green : .red)
                Text("Found \(firebaseManager.customers.count) customers")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if firebaseManager.isConnected {
                    Text("• Connected")
                        .font(.body)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    private func addTransaction() {
        guard let fromCustomer = selectedFromCustomer,
              let toCustomer = selectedToCustomer,
              let currency = currencyManager.selectedCurrency,
              let transactionAmount = Double(amount.trimmingCharacters(in: .whitespaces)) else {
            transactionError = "Please fill in all required fields"
            return
        }
        
        guard transactionAmount > 0 else {
            transactionError = "Amount must be greater than 0"
            return
        }
        
        guard fromCustomer.id != toCustomer.id else {
            transactionError = "Giver and receiver cannot be the same"
            return
        }
        
        // Additional validation for exchange transactions
        if isExchangeOn {
            guard let receivingCurrency = selectedReceivingCurrency,
                  let customRate = Double(customExchangeRate.trimmingCharacters(in: .whitespaces)) else {
                transactionError = "Please fill in exchange rate and receiving currency"
                return
            }
            
            guard customRate > 0 else {
                transactionError = "Exchange rate must be greater than 0"
                return
            }
            
            guard receivingCurrency.id != currency.id else {
                transactionError = "Giving and receiving currencies must be different"
                return
            }
        }
        
        isProcessingTransaction = true
        transactionError = ""
        
        if isExchangeOn {
            // Handle exchange transaction
            transactionManager.addExchangeTransaction(
                amount: transactionAmount,
                givingCurrency: currency,
                receivingCurrency: selectedReceivingCurrency!,
                customExchangeRate: Double(customExchangeRate.trimmingCharacters(in: .whitespaces))!,
                fromCustomer: fromCustomer,
                toCustomer: toCustomer,
                notes: notes.trimmingCharacters(in: .whitespaces)
            ) { [self] success, error in
                DispatchQueue.main.async {
                    self.isProcessingTransaction = false
                    
                    if success {
                        self.clearForm()
                        print("✅ Exchange transaction completed successfully")
                    } else {
                        self.transactionError = error ?? "Failed to process exchange transaction"
                    }
                }
            }
        } else {
            // Handle regular transaction
            transactionManager.addTransaction(
                amount: transactionAmount,
                currency: currency,
                fromCustomer: fromCustomer,
                toCustomer: toCustomer,
                notes: notes.trimmingCharacters(in: .whitespaces)
            ) { [self] success, error in
                DispatchQueue.main.async {
                    self.isProcessingTransaction = false
                    
                    if success {
                        self.clearForm()
                        print("✅ Transaction completed successfully")
                    } else {
                        self.transactionError = error ?? "Failed to process transaction"
                    }
                }
            }
        }
    }
    // Exchange Rates Display Components
    private var exchangeRatesBarHorizontal: some View {
        Button(action: { showingExchangeRatesDialog = true }) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.body)
                    .foregroundColor(.white)
                
                Text("Rates:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currencyManager.allCurrencies) { currency in
                            if currency.name != "CAD" {
                                HStack(spacing: 3) {
                                    Text("1$ =")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("\(currency.exchangeRate, specifier: "%.2f")")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text(currency.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(4)
                            }
                        }
                        
                        if currencyManager.allCurrencies.filter({ $0.name != "CAD" }).isEmpty {
                            Text("No custom currencies")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxWidth: 400)
                
                Image(systemName: "pencil.circle.fill")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var exchangeRatesBarVertical: some View {
        Button(action: { showingExchangeRatesDialog = true }) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.callout)
                        .foregroundColor(.white)
                    
                    Text("Exchange Rates")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(currencyManager.allCurrencies) { currency in
                            if currency.name != "CAD" {
                                VStack(spacing: 1) {
                                    Text(currency.symbol)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("\(currency.exchangeRate, specifier: "%.2f")")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(3)
                            }
                        }
                        
                        if currencyManager.allCurrencies.filter({ $0.name != "CAD" }).isEmpty {
                            Text("No rates")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func refreshEntireScreen() {
        currencyManager.fetchCurrencies()
        transactionManager.fetchTransactions()
        firebaseManager.fetchAllCustomers()
        
        // Calculate profit after a small delay to ensure data is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.calculateTotalExchangeProfit()
        }
    }
    
    private var totalExchangeProfitBarHorizontal: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.body)
                    .foregroundColor(.white)
                
                Text("Profit:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                // Timeframe Filter Button
                Menu {
                    ForEach(ProfitTimeframe.allCases, id: \.self) { timeframe in
                        Button(action: {
                            selectedProfitTimeframe = timeframe
                            calculateTotalExchangeProfit()
                        }) {
                            HStack {
                                Image(systemName: timeframe.icon)
                                Text(timeframe.rawValue)
                                if selectedProfitTimeframe == timeframe {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedProfitTimeframe.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(selectedProfitTimeframe.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(totalExchangeProfit.keys.sorted()), id: \.self) { currency in
                            if let profit = totalExchangeProfit[currency], abs(profit) >= 0.01 {
                                HStack(spacing: 3) {
                                    Text(profit > 0 ? "+" : "")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(profit > 0 ? .green : .red)
                                    Text("\(profit, specifier: "%.2f")")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(profit > 0 ? .green : .red)
                                    Text(currency)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background((profit > 0 ? Color.green : Color.red).opacity(0.15))
                                .cornerRadius(4)
                            }
                        }
                        
                        if totalExchangeProfit.isEmpty || totalExchangeProfit.values.allSatisfy({ abs($0) < 0.01 }) {
                            Text("No profit (\(selectedProfitTimeframe.rawValue.lowercased()))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxWidth: 300) // Limit the width similar to rates section
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var totalExchangeProfitBarVertical: some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.callout)
                        .foregroundColor(.white)
                    
                    Text("Profit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Compact Timeframe Button
                    Menu {
                        ForEach(ProfitTimeframe.allCases, id: \.self) { timeframe in
                            Button(action: {
                                selectedProfitTimeframe = timeframe
                                calculateTotalExchangeProfit()
                            }) {
                                HStack {
                                    Image(systemName: timeframe.icon)
                                    Text(timeframe.rawValue)
                                    if selectedProfitTimeframe == timeframe {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: selectedProfitTimeframe.icon)
                                .font(.system(size: 8, weight: .medium))
                            Text(selectedProfitTimeframe == .all ? "All" : selectedProfitTimeframe.rawValue.first?.uppercased() ?? "")
                                .font(.system(size: 9, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 6, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(3)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(Array(totalExchangeProfit.keys.sorted()), id: \.self) { currency in
                            if let profit = totalExchangeProfit[currency], abs(profit) >= 0.01 {
                                VStack(spacing: 1) {
                                    Text(currency)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("\(profit > 0 ? "+" : "")\(profit, specifier: "%.1f")")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(profit > 0 ? .green : .red)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background((profit > 0 ? Color.green : Color.red).opacity(0.15))
                                .cornerRadius(3)
                            }
                        }
                        
                        if totalExchangeProfit.isEmpty || totalExchangeProfit.values.allSatisfy({ abs($0) < 0.01 }) {
                            Text("No profit")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func calculateTotalExchangeProfit() {
        var profitByCurrency: [String: Double] = [:]
        
        // Filter transactions by timeframe
        let filteredTransactions = transactionManager.transactions.filter { transaction in
            guard transaction.isExchange else { return false }
            
            let transactionDate = transaction.timestamp.dateValue()
            let now = Date()
            
            switch selectedProfitTimeframe {
            case .day:
                return Calendar.current.isDate(transactionDate, inSameDayAs: now)
            case .week:
                return Calendar.current.dateInterval(of: .weekOfYear, for: now)?.contains(transactionDate) ?? false
            case .month:
                return Calendar.current.dateInterval(of: .month, for: now)?.contains(transactionDate) ?? false
            case .year:
                return Calendar.current.dateInterval(of: .year, for: now)?.contains(transactionDate) ?? false
            case .all:
                return true
            }
        }
        
        print("🔍 Calculating profit for \(selectedProfitTimeframe.rawValue): \(filteredTransactions.count) transactions")
        
        // Go through filtered exchange transactions
        for transaction in filteredTransactions {
            guard let customRate = transaction.customExchangeRate,
                  let receivingCurrencyName = transaction.receivingCurrencyName else {
                continue
            }
            
            let givingCurrencyName = transaction.currencyName
            
            // Find current exchange rates
            let givingCurrency = currencyManager.allCurrencies.first { $0.name == givingCurrencyName }
            let receivingCurrency = currencyManager.allCurrencies.first { $0.name == receivingCurrencyName }
            
            guard let givingRate = givingCurrency?.exchangeRate,
                  let receivingRate = receivingCurrency?.exchangeRate else {
                continue
            }
            
            // Calculate current profit for this transaction
            let currentMarketRate = (1.0 / givingRate) * receivingRate
            let profitRate = customRate - currentMarketRate
            let transactionProfit = profitRate * transaction.amount
            
            // Add to total for this currency
            profitByCurrency[receivingCurrencyName] = (profitByCurrency[receivingCurrencyName] ?? 0) + transactionProfit
        }
        
        totalExchangeProfit = profitByCurrency
        print("💰 Total Exchange Profit (\(selectedProfitTimeframe.rawValue)): \(profitByCurrency)")
    }
    private func clearForm() {
        selectedFromCustomer = nil
        selectedToCustomer = nil
        amount = ""
        notes = ""
        transactionError = ""
        selectedReceivingCurrency = nil
        customExchangeRate = ""
    }
}

struct SimpleDropdownButton: View {
    let selectedCustomer: Customer?
    let placeholder: String
    @Binding var isOpen: Bool
    @Binding var buttonFrame: CGRect
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                if isOpen {
                    TextField("Search...", text: $searchText)
                        .font(.body)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primary)
                        .focused($isFocused)
                        .onAppear {
                            DispatchQueue.main.async {
                                isFocused = true
                            }
                        }
                } else {
                    if let selectedCustomer = selectedCustomer {
                        Text(selectedCustomer.displayNameWithTag)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text(placeholder)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.6))
                    }
                }
            }
            Spacer()
            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isOpen ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: isOpen ? 2 : 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOpen.toggle()
                isFocused = isOpen
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        buttonFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                        buttonFrame = newFrame
                    }
            }
        )
    }
}

struct CustomerDropdownOverlay: View {
    @Binding var isOpen: Bool
    @Binding var selectedCustomer: Customer?
    let customers: [Customer]
    let buttonFrame: CGRect
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var currencyManager = CurrencyManager.shared
    
    private var overlayWidth: CGFloat {
        #if os(macOS)
        return max(400, buttonFrame.width)
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - 32
        } else {
            return max(400, buttonFrame.width)
        }
        #endif
    }
    
    var body: some View {
        Color.black.opacity(0.001)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
                withAnimation {
                    isOpen = false
                }
            }
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(customers) { customer in
                                Button(action: {
                                    withAnimation {
                                        selectedCustomer = customer
                                        isOpen = false
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            // Customer name with icon
                                            HStack(spacing: 6) {
                                                if customer.id == "myself_special_id" {
                                                    Image(systemName: "person.crop.circle.fill")
                                                        .font(.callout)
                                                        .foregroundColor(.blue)
                                                }
                                                Text(customer.name)
                                                    .font(.body)
                                                    .fontWeight(customer.id == "myself_special_id" ? .semibold : .medium)
                                                    .foregroundColor(customer.id == "myself_special_id" ? .blue : .primary)
                                            }
                                            
                                            // Currency balances
                                            if customer.id != "myself_special_id" {
                                                CustomerBalancesView(customer: customer)
                                            } else {
                                                // For "Myself", show placeholder balances
                                                HStack(spacing: 8) {
                                                    HStack(spacing: 2) {
                                                        Text("CAD")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                        Text("0.00")
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .fill(Color.blue.opacity(0.1))
                                                    )
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Customer type badge
                                        if customer.id != "myself_special_id" {
                                            Text("[\(customer.type.displayName)]")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(customer.type == .customer ? Color.blue :
                                                            customer.type == .middleman ? Color.orange : Color.green)
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedCustomer?.id == customer.id ?
                                        Color.blue.opacity(0.1) : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Add separator after "Myself" option
                                if customer.id == "myself_special_id" && customers.count > 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: min(CGFloat(customers.count) * 80 + (customers.count > 1 ? 10 : 0), 320))
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
                )
                .frame(width: overlayWidth)
                .position(
                    x: buttonFrame.midX,
                    y: buttonFrame.maxY + 15 + (min(CGFloat(customers.count) * 80 + (customers.count > 1 ? 10 : 0), 320) / 2)
                )
            )
    }
}

struct CurrencyDropdownButton: View {
    let selectedCurrency: Currency?
    @Binding var isOpen: Bool
    @Binding var buttonFrame: CGRect
    
    var body: some View {
        HStack(spacing: 2) {
            // Show currency name with better truncation
            Text(selectedCurrency?.name ?? "CAD")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7) // Allow text to scale down if needed
            
            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 4)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isOpen ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: isOpen ? 2 : 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOpen.toggle()
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        buttonFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                        buttonFrame = newFrame
                    }
            }
        )
    }
}

struct CurrencyDropdownOverlay: View {
    @Binding var isOpen: Bool
    @Binding var selectedCurrency: Currency?
    let currencies: [Currency]
    let buttonFrame: CGRect
    let onAddCurrency: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var overlayWidth: CGFloat {
        #if os(macOS)
        return 180
        #else
        if horizontalSizeClass == .compact {
            return min(200, UIScreen.main.bounds.width - 40)
        } else {
            return 180
        }
        #endif
    }
    
    var body: some View {
        Color.black.opacity(0.001)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
                withAnimation {
                    isOpen = false
                }
            }
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Currency options (now includes CAD always)
                            ForEach(currencies) { currency in
                                Button(action: {
                                    withAnimation {
                                        selectedCurrency = currency
                                        isOpen = false
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text(currency.symbol)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .frame(width: 20)
                                        
                                        Text(currency.name)
                                            .font(.callout)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if selectedCurrency?.id == currency.id {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCurrency?.id == currency.id ?
                                        Color.blue.opacity(0.1) : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Add Currency Button
                            Divider()
                                .padding(.horizontal, 16)
                            
                            Button(action: onAddCurrency) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    
                                    Text("Add Currency")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: min(CGFloat(currencies.count) * 36 + 50, 200))
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
                )
                .frame(width: overlayWidth)
                .position(
                    x: buttonFrame.midX,
                    y: buttonFrame.maxY + 8 + (min(CGFloat(currencies.count) * 36 + 50, 200) / 2)
                )
            )
    }
}

struct TransactionRowView: View {
    let transaction: CurrencyTransaction
    @StateObject private var currencyManager = CurrencyManager.shared
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
    
    private var giverBalances: [String: Double] {
        if transaction.giver == "myself_special_id" {
            return transaction.balancesAfterTransaction["myself"] as? [String: Double] ?? [:]
        } else {
            return transaction.balancesAfterTransaction[transaction.giver] as? [String: Double] ?? [:]
        }
    }
    
    private var takerBalances: [String: Double] {
        if transaction.taker == "myself_special_id" {
            return transaction.balancesAfterTransaction["myself"] as? [String: Double] ?? [:]
        } else {
            return transaction.balancesAfterTransaction[transaction.taker] as? [String: Double] ?? [:]
        }
    }
    
    private func navigateToCustomer(id: String, name: String) {
        // Find the customer in the firebaseManager
        if let customer = firebaseManager.customers.first(where: { $0.id == id }) {
            navigationManager.navigateToCustomer(customer)
        }
    }
    // Dynamic profit calculation using current exchange rates
    private var dynamicProfitData: (profit: Double, currency: String)? {
        guard transaction.isExchange,
              let customRate = transaction.customExchangeRate,
              let receivingCurrencyName = transaction.receivingCurrencyName else {
            return nil
        }
        
        let givingCurrencyName = transaction.currencyName
        
        // Find current exchange rates from currencyManager
        let givingCurrency = currencyManager.allCurrencies.first { $0.name == givingCurrencyName }
        let receivingCurrency = currencyManager.allCurrencies.first { $0.name == receivingCurrencyName }
        
        guard let givingRate = givingCurrency?.exchangeRate,
              let receivingRate = receivingCurrency?.exchangeRate else {
            return nil
        }
        
        // Calculate current market rate
        let currentMarketRate = (1.0 / givingRate) * receivingRate
        let profitRate = customRate - currentMarketRate
        let totalProfit = profitRate * transaction.amount
        
        return (profit: totalProfit, currency: receivingCurrencyName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header Row (keeping as is)
            HStack(spacing: 0) {
                Text("Date & Time")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.horizontal, 12)
                
                Divider().frame(height: 20)
                
                Text("Transaction Details")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 280, alignment: .leading)
                    .padding(.horizontal, 12)
                
                Divider().frame(height: 20)
                
                Text("Exchange Info")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 160, alignment: .leading)
                    .padding(.horizontal, 12)
                
                Divider().frame(height: 20)
                
                Text("Giver Balances")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
                    .padding(.horizontal, 12)
                
                Divider().frame(height: 20)
                
                Text("Taker Balances")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            // Actual Transaction Row
            HStack(spacing: 0) {
                // COLUMN 1: Date & Time with Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text(dateFormatter.string(from: transaction.timestamp.dateValue()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(timeFormatter.string(from: transaction.timestamp.dateValue()))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(4)
                    
                    if !transaction.notes.isEmpty {
                        Text(transaction.notes)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(6)
                            .lineLimit(3)
                    }
                }
                .frame(width: 120, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 2: Transaction Details - Reduced Sizes
                VStack(alignment: .leading, spacing: 16) {
                    // Amount Section
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Given")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("\(transaction.amount, specifier: "%.2f") \(transaction.currencyName)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(4)
                        }
                        
                        if transaction.isExchange {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue.opacity(0.7))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("To be received")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(transaction.receivedAmount ?? 0, specifier: "%.2f") \(transaction.receivingCurrencyName ?? "")")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.08))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    // Participants Section - Enhanced Highlighting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transaction Flow")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            // Clickable Giver
                            Button(action: {
                                navigateToCustomer(id: transaction.giver, name: transaction.giverName)
                            }) {
                                HStack(spacing: 4) {
                                    if transaction.giver == "myself_special_id" {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                    } else {
                                        Circle()
                                            .fill(Color.orange.opacity(0.7))
                                            .frame(width: 8, height: 8)
                                    }
                                    
                                    Text(transaction.giverName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(transaction.giver == "myself_special_id" ? .blue : .primary)
                                        .underline(transaction.giver != "myself_special_id") // Underline for non-myself customers
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(transaction.giver == "myself_special_id") // Disable click for "Myself"
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue.opacity(0.7))
                            
                            // Clickable Taker
                            Button(action: {
                                navigateToCustomer(id: transaction.taker, name: transaction.takerName)
                            }) {
                                HStack(spacing: 4) {
                                    if transaction.taker == "myself_special_id" {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                    } else {
                                        Circle()
                                            .fill(Color.green.opacity(0.7))
                                            .frame(width: 8, height: 8)
                                    }
                                    
                                    Text(transaction.takerName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(transaction.taker == "myself_special_id" ? .blue : .primary)
                                        .underline(transaction.taker != "myself_special_id") // Underline for non-myself customers
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(transaction.taker == "myself_special_id") // Disable click for "Myself"
                            
                            Spacer()
                        }
                    }
                }
                .frame(width: 280, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 3: Exchange Info - One Line Layout
                VStack(alignment: .leading, spacing: 8) {
                    if transaction.isExchange {
                        // Exchange Rate with Currency Names
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exchange Rate")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            
                            if let customRate = transaction.customExchangeRate {
                                HStack(spacing: 4) {
                                    Text("1 \(transaction.currencyName) = \(customRate, specifier: "%.4f") \(transaction.receivingCurrencyName ?? "")")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Current Profit Display with Dynamic Calculation
                        if let profit = dynamicProfitData?.profit,
                           let profitCurrency = dynamicProfitData?.currency {
                            VStack(alignment: .leading, spacing: 4) {
                                // Profit amount and percentage
                                HStack(spacing: 8) {
                                    Text(profit > 0 ? "Current Profit:" : (profit < 0 ? "Current Loss:" : "Break Even:"))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(profit > 0 ? .green.opacity(0.8) : (profit < 0 ? .red.opacity(0.8) : .gray))
                                    
                                    Text("\(profit > 0 ? "+" : "")\(profit, specifier: "%.2f") \(profitCurrency)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(profit > 0 ? .green.opacity(0.8) : (profit < 0 ? .red.opacity(0.8) : .gray))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((profit > 0 ? Color.green : (profit < 0 ? Color.red : Color.gray)).opacity(0.08))
                                .cornerRadius(6)
                                
                                // Profit percentage
                                if let customRate = transaction.customExchangeRate,
                                   let givingCurrency = currencyManager.allCurrencies.first(where: { $0.name == transaction.currencyName }),
                                   let receivingCurrency = currencyManager.allCurrencies.first(where: { $0.name == transaction.receivingCurrencyName }) {
                                    
                                    let currentMarketRate = (1.0 / givingCurrency.exchangeRate) * receivingCurrency.exchangeRate
                                    let profitPercentage = ((customRate - currentMarketRate) / currentMarketRate) * 100
                                    
                                    HStack(spacing: 4) {
                                        Text("Profit %:")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(profitPercentage > 0 ? "+" : "")\(profitPercentage, specifier: "%.2f")%")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(profitPercentage > 0 ? .green.opacity(0.8) : (profitPercentage < 0 ? .red.opacity(0.8) : .gray))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 16))
                                .foregroundColor(.blue.opacity(0.6))
                            
                            Text("Regular Transfer")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("\(transaction.amount, specifier: "%.2f") \(transaction.currencyName)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .frame(width: 160, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 4: Giver Balances - Enhanced Padding
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack(spacing: 4) {
                        if transaction.giver == "myself_special_id" {
                            Image(systemName: "person.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        
                        Text(transaction.giverName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Balance list
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(giverBalances.keys.sorted()), id: \.self) { currencyKey in
                            if let balance = giverBalances[currencyKey] {
                                let roundedBalance = round(balance * 100) / 100
                                if abs(roundedBalance) >= 0.01 || currencyKey == "amount" || currencyKey == "CAD" {
                                    HStack(spacing: 4) {
                                        Text(currencyKey == "amount" ? "CAD" : currencyKey)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(2)
                                        
                                        Text("\(roundedBalance, specifier: "%.2f")")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(abs(roundedBalance) < 0.01 ? .secondary : (roundedBalance > 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8)))
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 140, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                Divider()
                
                // COLUMN 5: Taker Balances - Enhanced Padding
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack(spacing: 4) {
                        if transaction.taker == "myself_special_id" {
                            Image(systemName: "person.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        
                        Text(transaction.takerName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Balance list
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(takerBalances.keys.sorted()), id: \.self) { currencyKey in
                            if let balance = takerBalances[currencyKey] {
                                let roundedBalance = round(balance * 100) / 100
                                if abs(roundedBalance) >= 0.01 || currencyKey == "amount" || currencyKey == "CAD" {
                                    HStack(spacing: 4) {
                                        Text(currencyKey == "amount" ? "CAD" : currencyKey)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(2)
                                        
                                        Text("\(roundedBalance, specifier: "%.2f")")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(abs(roundedBalance) < 0.01 ? .secondary : (roundedBalance > 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8)))
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 140, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.systemBackground)
                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .onAppear {
            // Ensure currency manager fetches latest rates when row appears
            currencyManager.fetchCurrencies()
        }
    }
}
