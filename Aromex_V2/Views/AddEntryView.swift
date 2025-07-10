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
                VStack(spacing: 24) {
                    // Transaction Section
                    transactionSection
                    
                    // Debug Info and Network Status
                    if firebaseManager.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading customers...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    if !firebaseManager.isConnected {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.red)
                            Text("No internet connection")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Button("Retry") {
                                firebaseManager.retryConnection()
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 32)
                    }
                    
                    if !firebaseManager.errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(firebaseManager.errorMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Button("Retry") {
                                firebaseManager.retryConnection()
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 32)
                    }
                    
                    // Customer count for debugging
                    HStack {
                        Image(systemName: firebaseManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(firebaseManager.isConnected ? .green : .red)
                        Text("Found \(firebaseManager.customers.count) customers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if firebaseManager.isConnected {
                            Text("• Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .padding(.top, 32)
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
                HStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("AROMEX")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Center Title
                Text("Transaction Entry")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // User Profile
                Button(action: {}) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(height: 80)
    }
    
    private var transactionSection: some View {
        VStack(spacing: 32) {
            // Section Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("New Transaction")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Exchange Toggle
                HStack(spacing: 12) {
                    Text("Exchange")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: $isExchangeOn)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 32)
            
            // Transaction Form
            VStack(spacing: 24) {
                // Main Transaction Row
                HStack(spacing: 16) {
                    // From Dropdown
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SimpleDropdownButton(
                            selectedCustomer: selectedFromCustomer,
                            placeholder: "Select customer",
                            isOpen: $selectedFromDropdownOpen,
                            buttonFrame: $fromButtonFrame
                        )
                        .frame(width: 160)
                    }
                    
                    // Arrow with "gives to"
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("gives to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(width: 80)
                    
                    // To Dropdown
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SimpleDropdownButton(
                            selectedCustomer: selectedToCustomer,
                            placeholder: "Select customer",
                            isOpen: $selectedToDropdownOpen,
                            buttonFrame: $toButtonFrame
                        )
                        .frame(width: 160)
                    }
                    
                    // Amount Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("USD")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Amount", text: $amount)
                                .font(.subheadline)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .frame(width: 120)
                    
                    // Add Customer Button
                    VStack(spacing: 6) {
                        Text("")
                            .font(.caption)
                        
                        Button(action: {
                            showingAddCustomerDialog = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add Entry Button
                    VStack(spacing: 6) {
                        Text("")
                            .font(.caption)
                        
                        Button(action: {
                            // Non-functional as requested
                        }) {
                            Text("Add Entry")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.3, green: 0.4, blue: 0.6))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 32)
                
                // Notes Section
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                    
                    TextField("Add notes (optional)", text: $notes)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 24)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
            HStack(spacing: 8) {
                if let selectedCustomer = selectedCustomer {
                    Text(selectedCustomer.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOpen ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
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
        .frame(width: 200)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)
            
            TextField("Search...", text: $searchText)
                .font(.caption)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        .frame(height: min(CGFloat(filteredCustomers.count) * 44, 200))
    }
    
    private func customerRow(customer: Customer) -> some View {
        Button(action: {
            withAnimation {
                selectedCustomer = customer
                isOpen = false
            }
        }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("$\(customer.balance, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundColor(customer.balance >= 0 ? .green : .red)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
                        y: buttonFrame.maxY + 10 + (min(CGFloat(filteredCustomers.count) * 44, 200) / 2)
                    )
            )
    }
}
