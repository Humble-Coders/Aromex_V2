import SwiftUI
#if os(macOS)
import AppKit
#endif

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

struct AddEntryView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @State private var selectedFromCustomer: Customer?
    @State private var selectedToCustomer: Customer?
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var isExchangeOn: Bool = false
    @State private var showingAddCustomerDialog: Bool = false
    
    // Dropdown states for global overlays
    @State private var selectedFromDropdownOpen: Bool = false
    @State private var selectedToDropdownOpen: Bool = false
    @State private var fromButtonFrame: CGRect = .zero
    @State private var toButtonFrame: CGRect = .zero
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Professional Header
                headerView
                
                // Main Content Area
                VStack(spacing: 32) {
                    // Transaction Section
                    transactionSection
                    
                    // Debug Info and Network Status
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
                        .padding(.horizontal, 32)
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
                        .padding(.horizontal, 32)
                    }
                    
                    // Customer count for debugging
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
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .padding(.top, 40)
                .background(Color.systemBackground)
            }
            
            // Dropdown overlays
            if selectedFromDropdownOpen {
                CustomerDropdownOverlay(
                    isOpen: $selectedFromDropdownOpen,
                    selectedCustomer: $selectedFromCustomer,
                    customers: firebaseManager.customers,
                    buttonFrame: fromButtonFrame
                )
            }
            
            if selectedToDropdownOpen {
                CustomerDropdownOverlay(
                    isOpen: $selectedToDropdownOpen,
                    selectedCustomer: $selectedToCustomer,
                    customers: firebaseManager.customers,
                    buttonFrame: toButtonFrame
                )
            }
        }
        .sheet(isPresented: $showingAddCustomerDialog) {
            AddCustomerDialog()
        }
    }
    
    private var headerView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.5),
                    Color(red: 0.3, green: 0.4, blue: 0.6)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
            HStack {
                // Logo and Title
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
                
                // Center Title
                Text("Transaction Entry")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // User Profile
                Button(action: {}) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .frame(height: 100)
    }
    
    private var transactionSection: some View {
        VStack(spacing: 40) {
            // Section Header
            HStack {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("New Transaction")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Exchange Toggle
                HStack(spacing: 16) {
                    Text("Exchange")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: $isExchangeOn)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .scaleEffect(1.2)
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 32)
            
            // Transaction Form
            VStack(spacing: 32) {
                // Main Transaction Row
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
                            buttonFrame: $fromButtonFrame
                        )
                        .frame(width: 200, height: 50)
                    }
                    
                    // Arrow with "gives to"
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
                            buttonFrame: $toButtonFrame
                        )
                        .frame(width: 200, height: 50)
                    }
                    
                    // Amount Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount (USD)")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Text("$")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("0.00", text: $amount)
                                .font(.body)
                                .fontWeight(.medium)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
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
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(height: 50)
                    }
                    .frame(width: 140)
                    
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
                            // Non-functional as requested
                        }) {
                            Text("Add Entry")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.3, green: 0.4, blue: 0.6),
                                            Color(red: 0.25, green: 0.35, blue: 0.55)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: Color(red: 0.3, green: 0.4, blue: 0.6).opacity(0.3), radius: 4, x: 0, y: 2)
                                .frame(height: 50)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 32)
                
                // Notes Section
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
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 32)
        }
    }
}

// Simple dropdown button that just opens overlay
struct SimpleDropdownButton: View {
    let selectedCustomer: Customer?
    let placeholder: String
    @Binding var isOpen: Bool
    @Binding var buttonFrame: CGRect
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOpen.toggle()
            }
        }) {
            HStack(spacing: 12) {
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
        }
        .buttonStyle(PlainButtonStyle())
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

// Global dropdown overlay that appears above everything
struct CustomerDropdownOverlay: View {
    @Binding var isOpen: Bool
    @Binding var selectedCustomer: Customer?
    let customers: [Customer]
    let buttonFrame: CGRect
    
    @State private var searchText: String = ""
    
    private var filteredCustomers: [Customer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var dropdownContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            Divider()
            customerList
        }
        .frame(width: 250)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 6)
    }
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.body)
            
            TextField("Search...", text: $searchText)
                .font(.body)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
    }
    
    private var customerList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(filteredCustomers) { customer in
                    customerRow(customer: customer)
                }
            }
        }
        .frame(height: min(CGFloat(filteredCustomers.count) * 60, 240))
    }
    
    private func customerRow(customer: Customer) -> some View {
        Button(action: {
            withAnimation {
                selectedCustomer = customer
                isOpen = false
            }
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(customer.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("[\(customer.type.shortTag)]")
                            .font(.caption)
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
                    
                    Text("$\(customer.balance, specifier: "%.2f")")
                        .font(.callout)
                        .foregroundColor(customer.balance >= 0 ? .green : .red)
                }
                
                Spacer()
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
    }
    
    var body: some View {
        // Full screen background to catch taps outside
        Color.black.opacity(0.001)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
                withAnimation {
                    isOpen = false
                }
            }
            .overlay(
                dropdownContent
                    .position(
                        x: buttonFrame.midX,
                        y: buttonFrame.maxY + 15 + (min(CGFloat(filteredCustomers.count) * 60, 240) / 2)
                    )
            )
    }
}
