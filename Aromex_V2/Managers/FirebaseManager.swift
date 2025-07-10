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
    
    private init() {
        // Configure Firestore for online-only mode
        configureFirestore()
        startNetworkMonitoring()
    }
    
    private func configureFirestore() {
        // Disable offline persistence - forces online-only mode
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = false
        settings.isSSLEnabled = true
        
        // Try to resolve connectivity issues
        settings.host = "firestore.googleapis.com"
        
        db.settings = settings
        
        // Debug: Print Firebase project info
        if let app = FirebaseApp.app() {
            let projectID = app.options.projectID
            print("🔧 Connected to Firebase Project: \(projectID)")
            
            let bundleID = app.options.bundleID
            print("🔧 App Bundle ID: \(bundleID)")
        }
        
        // Test network connectivity to Google
        testNetworkConnectivity()
        
        print("🔧 Configured Firestore for online-only mode")
    }
    
    private func testNetworkConnectivity() {
        print("🔍 Testing network connectivity...")
        
        // Test if we can reach Google DNS
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
        
        // Test specific Firebase endpoint
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
                    // Wait a moment for connection to stabilize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.fetchCustomers()
                    }
                } else {
                    self?.errorMessage = "No internet connection. Please check your network settings."
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    func fetchCustomers() {
        guard isConnected else {
            errorMessage = "No internet connection. Cannot fetch customers."
            print("❌ No internet connection available")
            return
        }
        
        print("🔍 Fetching customers from Firestore (online-only mode)...")
        isLoading = true
        errorMessage = ""
        
        // Use real-time listener for immediate updates
        db.collection("Customers")
            .addSnapshotListener { [weak self] querySnapshot, error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ Firestore Error: \(error.localizedDescription)")
                        
                        // Check for specific connectivity errors
                        if error.localizedDescription.contains("network") ||
                           error.localizedDescription.contains("connection") ||
                           error.localizedDescription.contains("Unavailable") {
                            self?.errorMessage = "Network connection error. Please check your internet connection and firewall settings."
                        } else {
                            self?.errorMessage = "Database error: \(error.localizedDescription)"
                        }
                        return
                    }
                    
                    guard let querySnapshot = querySnapshot else {
                        print("⚠️ QuerySnapshot is nil")
                        self?.errorMessage = "No data received from database"
                        return
                    }
                    
                    let documents = querySnapshot.documents
                    print("📄 Found \(documents.count) documents in 'Customers' collection")
                    
                    // Let's also try checking other possible collection names
                    if documents.isEmpty {
                        print("⚠️ No documents in 'Customers' collection")
                        print("🔍 Let's check if collection name is different...")
                        self?.checkOtherCollectionNames()
                    }
                    
                    if documents.isEmpty {
                        print("⚠️ No customers found in the collection")
                        self?.errorMessage = "No customers found in database"
                        self?.customers = []
                        return
                    }
                    
                    var loadedCustomers: [Customer] = []
                    
                    for document in documents {
                        let documentID = document.documentID
                        let data = document.data()
                        
                        print("📋 Document ID: \(documentID)")
                        print("📋 Document Fields: \(Array(data.keys))")
                        
                        // Check if name field exists and is not empty
                        if let name = data["name"] as? String, !name.isEmpty {
                            print("👤 Found customer: '\(name)'")
                            
                            // Extract all fields with fallbacks
                            let phone = data["phone"] as? String ?? ""
                            let email = data["email"] as? String ?? ""
                            let address = data["address"] as? String ?? ""
                            let notes = data["notes"] as? String ?? ""
                            
                            // Handle balance flexibly
                            var balance: Double = 0.0
                            if let balanceDouble = data["balance"] as? Double {
                                balance = balanceDouble
                            } else if let balanceInt = data["balance"] as? Int {
                                balance = Double(balanceInt)
                            } else if let balanceString = data["balance"] as? String,
                                     let balanceParsed = Double(balanceString) {
                                balance = balanceParsed
                            }
                            
                            let customer = Customer(
                                id: documentID,
                                name: name,
                                phone: phone,
                                email: email,
                                address: address,
                                notes: notes,
                                balance: balance,
                                createdAt: data["createdAt"] as? Timestamp,
                                updatedAt: data["updatedAt"] as? Timestamp
                            )
                            
                            loadedCustomers.append(customer)
                        } else {
                            print("⚠️ Document \(documentID) missing or empty 'name' field")
                        }
                    }
                    
                    // Sort by name
                    loadedCustomers.sort { $0.name.lowercased() < $1.name.lowercased() }
                    
                    self?.customers = loadedCustomers
                    self?.errorMessage = ""
                    
                    print("✅ Successfully loaded \(loadedCustomers.count) customers:")
                    for customer in loadedCustomers {
                        print("  - \(customer.name) (Balance: $\(customer.balance))")
                    }
                }
            }
    }
    
    func addCustomer(_ customer: Customer) async throws {
        guard isConnected else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No internet connection"])
        }
        
        print("💾 Adding new customer: \(customer.name)")
        let docRef = db.collection("Customers").document()
        var newCustomer = customer
        newCustomer.id = docRef.documentID
        
        try await docRef.setData(newCustomer.toDictionary())
        print("✅ Customer added successfully")
    }
    
    func retryConnection() {
        print("🔄 Retrying connection...")
        fetchCustomers()
    }
    
    private func checkOtherCollectionNames() {
        // Check if the collection might have a different name
        let possibleNames = ["customers", "Customers", "CUSTOMERS", "customer", "Customer"]
        
        for collectionName in possibleNames {
            db.collection(collectionName).getDocuments { querySnapshot, error in
                if let documents = querySnapshot?.documents, !documents.isEmpty {
                    print("🔍 Found \(documents.count) documents in '\(collectionName)' collection!")
                    print("🔍 Document IDs: \(documents.map { $0.documentID })")
                    
                    // Show first document data to verify structure
                    if let firstDoc = documents.first {
                        print("🔍 First document data: \(firstDoc.data())")
                    }
                }
            }
        }
    }
}
