import Foundation
import FirebaseFirestore
import Network
import Firebase

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let db = Firestore.firestore()
    private let monitor = NWPathMonitor()
    
    @Published var customers: [Customer] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isConnected = false
    
    private var customersListener: ListenerRegistration?
    private var middlemenListener: ListenerRegistration?
    private var suppliersListener: ListenerRegistration?
    
    private init() {
        configureFirestore()
        startNetworkMonitoring()
    }
    
    private func configureFirestore() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = false
        settings.isSSLEnabled = true
        settings.host = "firestore.googleapis.com"
        
        db.settings = settings
        
        if let app = FirebaseApp.app() {
            let projectID = app.options.projectID
            print("🔧 Connected to Firebase Project: \(projectID)")
            
            let bundleID = app.options.bundleID
            print("🔧 App Bundle ID: \(bundleID)")
        }
        
        testNetworkConnectivity()
        print("🔧 Configured Firestore for online-only mode")
    }
    
    private func testNetworkConnectivity() {
        print("🔍 Testing network connectivity...")
        
        let url = URL(string: "https://dns.google")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network test failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("✅ Network test successful: \(httpResponse.statusCode)")
                }
            }
        }
        task.resume()
        
        let firebaseURL = URL(string: "https://firestore.googleapis.com")!
        let firebaseTask = URLSession.shared.dataTask(with: firebaseURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Firebase endpoint test failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("✅ Firebase endpoint reachable: \(httpResponse.statusCode)")
                }
            }
        }
        firebaseTask.resume()
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                print("🌐 Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
                
                if path.status == .satisfied {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.fetchAllCustomers()
                    }
                } else {
                    self?.errorMessage = "No internet connection. Please check your network settings."
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    func fetchAllCustomers() {
        guard isConnected else {
            errorMessage = "No internet connection. Cannot fetch customers."
            print("❌ No internet connection available")
            return
        }
        
        print("🔍 Fetching all customers from multiple collections...")
        isLoading = true
        errorMessage = ""
        
        // Remove existing listeners
        customersListener?.remove()
        middlemenListener?.remove()
        suppliersListener?.remove()
        
        // Fetch from Customers collection
        customersListener = db.collection("Customers")
            .addSnapshotListener { [weak self] querySnapshot, error in
                self?.handleCollectionUpdate(querySnapshot: querySnapshot, error: error, type: .customer)
            }
        
        // Fetch from Middlemen collection
        middlemenListener = db.collection("Middlemen")
            .addSnapshotListener { [weak self] querySnapshot, error in
                self?.handleCollectionUpdate(querySnapshot: querySnapshot, error: error, type: .middleman)
            }
        
        // Fetch from Suppliers collection
        suppliersListener = db.collection("Suppliers")
            .addSnapshotListener { [weak self] querySnapshot, error in
                self?.handleCollectionUpdate(querySnapshot: querySnapshot, error: error, type: .supplier)
            }
    }
    
    private func handleCollectionUpdate(querySnapshot: QuerySnapshot?, error: Error?, type: CustomerType) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Firestore Error for \(type.rawValue): \(error.localizedDescription)")
                
                if error.localizedDescription.contains("network") ||
                   error.localizedDescription.contains("connection") ||
                   error.localizedDescription.contains("Unavailable") {
                    self.errorMessage = "Network connection error. Please check your internet connection and firewall settings."
                } else {
                    self.errorMessage = "Database error: \(error.localizedDescription)"
                }
                self.isLoading = false
                return
            }
            
            guard let querySnapshot = querySnapshot else {
                print("⚠️ QuerySnapshot is nil for \(type.rawValue)")
                self.isLoading = false
                return
            }
            
            let documents = querySnapshot.documents
            print("📄 Found \(documents.count) documents in '\(type.rawValue)' collection")
            
            var collectionCustomers: [Customer] = []
            
            for document in documents {
                let documentID = document.documentID
                let data = document.data()
                
                print("📋 \(type.rawValue) Document ID: \(documentID)")
                
                if let name = data["name"] as? String, !name.isEmpty {
                    print("👤 Found \(type.rawValue.lowercased()): '\(name)'")
                    
                    // For customers, read all fields. For middlemen/suppliers, only name and balance
                    let phone: String
                    let email: String
                    let address: String
                    let notes: String
                    
                    if type == .customer {
                        phone = data["phone"] as? String ?? ""
                        email = data["email"] as? String ?? ""
                        address = data["address"] as? String ?? ""
                        notes = data["notes"] as? String ?? ""
                    } else {
                        // Middlemen and Suppliers only need name and balance
                        phone = ""
                        email = ""
                        address = ""
                        notes = ""
                    }
                    
                    // Handle balance flexibly for all types
                    var balance: Double = 0.0
                    if let balanceDouble = data["balance"] as? Double {
                        balance = balanceDouble
                    } else if let balanceInt = data["balance"] as? Int {
                        balance = Double(balanceInt)
                    } else if let balanceString = data["balance"] as? String,
                             let balanceParsed = Double(balanceString) {
                        balance = balanceParsed
                    }
                    
                    print("💰 \(type.rawValue) '\(name)' balance: $\(balance)")
                    
                    let customer = Customer(
                        id: documentID,
                        name: name,
                        phone: phone,
                        email: email,
                        address: address,
                        notes: notes,
                        balance: balance,
                        type: type,
                        createdAt: type == .customer ? (data["createdAt"] as? Timestamp) : nil,
                        updatedAt: type == .customer ? (data["updatedAt"] as? Timestamp) : nil
                    )
                    
                    collectionCustomers.append(customer)
                } else {
                    print("⚠️ \(type.rawValue) Document \(documentID) missing or empty 'name' field")
                }
            }
            
            // Update the combined list
            self.updateCombinedCustomersList(newCustomers: collectionCustomers, type: type)
        }
    }
    
    private func updateCombinedCustomersList(newCustomers: [Customer], type: CustomerType) {
        // Remove existing customers of this type
        customers.removeAll { $0.type == type }
        
        // Add new customers of this type
        customers.append(contentsOf: newCustomers)
        
        // Sort by name
        customers.sort { $0.name.lowercased() < $1.name.lowercased() }
        
        isLoading = false
        errorMessage = ""
        
        let typeCount = customers.filter { $0.type == type }.count
        print("✅ Successfully loaded \(typeCount) \(type.rawValue.lowercased())s")
        print("📊 Total combined: \(customers.count) entries (\(customers.filter{$0.type == .customer}.count) customers, \(customers.filter{$0.type == .middleman}.count) middlemen, \(customers.filter{$0.type == .supplier}.count) suppliers)")
        
        // Show only names and balances for cleaner logging
        for customer in customers.filter({ $0.type == type }) {
            print("  - [\(customer.type.shortTag)] \(customer.name) → $\(customer.balance)")
        }
    }
    
    func addCustomer(_ customer: Customer) async throws {
        guard isConnected else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No internet connection"])
        }
        
        print("💾 Adding new \(customer.type.rawValue.lowercased()): \(customer.name)")
        
        let collectionName = "\(customer.type.rawValue)s"
        let docRef = db.collection(collectionName).document()
        var newCustomer = customer
        newCustomer.id = docRef.documentID
        
        try await docRef.setData(newCustomer.toDictionary())
        print("✅ \(customer.type.rawValue) added successfully")
    }
    
    func retryConnection() {
        print("🔄 Retrying connection...")
        fetchAllCustomers()
    }
    
    deinit {
        customersListener?.remove()
        middlemenListener?.remove()
        suppliersListener?.remove()
    }
}
