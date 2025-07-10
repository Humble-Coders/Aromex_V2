import SwiftUI

struct AddCustomerDialog: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var firebaseManager: FirebaseManager
    
    @State private var customerName: String = ""
    @State private var customerPhone: String = ""
    @State private var customerEmail: String = ""
    @State private var customerAddress: String = ""
    @State private var customerNotes: String = ""
    @State private var isLoading: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Customer Information")
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customer Name *")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter customer name", text: $customerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone Number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter phone number", text: $customerPhone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                #if os(iOS)
                                .keyboardType(.phonePad)
                                #endif
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email Address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter email address", text: $customerEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                #endif
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter address", text: $customerAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter any notes", text: $customerNotes, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add New Customer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCustomer()
                    }
                    .disabled(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCustomer()
                    }
                    .disabled(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            #endif
        }
        .alert("Customer", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .disabled(isLoading)
        .overlay(
            Group {
                if isLoading {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        )
    }
    
    private func saveCustomer() {
        guard !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Customer name is required"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let newCustomer = Customer(
            name: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: customerPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: customerEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            address: customerAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: customerNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            balance: 0.0
        )
        
        Task {
            do {
                try await firebaseManager.addCustomer(newCustomer)
                
                await MainActor.run {
                    isLoading = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to save customer: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    AddCustomerDialog()
        .environmentObject(FirebaseManager.shared)
}
