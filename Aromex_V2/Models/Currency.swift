import Foundation
import FirebaseFirestore

struct Currency: Identifiable, Codable {
    var id: String?
    var name: String
    var symbol: String
    var exchangeRate: Double // Rate relative to CAD (1 CAD = exchangeRate of this currency)
    var createdAt: Timestamp?
    var updatedAt: Timestamp?
    
    init(name: String, symbol: String, exchangeRate: Double = 1.0) {
        self.id = UUID().uuidString
        self.name = name
        self.symbol = symbol
        self.exchangeRate = exchangeRate
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
    
    // Custom init for existing Firestore data
    init(id: String, name: String, symbol: String, exchangeRate: Double, createdAt: Timestamp? = nil, updatedAt: Timestamp? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.exchangeRate = exchangeRate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "symbol": symbol,
            "exchangeRate": exchangeRate,
            "createdAt": createdAt ?? Timestamp(),
            "updatedAt": Timestamp()
        ]
    }
}

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    private let db = Firestore.firestore()
    
    @Published var currencies: [Currency] = []
    @Published var selectedCurrency: Currency?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var currenciesListener: ListenerRegistration?
    
    // Default CAD currency that's always available
    private let defaultCAD = Currency(id: "default_cad_id", name: "CAD", symbol: "$", exchangeRate: 1.0)
    
    private init() {
        // Start with default CAD currency
        self.selectedCurrency = defaultCAD
        fetchCurrencies()
    }
    
    // Computed property to get all currencies including CAD
    var allCurrencies: [Currency] {
        var allCurrencies = [defaultCAD] // Always include CAD first
        
        // Add other currencies from Firestore, but exclude any CAD duplicates
        let otherCurrencies = currencies.filter { $0.name.uppercased() != "CAD" }
        allCurrencies.append(contentsOf: otherCurrencies)
        
        return allCurrencies
    }
    
    func fetchCurrencies() {
        print("🔍 Fetching currencies from Firestore...")
        isLoading = true
        errorMessage = ""
        
        // Remove existing listener
        currenciesListener?.remove()
        
        // Fetch from Currencies collection
        currenciesListener = db.collection("Currencies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                self?.handleCurrenciesUpdate(querySnapshot: querySnapshot, error: error)
            }
    }
    
    private func handleCurrenciesUpdate(querySnapshot: QuerySnapshot?, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Firestore Error for Currencies: \(error.localizedDescription)")
                self.errorMessage = "Failed to load currencies: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            guard let querySnapshot = querySnapshot else {
                print("⚠️ QuerySnapshot is nil for Currencies")
                self.isLoading = false
                return
            }
            
            let documents = querySnapshot.documents
            print("📄 Found \(documents.count) currencies in Firestore")
            
            var fetchedCurrencies: [Currency] = []
            
            for document in documents {
                let documentID = document.documentID
                let data = document.data()
                
                print("📋 Currency Document ID: \(documentID)")
                
                if let name = data["name"] as? String,
                   let symbol = data["symbol"] as? String,
                   !name.isEmpty, !symbol.isEmpty {
                    
                    // Handle exchange rate
                    var exchangeRate: Double = 1.0
                    if let rateDouble = data["exchangeRate"] as? Double {
                        exchangeRate = rateDouble
                    } else if let rateInt = data["exchangeRate"] as? Int {
                        exchangeRate = Double(rateInt)
                    } else if let rateString = data["exchangeRate"] as? String,
                             let rateParsed = Double(rateString) {
                        exchangeRate = rateParsed
                    }
                    
                    let currency = Currency(
                        id: documentID,
                        name: name,
                        symbol: symbol,
                        exchangeRate: exchangeRate,
                        createdAt: data["createdAt"] as? Timestamp,
                        updatedAt: data["updatedAt"] as? Timestamp
                    )
                    
                    fetchedCurrencies.append(currency)
                    print("💱 Found currency: '\(name)' (\(symbol)) - Rate: \(exchangeRate)")
                } else {
                    print("⚠️ Currency Document \(documentID) missing required fields")
                }
            }
            
            // Sort by creation date
            fetchedCurrencies.sort {
                guard let date1 = $0.createdAt, let date2 = $1.createdAt else { return false }
                return date1.dateValue() < date2.dateValue()
            }
            
            self.currencies = fetchedCurrencies
            
            // Set default selected currency to CAD if not already set
            if self.selectedCurrency == nil {
                self.selectedCurrency = self.defaultCAD
            }
            
            self.isLoading = false
            self.errorMessage = ""
            
            print("✅ Successfully loaded \(fetchedCurrencies.count) currencies")
            print("📊 Total available currencies including CAD: \(self.allCurrencies.count)")
        }
    }
    
    func addCurrency(_ currency: Currency) async throws {
        print("💾 Adding new currency: \(currency.name) (\(currency.symbol))")
        
        let docRef = db.collection("Currencies").document()
        var newCurrency = currency
        newCurrency.id = docRef.documentID
        
        try await docRef.setData(newCurrency.toDictionary())
        print("✅ Currency added successfully")
    }
    
    func addCurrencyToFirestore(currencyId: String, data: [String: Any], completion: @escaping (Bool) -> Void) {
        db.collection("Currencies").document(currencyId).setData(data) { error in
            completion(error == nil)
        }
    }
    
    deinit {
        currenciesListener?.remove()
    }
}
