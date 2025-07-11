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
                    }
                    
                    Text("Transaction Entry")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 20)
            } else {
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
                    
                    Button(action: {}) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
            }
        }
        .frame(height: shouldUseVerticalLayout ? 120 : 100)
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
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    
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
                
                // Notes Section
                notesSection
            }
            .padding(.vertical, 32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    private var verticalTransactionForm: some View {
        VStack(spacing: 24) {
            // From Customer
            VStack(alignment: .leading, spacing: 8) {
                Text("From")
                    .font(.body)
                    .fontWeight(.semibold)
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
            }
            .padding(.horizontal, 20)
            
            // Arrow Indicator
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("gives to")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Image(systemName: "arrow.down")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            
            // To Customer
            VStack(alignment: .leading, spacing: 8) {
                Text("To")
                    .font(.body)
                    .fontWeight(.semibold)
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
            }
            .padding(.horizontal, 20)
            
            // Amount Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 0) {
                    // Currency Dropdown
                    CurrencyDropdownButton(
                        selectedCurrency: currencyManager.selectedCurrency,
                        isOpen: $currencyDropdownOpen,
                        buttonFrame: $currencyButtonFrame
                    )
                    .frame(width: 60, height: 50)
                    
                    // Amount Input
                    TextField("0.00", text: $amount)
                        .font(.body)
                        .fontWeight(.medium)
                        .focused($isAmountFieldFocused)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 20)
            
            // Exchange Rate Section (only if exchange is on)
            if isExchangeOn {
                exchangeRateSection
            }
            
            // Action Buttons
            VStack(spacing: 16) {
                Button(action: {
                    showingAddCustomerDialog = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Add Customer")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    addTransaction()
                }) {
                    Text(isProcessingTransaction ? "Processing..." : "Add Entry")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isTransactionValid && !isProcessingTransaction ? Color(red: 0.3, green: 0.4, blue: 0.6) : Color.gray.opacity(0.5),
                                    isTransactionValid && !isProcessingTransaction ? Color(red: 0.25, green: 0.35, blue: 0.55) : Color.gray.opacity(0.4)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                }
                .disabled(!isTransactionValid || isProcessingTransaction)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var horizontalTransactionForm: some View {
        HStack(spacing: 20) {
            // From Dropdown
            VStack(alignment: .leading, spacing: 8) {
                Text("From")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                SimpleDropdownButton(
                    selectedCustomer: selectedFromCustomer,
                    placeholder: "Select customer",
                    isOpen: $selectedFromDropdownOpen,
                    buttonFrame: $fromButtonFrame,
                    searchText: $fromSearchText,
                    isFocused: $isFromFieldFocused
                )
                .frame(width: dropdownWidth, height: 50)
            }
            
            // Arrow
            VStack(alignment: .center, spacing: 8) {
                Text("")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.clear)
                
                HStack(spacing: 6) {
                    Text("gives to")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Image(systemName: "arrow.right")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                )
            }
            .frame(width: 100)
            
            // To Dropdown
            VStack(alignment: .leading, spacing: 8) {
                Text("To")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                SimpleDropdownButton(
                    selectedCustomer: selectedToCustomer,
                    placeholder: "Select customer",
                    isOpen: $selectedToDropdownOpen,
                    buttonFrame: $toButtonFrame,
                    searchText: $toSearchText,
                    isFocused: $isToFieldFocused
                )
                .frame(width: dropdownWidth, height: 50)
            }
            
            // Amount Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 0) {
                    // Currency Dropdown
                    CurrencyDropdownButton(
                        selectedCurrency: currencyManager.selectedCurrency,
                        isOpen: $currencyDropdownOpen,
                        buttonFrame: $currencyButtonFrame
                    )
                    .frame(width: 60, height: 50)
                    
                    // Amount Input
                    TextField("0.00", text: $amount)
                        .font(.body)
                        .fontWeight(.medium)
                        .focused($isAmountFieldFocused)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(width: amountFieldWidth)
            
            // Exchange Rate Section (only if exchange is on)
            if isExchangeOn {
                exchangeRateSection
            }
            
            // Add Customer Button
            VStack(spacing: 8) {
                Text("New Customer")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Button(action: {
                    showingAddCustomerDialog = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Add Entry Button
            VStack(spacing: 8) {
                Text("Complete Transaction")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.3, green: 0.4, blue: 0.6))
                
                Button(action: {
                    addTransaction()
                }) {
                    Text(isProcessingTransaction ? "Processing..." : "Add Entry")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isTransactionValid && !isProcessingTransaction ? Color(red: 0.3, green: 0.4, blue: 0.6) : Color.gray.opacity(0.5),
                                    isTransactionValid && !isProcessingTransaction ? Color(red: 0.25, green: 0.35, blue: 0.55) : Color.gray.opacity(0.4)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color(red: 0.3, green: 0.4, blue: 0.6).opacity(0.3), radius: 4, x: 0, y: 2)
                        .frame(height: 50)
                }
                .disabled(!isTransactionValid || isProcessingTransaction)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    private var exchangeRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exchange Rate")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                // Given currency (fixed)
                HStack(spacing: 4) {
                    Text("1")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(currencyManager.selectedCurrency?.name ?? "CAD")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Equals sign
                Text("=")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Custom rate input
                TextField("Rate", text: $customExchangeRate)
                    .font(.body)
                    .fontWeight(.medium)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 80)
                
                // Receiving currency dropdown
                CurrencyDropdownButton(
                    selectedCurrency: selectedReceivingCurrency,
                    isOpen: $showReceivingCurrencyDropdown,
                    buttonFrame: $receivingCurrencyButtonFrame
                )
                .frame(width: 60, height: 44)
            }
            
            // Market rate comparison (if available)
            if let givingCurrency = currencyManager.selectedCurrency,
               let receivingCurrency = selectedReceivingCurrency,
               let customRate = Double(customExchangeRate.trimmingCharacters(in: .whitespaces)) {
                
                let marketRate = calculateMarketRate(from: givingCurrency, to: receivingCurrency)
                let profitRate = customRate - marketRate
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Market rate:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1 \(givingCurrency.name) = \(marketRate, specifier: "%.2f") \(receivingCurrency.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if profitRate > 0 {
                        HStack {
                            Text("Your profit:")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("+\(profitRate, specifier: "%.2f") \(receivingCurrency.name) per \(givingCurrency.name)")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, shouldUseVerticalLayout ? 20 : 0)
    }
    
    private func calculateMarketRate(from: Currency, to: Currency) -> Double {
        // Both currencies have exchange rates relative to CAD
        // To convert from currency A to currency B:
        // 1 A = (1 / A.exchangeRate) CAD = (1 / A.exchangeRate) * B.exchangeRate B
        return (1.0 / from.exchangeRate) * to.exchangeRate
    }
    
    private var notesSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.title2)
                .foregroundColor(.blue)
            
            TextField("Add notes (optional)", text: $notes)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(height: 50)
        }
        .padding(.horizontal, horizontalPadding)
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

// Key updates for TransactionRowView in AddEntryView.swift

struct TransactionRowView: View {
    let transaction: CurrencyTransaction
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with amount and currency
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if transaction.isExchange {
                        HStack(spacing: 8) {
                            Text("\(transaction.amount, specifier: "%.2f") \(transaction.currencyName)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Image(systemName: "arrow.right")
                                .font(.callout)
                                .foregroundColor(.blue)
                            
                            Text("\(transaction.receivedAmount ?? 0, specifier: "%.2f") \(transaction.receivingCurrencyName ?? "")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Exchange:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(transaction.currencyName) → \(transaction.receivingCurrencyName ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let profit = transaction.profitAmount, profit > 0 {
                                Text("(+\(profit, specifier: "%.2f") \(transaction.receivingCurrencyName ?? "") profit)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                            }
                        }
                    } else {
                        Text("\(transaction.amount, specifier: "%.2f") \(transaction.currencyName)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text(transaction.currencyName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dateFormatter.string(from: transaction.timestamp.dateValue()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if transaction.isExchange {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("EXCHANGE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Exchange rate information (for exchange transactions)
            if transaction.isExchange,
               let customRate = transaction.customExchangeRate,
               let marketRate = transaction.marketExchangeRate {
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Exchange Rate:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1 \(transaction.currencyName) = \(customRate, specifier: "%.2f") \(transaction.receivingCurrencyName ?? "")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Market Rate:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1 \(transaction.currencyName) = \(marketRate, specifier: "%.2f") \(transaction.receivingCurrencyName ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let profit = transaction.profitAmount, profit > 0 {
                        HStack {
                            Text("Profit Made:")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("+\(profit, specifier: "%.2f") \(transaction.receivingCurrencyName ?? "")")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Transaction flow
            HStack(spacing: 12) {
                // Giver
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        if transaction.giver == "myself_special_id" {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.callout)
                                .foregroundColor(.blue)
                        }
                        Text(transaction.giverName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(transaction.giver == "myself_special_id" ? .blue : .primary)
                    }
                }
                
                // Arrow
                Image(systemName: transaction.isExchange ? "arrow.triangle.2.circlepath" : "arrow.right")
                    .font(.body)
                    .foregroundColor(.blue)
                
                // Taker
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        if transaction.taker == "myself_special_id" {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.callout)
                                .foregroundColor(.blue)
                        }
                        Text(transaction.takerName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(transaction.taker == "myself_special_id" ? .blue : .primary)
                    }
                }
                
                Spacer()
            }
            
            // Balances after transaction
            VStack(alignment: .leading, spacing: 12) {
                Text("Balances after transaction")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                HStack(alignment: .top, spacing: 20) {
                    // Giver balances
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            if transaction.giver == "myself_special_id" {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            Text(transaction.giverName)
                                .font(.caption)
                                .foregroundColor(transaction.giver == "myself_special_id" ? .blue : .secondary)
                                .fontWeight(.medium)
                        }
                        
                        // Replace the balance display sections in TransactionRowView
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(giverBalances.keys.sorted()), id: \.self) { currencyKey in
                                if let balance = giverBalances[currencyKey] {
                                    let roundedBalance = round(balance * 100) / 100  // Round to 2 decimal places
                                    HStack(spacing: 4) {
                                        Text(currencyKey == "amount" ? "CAD" : currencyKey)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(roundedBalance, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(abs(roundedBalance) < 0.01 ? .gray : (roundedBalance > 0 ? .green : .red))
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Taker balances
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            if transaction.taker == "myself_special_id" {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            Text(transaction.takerName)
                                .font(.caption)
                                .foregroundColor(transaction.taker == "myself_special_id" ? .blue : .secondary)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(takerBalances.keys.sorted()), id: \.self) { currencyKey in
                                if let balance = takerBalances[currencyKey] {
                                    let roundedBalance = round(balance * 100) / 100  // Round to 2 decimal places
                                    HStack(spacing: 4) {
                                        Text(currencyKey == "amount" ? "CAD" : currencyKey)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(roundedBalance, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(abs(roundedBalance) < 0.01 ? .gray : (roundedBalance > 0 ? .green : .red))
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Notes (if any)
            if !transaction.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    Text(transaction.notes)
                        .font(.callout)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
