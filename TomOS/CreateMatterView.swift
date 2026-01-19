//
//  CreateMatterView.swift
//  TomOS
//
//  Form to create a new legal matter
//

import SwiftUI

struct CreateMatterView: View {
    @Environment(\.dismiss) private var dismiss

    let onMatterCreated: (Matter) -> Void

    @State private var title: String = ""
    @State private var client: String = ""
    @State private var selectedType: MatterType = .contract
    @State private var description: String = ""
    @State private var selectedPriority: MatterPriority = .medium
    @State private var leadCounsel: String = ""
    @State private var practiceArea: String = ""
    @State private var jurisdiction: String = ""
    @State private var matterNumber: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !client.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    TextField("Client", text: $client)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    Picker("Type", selection: $selectedType) {
                        ForEach(MatterType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }

                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(MatterPriority.allCases) { priority in
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(priority.color)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                }

                Section("Details") {
                    TextField("Matter Number (Optional)", text: $matterNumber)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif

                    TextField("Lead Counsel (Optional)", text: $leadCounsel)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    TextField("Practice Area (Optional)", text: $practiceArea)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    TextField("Jurisdiction (Optional)", text: $jurisdiction)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Matter")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createMatter()
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .bold()
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Text("Creating matter...")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func createMatter() {
        guard isFormValid else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let newMatter = try await APIService.shared.createMatter(
                    title: title.trimmingCharacters(in: .whitespaces),
                    client: client.trimmingCharacters(in: .whitespaces),
                    type: selectedType.rawValue,
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                    priority: selectedPriority.rawValue,
                    leadCounsel: leadCounsel.isEmpty ? nil : leadCounsel.trimmingCharacters(in: .whitespaces),
                    practiceArea: practiceArea.isEmpty ? nil : practiceArea.trimmingCharacters(in: .whitespaces),
                    jurisdiction: jurisdiction.isEmpty ? nil : jurisdiction.trimmingCharacters(in: .whitespaces)
                )

                await MainActor.run {
                    onMatterCreated(newMatter)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSubmitting = false
                }
            }
        }
    }
}

// MARK: - Matter Type Enum

enum MatterType: String, CaseIterable, Identifiable {
    case contract = "contract"
    case dispute = "dispute"
    case compliance = "compliance"
    case advisory = "advisory"
    case employment = "employment"
    case ip = "ip"
    case regulatory = "regulatory"
    case corporate = "corporate"
    case realEstate = "real_estate"
    case tax = "tax"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .contract: return "Contract"
        case .dispute: return "Dispute"
        case .compliance: return "Compliance"
        case .advisory: return "Advisory"
        case .employment: return "Employment"
        case .ip: return "Intellectual Property"
        case .regulatory: return "Regulatory"
        case .corporate: return "Corporate"
        case .realEstate: return "Real Estate"
        case .tax: return "Tax"
        }
    }

    var icon: String {
        switch self {
        case .contract: return "doc.text"
        case .dispute: return "hammer"
        case .compliance: return "checkmark.shield"
        case .advisory: return "lightbulb"
        case .employment: return "person.2"
        case .ip: return "lightbulb.max"
        case .regulatory: return "building.columns"
        case .corporate: return "building.2"
        case .realEstate: return "house"
        case .tax: return "dollarsign.circle"
        }
    }
}

// MARK: - Matter Priority Enum

enum MatterPriority: String, CaseIterable, Identifiable {
    case urgent = "urgent"
    case high = "high"
    case medium = "medium"
    case low = "low"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

#Preview {
    CreateMatterView { matter in
        print("Created: \(matter.title)")
    }
}
