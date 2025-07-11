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
        guard !balanceData.isEmpty else {
            return ["All", "CAD"] // Return default currencies if no data
        }
        
        let allCurrencies = Set(balanceData.flatMap { $0.currencyBalances.keys })
        return ["All", "CAD"] + Array(allCurrencies.filter { $0 != "CAD" }).sorted()
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
        VStack(spacing: 16) {
            // Title and refresh
            HStack {
                VStack(alignment: .leading) {
                    Text("Balance Report")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Net balance with contacts • Tap to view details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: fetchAllBalances) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
            
            // Search bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by name or balance...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.systemBackgroundColor)
                .cornerRadius(10)
                
                Button(action: { showingFilters.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Filters (if showing)
            if showingFilters {
                filtersSection
            }
        }
        .padding()
        .background(Color.systemBackgroundColor)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Currency filter and sort
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Currency", selection: $selectedCurrencyFilter) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sort by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Sort", selection: $sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: { sortAscending.toggle() }) {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Amount range filter
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0.00", text: $minAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("999999.99", text: $maxAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                Button("Clear") {
                    clearFilters()
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.systemGray6Color)
        .cornerRadius(12)
    }
    
    private var balanceTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Table header
                tableHeaderView
                
                // Table rows with grid lines
                ForEach(filteredData.indices, id: \.self) { index in
                    let customer = filteredData[index]
                    CustomerBalanceRow(
                        customer: customer,
                        currencies: currencies.filter { $0 != "All" },
                        isEven: index % 2 == 0,
                        showGridLines: true
                    )
                }
            }
            .overlay(
                // Vertical grid lines
                HStack(spacing: 0) {
                    ForEach(0..<(currencies.filter { $0 != "All" }.count + 1), id: \.self) { index in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1)
                        if index == 0 {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        } else if index < currencies.filter { $0 != "All" }.count {
                            Spacer()
                                .frame(width: 100)
                        }
                    }
                }
            )
        }
        .background(Color.systemBackgroundColor)
    }
    
    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            // Person column
            VStack(spacing: 2) {
                Text("Person")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemGray5Color)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                    .offset(x: 0.5),
                alignment: .trailing
            )
            
            // Currency columns
            ForEach(currencies.filter { $0 != "All" }, id: \.self) { currency in
                VStack(spacing: 2) {
                    Text(currency)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 100)
                .padding(.vertical, 12)
                .background(Color.systemGray5Color)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: 0.5),
                    alignment: .trailing
                )
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
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
    
    var body: some View {
        HStack(spacing: 0) {
            // Person info column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Customer type indicator
                    Circle()
                        .fill(customer.type == .customer ? Color.blue :
                              customer.type == .middleman ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(customer.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Text(customer.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isEven ? Color.systemBackgroundColor : Color.systemGray6Color)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                    .offset(x: 0.5),
                alignment: .trailing
            )
            
            // Currency balance columns
            ForEach(currencies, id: \.self) { currency in
                VStack(spacing: 4) {
                    let balance = currency == "CAD" ? customer.cadBalance : (customer.currencyBalances[currency] ?? 0)
                    let roundedBalance = round(balance * 100) / 100
                    
                    if abs(roundedBalance) >= 0.01 {
                        Text("\(roundedBalance, specifier: "%.2f")")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(roundedBalance > 0 ? .green : .red)
                        
                        Text(roundedBalance > 0 ? "To Receive" : "To Pay")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(roundedBalance > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            )
                            .foregroundColor(roundedBalance > 0 ? .green : .red)
                    } else {
                        Text("0.00")
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        Text("Settled")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.15))
                            )
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 100)
                .padding(.vertical, 12)
                .background(isEven ? Color.systemBackgroundColor : Color.systemGray6Color)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: 0.5),
                    alignment: .trailing
                )
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
