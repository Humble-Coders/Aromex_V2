import SwiftUI

struct ContentView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationView {
            // Sidebar
            SidebarView()
                .frame(minWidth: 200, maxWidth: 250)
            
            // Main Content
            MainContentView()
                .frame(minWidth: 800)
        }
        .navigationTitle("AROMEX")
        .environmentObject(firebaseManager)
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink(destination: AddEntryView()) {
                Label("Add Entry", systemImage: "plus.circle.fill")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("AROMEX")
    }
}

struct MainContentView: View {
    var body: some View {
        AddEntryView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
