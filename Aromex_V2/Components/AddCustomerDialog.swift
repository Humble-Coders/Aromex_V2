import SwiftUI
import FirebaseFirestore

struct AddCustomerDialog: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
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
        return 900
        #else
        if horizontalSizeClass == .compact {
            return UIScreen.main.bounds.width - 40
        } else {
            return min(700, UIScreen.main.bounds.width - 80)
        }
        #endif
    }
    
    private var dialogHeight: CGFloat {
        #if os(macOS)
        return 500
        #else
        if shouldUseVerticalLayout {
            return min(UIScreen.main.bounds.height - 100, 600)
        } else {
            return min(500, UIScreen.main.bounds.height - 100)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Add Customer")
                    .font(.system(size: shouldUseVerticalLayout ? 28 : 34, weight: .bold, design: .serif))
                    .foregroundColor(mainColor)
                    .padding(.top, shouldUseVerticalLayout ? 20 : 28)
                    .padding(.leading, horizontalPadding)
                    .padding(.bottom, 20)
                
                VStack(spacing: 24) {
                    if shouldUseVerticalLayout {
                        verticalFieldsLayout
                    } else {
                        horizontalFieldsLayout
                    }
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
                TextField("Enter customer name", text: $name)
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
                TextField("Enter customer phone", text: $phone)
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
                TextField("Enter customer email", text: $email)
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
                TextField("Enter customer address", text: $address)
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
                TextField("Enter customer notes", text: $notes)
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
                    TextField("Enter customer name", text: $name)
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
                    TextField("Enter customer phone", text: $phone)
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
                    TextField("Enter customer email", text: $email)
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
                TextField("Enter customer address", text: $address)
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
                TextField("Enter customer notes", text: $notes)
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
                // Add Customer Button
                Button(action: addCustomer) {
                    Text("Add Customer")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 45)
                        .background((name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding) ?
                                    Color.gray.opacity(0.22) : mainColor.opacity(0.97))
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
                        .background(mainColor.opacity(0.93))
                        .foregroundColor(.white)
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
                        .background(mainColor.opacity(0.93))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .opacity(isAdding ? 0.6 : 1)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAdding)
                
                // Add Customer Button
                Button(action: addCustomer) {
                    Text("Add Customer")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .frame(width: 180, height: 45)
                        .background((name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding) ?
                                    Color.gray.opacity(0.22) : mainColor.opacity(0.97))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func addCustomer() {
        nameError = ""
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Validate name
        guard !trimmedName.isEmpty else {
            nameError = "Name is required."
            return
        }
        
        // Check for duplicate
        if firebaseManager.customers.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            nameError = "A customer with this name already exists."
            return
        }
        
        isAdding = true
        
        // Prepare Firestore data
        let customerId = UUID().uuidString
        let now = Date()
        let timestamp = Timestamp(date: now)
        
        let customerData: [String: Any] = [
            "name": trimmedName,
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "email": email.trimmingCharacters(in: .whitespaces),
            "address": address.trimmingCharacters(in: .whitespaces),
            "notes": notes.trimmingCharacters(in: .whitespaces),
            "balance": 0.0,
            "createdAt": timestamp,
            "updatedAt": timestamp,
            "transactionHistory": []
        ]
        
        // Add to Firestore
        firebaseManager.addCustomerToFirestore(customerId: customerId, data: customerData) { success in
            isAdding = false
            if success {
                presentationMode.wrappedValue.dismiss()
            } else {
                nameError = "Failed to add customer. Try again."
            }
        }
    }
}
