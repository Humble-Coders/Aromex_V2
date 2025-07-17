import SwiftUI
import FirebaseFirestore

struct AddCustomerDialog: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var currencyManager = CurrencyManager.shared
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var nameError: String = ""
    @State private var isAdding: Bool = false
    
    // Initial Balance Fields
    @State private var initialBalance: String = ""
    @State private var selectedCurrency: Currency?
    @State private var balanceType: BalanceType = .toReceive
    @State private var entityType: EntityType = .customer
    @State private var balanceError: String = ""
    
    // Dropdown states
    @State private var currencyDropdownOpen: Bool = false
    @State private var currencyButtonFrame: CGRect = .zero
    
    enum BalanceType: String, CaseIterable {
        case toReceive = "To Receive"
        case toGive = "To Give"
        
        var color: Color {
            switch self {
            case .toReceive: return .green
            case .toGive: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .toReceive: return "plus.circle.fill"
            case .toGive: return "minus.circle.fill"
            }
        }
    }
    
    enum EntityType: String, CaseIterable {
        case customer = "Customer"
        case supplier = "Supplier"
        case middleman = "Middleman"
        
        var collectionName: String {
            switch self {
            case .customer: return "Customers"
            case .supplier: return "Suppliers"
            case .middleman: return "Middlemen"
            }
        }
        
        var customerType: CustomerType {
            switch self {
            case .customer: return .customer
            case .supplier: return .supplier
            case .middleman: return .middleman
            }
        }
        
        var color: Color {
            switch self {
            case .customer: return .blue
            case .supplier: return .green
            case .middleman: return .orange
            }
        }
    }
    
    // Theme colors
    let mainColor = Color(red: 0.23, green: 0.28, blue: 0.42)
    let sectionBg = Color.white
    let fieldCornerRadius: CGFloat = 10
    let fieldHeight: CGFloat = 50
    
    // Responsive properties
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    private var dialogWidth: CGFloat {
        #if os(macOS)
        return 950
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - 40
        } else {
            return min(800, UIScreen.main.bounds.width - 80)
        }
        #endif
    }
    
    private var dialogHeight: CGFloat {
        #if os(macOS)
        return 700
        #else
        if shouldUseVerticalLayout {
            return min(UIScreen.main.bounds.height - 100, 750)
        } else {
            return min(700, UIScreen.main.bounds.height - 100)
        }
        #endif
    }
    
    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 48
        #else
        return shouldUseVerticalLayout ? 24 : 32
        #endif
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text("Add \(entityType.rawValue)")
                        .font(.system(size: shouldUseVerticalLayout ? 28 : 34, weight: .bold, design: .serif))
                        .foregroundColor(mainColor)
                        .padding(.top, shouldUseVerticalLayout ? 20 : 28)
                        .padding(.leading, horizontalPadding)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 24) {
                        // Entity Type Selection
                        entityTypeSection
                        
                        // Basic Information Section
                        basicInformationSection
                        
                        // Initial Balance Section
                        initialBalanceSection
                    }
                    .padding(.horizontal, horizontalPadding)
                    
                    // Action Buttons
                    actionButtons
                        .padding(.top, 28)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 32)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(sectionBg)
                    .shadow(color: .black.opacity(0.13), radius: 36, x: 0, y: 12)
            )
            .frame(width: dialogWidth, height: dialogHeight)
            
            // Currency Dropdown Overlay
            if currencyDropdownOpen {
                CurrencyDropdownOverlay(
                    isOpen: $currencyDropdownOpen,
                    selectedCurrency: $selectedCurrency,
                    currencies: currencyManager.allCurrencies,
                    buttonFrame: currencyButtonFrame,
                    onAddCurrency: {
                        currencyDropdownOpen = false
                    }
                )
            }
        }
        .onAppear {
            currencyManager.fetchCurrencies()
            // Set default currency to CAD
            selectedCurrency = currencyManager.allCurrencies.first { $0.name == "CAD" }
        }
    }
    
    private var entityTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Entity Type")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(mainColor)
            
            if shouldUseVerticalLayout {
                VStack(spacing: 12) {
                    ForEach(EntityType.allCases, id: \.self) { type in
                        entityTypeButton(type: type)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(EntityType.allCases, id: \.self) { type in
                        entityTypeButton(type: type)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemGray6.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(entityType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func entityTypeButton(type: EntityType) -> some View {
        Button(action: {
            entityType = type
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(entityType == type ? type.color : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: entityType == type ? "checkmark" : "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text(type.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(entityType == type ? type.color : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(entityType == type ? type.color.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(entityType == type ? type.color.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var basicInformationSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Basic Information")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(mainColor)
            
            if shouldUseVerticalLayout {
                verticalFieldsLayout
            } else {
                horizontalFieldsLayout
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var initialBalanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Initial Balance (Optional)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(mainColor)
            
            VStack(spacing: 16) {
                // Balance Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Balance Type")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        ForEach(BalanceType.allCases, id: \.self) { type in
                            Button(action: {
                                balanceType = type
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(balanceType == type ? .white : type.color)
                                    
                                    Text(type.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(balanceType == type ? .white : type.color)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(balanceType == type ? type.color : type.color.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(type.color.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                    }
                }
                
                // Currency and Amount Row
                if shouldUseVerticalLayout {
                    VStack(spacing: 16) {
                        currencySelectionField
                        balanceAmountField
                    }
                } else {
                    HStack(spacing: 20) {
                        currencySelectionField
                        balanceAmountField
                    }
                }
                
                // Balance Preview
                if !initialBalance.trimmingCharacters(in: .whitespaces).isEmpty {
                    balancePreview
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var currencySelectionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currency")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Button(action: {
                currencyDropdownOpen.toggle()
            }) {
                HStack(spacing: 12) {
                    Text(selectedCurrency?.symbol ?? "$")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 20)
                    
                    Text(selectedCurrency?.name ?? "CAD")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: currencyDropdownOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .frame(height: fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: fieldCornerRadius)
                        .fill(sectionBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: fieldCornerRadius)
                                .stroke(currencyDropdownOpen ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: currencyDropdownOpen ? 2 : 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            currencyButtonFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            currencyButtonFrame = newFrame
                        }
                }
            )
        }
        .frame(maxWidth: shouldUseVerticalLayout ? .infinity : 200)
    }
    
    private var balanceAmountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            TextField("0.00", text: $initialBalance)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .padding(.horizontal, 16)
                .frame(height: fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: fieldCornerRadius)
                        .fill(sectionBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: fieldCornerRadius)
                                .stroke(balanceError.isEmpty ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                        )
                )
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            
            if !balanceError.isEmpty {
                Text(balanceError)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var balancePreview: some View {
        VStack(spacing: 8) {
            Text("Balance Preview")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            if let amount = Double(initialBalance.trimmingCharacters(in: .whitespaces)) {
                let finalAmount = balanceType == .toGive ? -abs(amount) : abs(amount)
                
                HStack(spacing: 12) {
                    Image(systemName: balanceType.icon)
                        .font(.system(size: 16))
                        .foregroundColor(balanceType.color)
                    
                    Text("\(finalAmount, specifier: "%.2f") \(selectedCurrency?.name ?? "CAD")")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(balanceType.color)
                    
                    Text("(\(balanceType.rawValue))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(balanceType.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(balanceType.color.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var verticalFieldsLayout: some View {
        VStack(spacing: 20) {
            // Name Field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Name")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(mainColor)
                    Text("*")
                        .foregroundColor(.red)
                }
                TextField("Enter \(entityType.rawValue.lowercased()) name", text: $name)
                    .font(.system(size: 18, weight: .medium, design: .default))
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
            
            // Phone Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Phone")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(mainColor)
                TextField("Enter phone number", text: $phone)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .padding(.horizontal, 16)
                    .frame(height: fieldHeight)
                    .background(sectionBg)
                    .cornerRadius(fieldCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: fieldCornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                    )
#if os(iOS)
                    .keyboardType(.phonePad)
#endif
            }
            
            // Email Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(mainColor)
                TextField("Enter email address", text: $email)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .padding(.horizontal, 16)
                    .frame(height: fieldHeight)
                    .background(sectionBg)
                    .cornerRadius(fieldCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: fieldCornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                    )
#if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
#endif
            }
            
            // Address Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Address")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(mainColor)
                TextField("Enter address", text: $address)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .padding(.horizontal, 16)
                    .frame(height: fieldHeight)
                    .background(sectionBg)
                    .cornerRadius(fieldCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: fieldCornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                    )
            }
            
            // Notes Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(mainColor)
                TextField("Enter notes", text: $notes)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .padding(.horizontal, 16)
                    .frame(height: fieldHeight)
                    .background(sectionBg)
                    .cornerRadius(fieldCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: fieldCornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                    )
            }
        }
    }
    
    private var horizontalFieldsLayout: some View {
        VStack(spacing: 24) {
            // Name, Phone, Email in a single row
            HStack(spacing: 20) {
                // Name Field
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        Text("Name")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundColor(mainColor)
                        Text("*")
                            .foregroundColor(.red)
                    }
                    TextField("Enter \(entityType.rawValue.lowercased()) name", text: $name)
                        .font(.system(size: 18, weight: .medium, design: .default))
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
                
                // Phone Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phone")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(mainColor)
                    TextField("Enter phone", text: $phone)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .padding(.horizontal, 16)
                        .frame(height: fieldHeight)
                        .background(sectionBg)
                        .cornerRadius(fieldCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: fieldCornerRadius)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                        )
#if os(iOS)
                        .keyboardType(.phonePad)
#endif
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(mainColor)
                    TextField("Enter email", text: $email)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .padding(.horizontal, 16)
                        .frame(height: fieldHeight)
                        .background(sectionBg)
                        .cornerRadius(fieldCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: fieldCornerRadius)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                        )
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
#endif
                }
            }
            .frame(maxWidth: .infinity)
            
            // Address Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Address")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(mainColor)
                TextField("Enter address", text: $address)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .padding(.horizontal, 16)
                    .frame(height: fieldHeight)
                    .background(sectionBg)
                    .cornerRadius(fieldCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: fieldCornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                    )
            }
            
            // Notes Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(mainColor)
                TextField("Enter notes", text: $notes)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .padding(.horizontal, 16)
                    .frame(height: fieldHeight)
                    .background(sectionBg)
                    .cornerRadius(fieldCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: fieldCornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1.2)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        if shouldUseVerticalLayout {
            VStack(spacing: 16) {
                // Add Entity Button
                Button(action: addEntity) {
                    Text(isAdding ? "Adding..." : "Add \(entityType.rawValue)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 45)
                        .background((name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding) ?
                                    Color.gray.opacity(0.22) : entityType.color.opacity(0.97))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
                .buttonStyle(PlainButtonStyle())
                
                // Cancel Button
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 45)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .opacity(isAdding ? 0.6 : 1)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAdding)
            }
        } else {
            HStack(spacing: 20) {
                Spacer()
                
                // Cancel Button
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .frame(width: 130, height: 45)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .opacity(isAdding ? 0.6 : 1)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAdding)
                
                // Add Entity Button
                Button(action: addEntity) {
                    Text(isAdding ? "Adding..." : "Add \(entityType.rawValue)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .frame(width: 200, height: 45)
                        .background((name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding) ?
                                    Color.gray.opacity(0.22) : entityType.color.opacity(0.97))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func addEntity() {
        nameError = ""
        balanceError = ""
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Validate name
        guard !trimmedName.isEmpty else {
            nameError = "Name is required."
            return
        }
        
        // Check for duplicate in the appropriate collection
        let existingEntities = firebaseManager.customers.filter { $0.type == entityType.customerType }
        if existingEntities.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            nameError = "A \(entityType.rawValue.lowercased()) with this name already exists."
            return
        }
        
        // Validate balance if provided
        var finalBalance: Double = 0.0
        if !initialBalance.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let balanceValue = Double(initialBalance.trimmingCharacters(in: .whitespaces)) else {
                balanceError = "Please enter a valid number."
                return
            }
            
            // Apply sign based on balance type
            finalBalance = balanceType == .toGive ? -abs(balanceValue) : abs(balanceValue)
        }
        
        isAdding = true
        
        // Prepare Firestore data
        let entityId = UUID().uuidString
        let now = Date()
        let timestamp = Timestamp(date: now)
        
        let cadBalance = (selectedCurrency?.name == "CAD") ? finalBalance : 0.0
        
        let entityData: [String: Any] = [
            "name": trimmedName,
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "email": email.trimmingCharacters(in: .whitespaces),
            "address": address.trimmingCharacters(in: .whitespaces),
            "notes": notes.trimmingCharacters(in: .whitespaces),
            "balance": cadBalance,
            "createdAt": timestamp,
            "updatedAt": timestamp,
            "transactionHistory": []
        ]
        
        Task {
            do {
                // Add to appropriate collection
                try await addEntityToFirestore(entityId: entityId, data: entityData)
                
                // If balance is in non-CAD currency, add to CurrencyBalances
                if let currency = selectedCurrency, currency.name != "CAD" && abs(finalBalance) > 0 {
                    try await addCurrencyBalance(entityId: entityId, currency: currency.name, balance: finalBalance)
                }
                
                DispatchQueue.main.async {
                    self.isAdding = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAdding = false
                    self.nameError = "Failed to add \(self.entityType.rawValue.lowercased()). Try again."
                }
            }
        }
    }
    
    private func addEntityToFirestore(entityId: String, data: [String: Any]) async throws {
        let db = Firestore.firestore()
        try await db.collection(entityType.collectionName).document(entityId).setData(data)
        print("✅ \(entityType.rawValue) added to \(entityType.collectionName) collection")
    }
    
    private func addCurrencyBalance(entityId: String, currency: String, balance: Double) async throws {
        let db = Firestore.firestore()
        let currencyData: [String: Any] = [
            currency: balance,
            "updatedAt": Timestamp()
        ]
        try await db.collection("CurrencyBalances").document(entityId).setData(currencyData, merge: true)
        print("✅ Currency balance added: \(balance) \(currency) for entity \(entityId)")
    }
}
