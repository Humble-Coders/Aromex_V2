import SwiftUI
#if os(macOS)
import AppKit
#endif

// Cross-platform color extensions
extension Color {
    static var systemGroupedBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemGroupedBackground)
        #endif
    }
    
    static var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
}

struct ContentView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // Determine if we should use sidebar navigation
    private var shouldUseSidebar: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    var body: some View {
        Group {
            if shouldUseSidebar {
                // iPad landscape and macOS - use sidebar
                NavigationView {
                    SidebarView()
                        .frame(minWidth: 200, maxWidth: 250)
                    
                    MainContentView()
                        .frame(minWidth: 600)
                }
                .navigationTitle("AROMEX")
            } else {
                // iPhone and iPad portrait - use tab view
                TabView {
                    NavigationView {
                        MainContentView()
                            .navigationTitle("AROMEX")
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.large)
                            #endif
                    }
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Entry")
                    }
                    
                    NavigationView {
                        CustomerListView()
                            .navigationTitle("Customers")
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.large)
                            #endif
                    }
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Customers")
                    }
                    
                    NavigationView {
                        TransactionHistoryView()
                            .navigationTitle("History")
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.large)
                            #endif
                    }
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text("History")
                    }
                }
                .accentColor(Color(red: 0.23, green: 0.28, blue: 0.42))
            }
        }
        .environmentObject(firebaseManager)
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink(destination: AddEntryView()) {
                Label("Add Entry", systemImage: "plus.circle.fill")
            }
            
            NavigationLink(destination: CustomerListView()) {
                Label("Customers", systemImage: "person.3.fill")
            }
            
            NavigationLink(destination: TransactionHistoryView()) {
                Label("Transaction History", systemImage: "clock.fill")
            }
            
            Section("Reports") {
                NavigationLink(destination: BalanceReportView()) {
                    Label("Balance Report", systemImage: "chart.bar.fill")
                }
                
                NavigationLink(destination: CustomerAnalyticsView()) {
                    Label("Customer Analytics", systemImage: "chart.pie.fill")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("AROMEX")
    }
}

struct MainContentView: View {
    var body: some View {
        AddEntryView()
    }
}

// Placeholder views for navigation
struct CustomerListView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var columns: [GridItem] {
        #if os(macOS)
        return [GridItem(.adaptive(minimum: 300))]
        #else
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.adaptive(minimum: 300))]
        }
        #endif
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(firebaseManager.customers) { customer in
                    CustomerCard(customer: customer)
                }
            }
            .padding()
        }
        .background(Color.systemGroupedBackground)
        .onAppear {
            firebaseManager.fetchAllCustomers()
        }
    }
}

struct CustomerCard: View {
    let customer: Customer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !customer.phone.isEmpty {
                        Text(customer.phone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("[\(customer.type.shortTag)]")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(customer.type == .customer ? Color.blue :
                                customer.type == .middleman ? Color.orange : Color.green)
                    )
            }
            
            if !customer.email.isEmpty {
                Text(customer.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if !customer.address.isEmpty {
                Text(customer.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Divider()
            
            HStack {
                Text("Balance:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("$\(customer.balance, specifier: "%.2f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(customer.balance >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct TransactionHistoryView: View {
    var body: some View {
        VStack {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Transaction History")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.top)
            
            Text("Transaction history will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }
}

struct BalanceReportView: View {
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Balance Report")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.top)
            
            Text("Customer balance reports will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }
}

struct CustomerAnalyticsView: View {
    var body: some View {
        VStack {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Customer Analytics")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.top)
            
            Text("Customer analytics and insights will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }
}

#Preview {
    ContentView()
}
