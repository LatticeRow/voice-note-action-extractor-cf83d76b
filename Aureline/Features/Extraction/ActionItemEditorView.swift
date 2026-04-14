import SwiftUI

struct ActionItemEditorView: View {
    @Bindable var item: ExtractedActionItem
    let index: Int

    @State private var showsDatePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Keep", isOn: $item.isSelectedForExport)
                .tint(AurelinePalette.accent)
                .foregroundStyle(Color.white)
                .accessibilityIdentifier("extraction.item.\(index).toggle")

            VStack(alignment: .leading, spacing: 8) {
                Text("Task")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AurelinePalette.secondaryText)

                TextField("Task", text: $item.normalizedText)
                    .textInputAutocapitalization(.sentences)
                    .foregroundStyle(Color.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AurelinePalette.cardRaised)
                    )
                    .accessibilityIdentifier("extraction.item.\(index).title")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Contact")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AurelinePalette.secondaryText)

                TextField("Optional", text: contactBinding)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(Color.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AurelinePalette.cardRaised)
                    )
                    .accessibilityIdentifier("extraction.item.\(index).contact")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Due")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AurelinePalette.secondaryText)

                if let dueDate = item.dueDate {
                    AurelineBadge(title: Self.dateFormatter.string(from: dueDate), tint: AurelinePalette.positive)
                }

                HStack(spacing: 10) {
                    Button(item.dueDate == nil ? "Add Date" : (showsDatePicker ? "Done" : "Adjust Date")) {
                        if item.dueDate == nil {
                            item.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
                        }
                        showsDatePicker.toggle()
                    }
                    .buttonStyle(AurelineSecondaryButtonStyle())
                    .accessibilityIdentifier("extraction.item.\(index).dateToggle")

                    if item.dueDate != nil {
                        Button("Clear Date") {
                            item.dueDate = nil
                            showsDatePicker = false
                        }
                        .buttonStyle(AurelineSecondaryButtonStyle())
                        .accessibilityIdentifier("extraction.item.\(index).clearDate")
                    }
                }

                if showsDatePicker, item.dueDate != nil {
                    DatePicker(
                        "Due",
                        selection: dueDateBinding,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(AurelinePalette.accent)
                    .accessibilityIdentifier("extraction.item.\(index).datePicker")
                }
            }

            HStack(spacing: 8) {
                if let method = item.contactMethod, !method.isEmpty {
                    AurelineBadge(title: method, tint: AurelinePalette.accent)
                }

                AurelineBadge(
                    title: "Confidence \(Int(item.confidence * 100))%",
                    tint: item.confidence >= 0.75 ? AurelinePalette.positive : AurelinePalette.caution
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AurelinePalette.cardRaised)
        )
    }

    private var contactBinding: Binding<String> {
        Binding(
            get: { item.contactName ?? "" },
            set: { item.contactName = $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { item.dueDate ?? .now },
            set: { item.dueDate = $0 }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
