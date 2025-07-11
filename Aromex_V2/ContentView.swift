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
    @State private var selectedTab = 0
    
    // Determine if we should use sidebar navigation (iPad landscape and macOS)
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
                    
                    MainContentWithTabs()
                        .frame(minWidth: 600)
                }
                .navigationTitle("AROMEX")
            } else {
                // iPhone and iPad portrait - use tab view
                TabView {
                    NavigationView {
                        MainContentWithTabs()
                            .navigationTitle("AROMEX")
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.large)
                            #endif
                    }
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
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

struct MainContentWithTabs: View {
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                switch selectedTab {
                case 0:
                    AddEntryView()
                case 1:
                    BalanceReportView()
                default:
                    AddEntryView()
                }
            }
            
            // Tab bar at the bottom
            TabBarView(selectedTab: $selectedTab)
        }
        .background(Color.systemGroupedBackground)
    }
}

struct TabBarView: View {
    @Binding var selectedTab: Int
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
            // All Entries Tab
            TabBarButton(
                icon: "doc.text.fill",
                title: "All Entries",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            // Balance Report Tab
            TabBarButton(
                icon: "chart.bar.fill",
                title: "Balance Report",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.23, green: 0.28, blue: 0.42),
                    Color(red: 0.3, green: 0.4, blue: 0.6)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .frame(height: shouldUseVerticalLayout ? 60 : 70)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var shouldUseVerticalLayout: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: shouldUseVerticalLayout ? 8 : 12) {
                Image(systemName: icon)
                    .font(.system(size: shouldUseVerticalLayout ? 16 : 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Text(title)
                    .font(.system(size: shouldUseVerticalLayout ? 14 : 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: shouldUseVerticalLayout ? 40 : 50)
            .background(
                isSelected ?
                Color.white.opacity(0.2) :
                Color.clear
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, shouldUseVerticalLayout ? 8 : 10)
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink(destination: MainContentWithTabs()) {
                Label("Home", systemImage: "house.fill")
            }
            
            NavigationLink(destination: CustomerListView()) {
                Label("Customers", systemImage: "person.3.fill")
            }
            
            NavigationLink(destination: TransactionHistoryView()) {
                Label("Transaction History", systemImage: "clock.fill")
            }
            
            Section("Analytics") {
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

// Keep the existing placeholder views
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
                
                Text("\(customer.balance, specifier: "%.2f") CAD")
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
