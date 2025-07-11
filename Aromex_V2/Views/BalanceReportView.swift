import SwiftUI
import FirebaseFirestore

// Color extension for cross-platform compatibility
extension Color {
    
    static var systemGray6Color: Color {
        #if os(macOS)
        return Color(NSColor.controlColor)
        #else
        return Color(.systemGray6)
        #endif
    }
    
    static var systemGray5Color: Color {
        #if os(macOS)
        return Color(NSColor.unemphasizedSelectedContentBackgroundColor)
        #else
        return Color(.systemGray5)
        #endif
    }
}

struct BalanceReportView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var balanceData: [CustomerBalanceData] = []
    @State private var filteredData: [CustomerBalanceData] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedCurrencyFilter = "All"
    @State private var minAmount = ""
    @State private var maxAmount = ""
    @State private var showingFilters = false
    @State private var sortBy: SortOption = .name
    @State private var sortAscending = true
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private let db = Firestore.firestore()
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case totalBalance = "Total Balance"
        case cadBalance = "CAD Balance"
        case lastUpdated = "Last Updated"
    }
    
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    private var currencies: [String] {
        // Always show all available currencies from the currency manager
        let allAvailableCurrencies = currencyManager.allCurrencies.map { $0.name }
        return ["All"] + allAvailableCurrencies.sorted()
    }
    
    private var displayCurrencies: [String] {
        // Currencies to display in the table (excluding "All")
        return currencies.filter { $0 != "All" }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerSection
            
            // Balance table
            if isLoading {
                loadingView
            } else if filteredData.isEmpty {
                emptyStateView
            } else {
                balanceTableView
            }
        }
        .background(Color.systemGroupedBackground)
        .onAppear {
            currencyManager.fetchCurrencies()
            fetchAllBalances()
        }
        .onChange(of: searchText) { _ in
            applyFilters()
        }
        .onChange(of: selectedCurrencyFilter) { _ in
            applyFilters()
        }
        .onChange(of: minAmount) { _ in
            applyFilters()
        }
        .onChange(of: maxAmount) { _ in
            applyFilters()
        }
        .onChange(of: sortBy) { _ in
            applySorting()
        }
        .onChange(of: sortAscending) { _ in
            applySorting()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Title and refresh
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance Report")
                        .font(.system(size: shouldUseVerticalLayout ? 28 : 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Net balance with contacts • Tap to view details")
                        .font(.system(size: shouldUseVerticalLayout ? 14 : 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: fetchAllBalances) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                        if !shouldUseVerticalLayout {
                            Text("Refresh")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, shouldUseVerticalLayout ? 12 : 16)
                    .padding(.vertical, shouldUseVerticalLayout ? 8 : 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(isLoading)
                .buttonStyle(PlainButtonStyle())
            }
            
            // Search and Filter Controls
            VStack(spacing: 16) {
                // Search bar with improved styling
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Search by name or balance...", text: $searchText)
                            .font(.system(size: 16, weight: .medium))
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.systemGray6Color)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingFilters.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 16, weight: .medium))
                            if !shouldUseVerticalLayout {
                                Text("Filters")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(showingFilters ? .white : .blue)
                        .padding(.horizontal, shouldUseVerticalLayout ? 12 : 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(showingFilters ? Color.blue : Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: showingFilters ? .blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Filters (if showing)
                if showingFilters {
                    filtersSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
            }
        }
        .padding(.horizontal, shouldUseVerticalLayout ? 16 : 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, shouldUseVerticalLayout ? 16 : 24)
        .padding(.top, 16)
    }
    
    private var filtersSection: some View {
        VStack(spacing: 20) {
            // First row: Currency filter and Sort controls
            HStack(spacing: shouldUseVerticalLayout ? 12 : 20) {
                // Currency Filter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filter by Currency")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Picker("Currency", selection: $selectedCurrencyFilter) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.systemGray6Color)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                
                // Sort By
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort by")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Picker("Sort", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.systemGray6Color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        
                        Button(action: { sortAscending.toggle() }) {
                            Image(systemName: sortAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Second row: Amount range filters
            HStack(spacing: shouldUseVerticalLayout ? 12 : 20) {
                // Min Amount
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Amount")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("0.00", text: $minAmount)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.systemGray6Color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                // Max Amount
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maximum Amount")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("999999.99", text: $maxAmount)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.systemGray6Color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                // Clear Filters Button
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Button(action: clearFilters) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Clear All")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemGray6Color.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var balanceTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Table header
                tableHeaderView
                
                // Table rows
                ForEach(filteredData.indices, id: \.self) { index in
                    let customer = filteredData[index]
                    CustomerBalanceRow(
                        customer: customer,
                        currencies: displayCurrencies,
                        isEven: index % 2 == 0,
                        showGridLines: true
                    )
                }
            }
            .background(Color.systemBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, shouldUseVerticalLayout ? 16 : 24)
        .padding(.bottom, 20)
    }
    
    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            // Person column
            VStack(spacing: 4) {
                Text("Contact")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Name & Type")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: shouldUseVerticalLayout ? 140 : 200, maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 1),
                alignment: .trailing
            )
            
            // Currency columns
            ForEach(displayCurrencies, id: \.self) { currency in
                VStack(spacing: 4) {
                    Text(currency)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Balance")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: shouldUseVerticalLayout ? 120 : 140)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.gray.opacity(0.08), Color.gray.opacity(0.04)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1),
                    alignment: .trailing
                )
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading balance data...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Balance Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No customers have outstanding balances matching your filters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Clear Filters") {
                clearFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }
    
    private func fetchAllBalances() {
        isLoading = true
        balanceData.removeAll()
        filteredData.removeAll() // Clear filtered data immediately
        
        let group = DispatchGroup()
        var tempBalanceData: [CustomerBalanceData] = []
        
        // Safety check for empty customers
        guard !firebaseManager.customers.isEmpty else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.applyFilters()
            }
            return
        }
        
        // Fetch all customers
        for customer in firebaseManager.customers {
            group.enter()
            
            var customerBalance = CustomerBalanceData(
                id: customer.id ?? UUID().uuidString,
                name: customer.name,
                type: customer.type,
                cadBalance: customer.balance,
                currencyBalances: [:],
                totalBalance: customer.balance,
                lastUpdated: Date()
            )
            
            // Fetch other currency balances from CurrencyBalances collection
            if let customerId = customer.id, !customerId.isEmpty {
                db.collection("CurrencyBalances").document(customerId).getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error fetching currency balances for \(customer.name): \(error.localizedDescription)")
                        // Still add customer even if currency fetch fails
                        if abs(customerBalance.cadBalance) >= 0.01 {
                            tempBalanceData.append(customerBalance)
                        }
                        return
                    }
                    
                    if let data = snapshot?.data() {
                        var currencyBalances: [String: Double] = [:]
                        var total = customer.balance // Start with CAD balance
                        
                        for (key, value) in data {
                            if key != "updatedAt" && key != "createdAt", let doubleValue = value as? Double {
                                currencyBalances[key] = doubleValue
                                // Add to total (simplified conversion - could use actual exchange rates)
                                total += doubleValue
                            }
                        }
                        
                        customerBalance.currencyBalances = currencyBalances
                        customerBalance.totalBalance = total
                        
                        if let updatedAt = data["updatedAt"] as? Timestamp {
                            customerBalance.lastUpdated = updatedAt.dateValue()
                        }
                        
                        print("💰 Loaded balances for \(customer.name): CAD=\(customer.balance), Others=\(currencyBalances)")
                    }
                    
                    // Add customers with any non-zero balances (CAD or other currencies)
                    if abs(customerBalance.cadBalance) >= 0.01 ||
                       customerBalance.currencyBalances.values.contains(where: { abs($0) >= 0.01 }) {
                        tempBalanceData.append(customerBalance)
                    }
                }
            } else {
                // If no valid customer ID, just check CAD balance
                if abs(customerBalance.cadBalance) >= 0.01 {
                    tempBalanceData.append(customerBalance)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.balanceData = tempBalanceData
            self.applyFilters()
            self.isLoading = false
            print("✅ Balance report loaded with \(tempBalanceData.count) customers")
        }
    }
    
    private func applyFilters() {
        var filtered = balanceData
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.currencyBalances.contains { currency, balance in
                    "\(balance)".contains(searchText)
                } ||
                "\(customer.cadBalance)".contains(searchText)
            }
        }
        
        // Currency filter
        if selectedCurrencyFilter != "All" {
            filtered = filtered.filter { customer in
                if selectedCurrencyFilter == "CAD" {
                    return abs(customer.cadBalance) >= 0.01
                } else {
                    return customer.currencyBalances[selectedCurrencyFilter] != nil &&
                           abs(customer.currencyBalances[selectedCurrencyFilter] ?? 0) >= 0.01
                }
            }
        }
        
        // Amount range filter
        if let minVal = Double(minAmount) {
            filtered = filtered.filter { abs($0.totalBalance) >= minVal }
        }
        
        if let maxVal = Double(maxAmount) {
            filtered = filtered.filter { abs($0.totalBalance) <= maxVal }
        }
        
        filteredData = filtered
        applySorting()
    }
    
    private func applySorting() {
        filteredData.sort { first, second in
            let result: Bool
            
            switch sortBy {
            case .name:
                result = first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .totalBalance:
                result = abs(first.totalBalance) < abs(second.totalBalance)
            case .cadBalance:
                result = abs(first.cadBalance) < abs(second.cadBalance)
            case .lastUpdated:
                result = first.lastUpdated < second.lastUpdated
            }
            
            return sortAscending ? result : !result
        }
    }
    
    private func clearFilters() {
        searchText = ""
        selectedCurrencyFilter = "All"
        minAmount = ""
        maxAmount = ""
    }
}

struct CustomerBalanceData: Identifiable {
    let id: String
    let name: String
    let type: CustomerType
    var cadBalance: Double
    var currencyBalances: [String: Double]
    var totalBalance: Double
    var lastUpdated: Date
}

struct CustomerBalanceRow: View {
    let customer: CustomerBalanceData
    let currencies: [String]
    let isEven: Bool
    let showGridLines: Bool
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Person info column
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Customer type indicator with better styling
                    RoundedRectangle(cornerRadius: 6)
                        .fill(customer.type == .customer ? Color.blue :
                              customer.type == .middleman ? Color.orange : Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Text(customer.type.shortTag)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(customer.type.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: shouldUseVerticalLayout ? 140 : 200, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isEven ? Color.systemBackgroundColor : Color.gray.opacity(0.02))
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1),
                alignment: .trailing
            )
            
            // Currency balance columns
            ForEach(currencies, id: \.self) { currency in
                VStack(spacing: 6) {
                    let balance = currency == "CAD" ? customer.cadBalance : (customer.currencyBalances[currency] ?? 0)
                    let roundedBalance = round(balance * 100) / 100
                    
                    if abs(roundedBalance) >= 0.01 {
                        Text("\(roundedBalance, specifier: "%.2f")")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(roundedBalance > 0 ? .green : .red)
                        
                        Text(roundedBalance > 0 ? "To Receive" : "To Pay")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(roundedBalance > 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                            )
                            .foregroundColor(roundedBalance > 0 ? .green : .red)
                    } else {
                        Text("0.00")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Text("Settled")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.12))
                            )
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: shouldUseVerticalLayout ? 120 : 140)
                .padding(.vertical, 16)
                .background(isEven ? Color.systemBackgroundColor : Color.gray.opacity(0.02))
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 1),
                    alignment: .trailing
                )
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
