import SwiftUI
import UIKit

private struct FloatingInputEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let placeholder: String
    let currentValue: String?
    let keyboardType: UIKeyboardType
    let confirmEnabled: (String) -> Bool
    let onConfirm: (String) -> Void

    @Binding var draft: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("cancel".localized) { dismiss() }
                    .accessibilityIdentifier("floating_input_cancel")
                Spacer()
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("confirm".localized) {
                    onConfirm(draft)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!confirmEnabled(draft))
                .accessibilityIdentifier("floating_input_confirm")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if let currentValue, !currentValue.isEmpty {
                HStack {
                    Text("current_value".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: $draft)
                    .keyboardType(keyboardType)
                    .font(.system(size: 20, weight: .semibold))
                    .focused($focused)
                    .accessibilityIdentifier("floating_input_textfield")
                if !draft.isEmpty {
                    Button {
                        draft = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("floating_input_clear")
                }
            }
            .padding(12)
            .background(DS.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .onAppear {
                draft = ""
                DispatchQueue.main.async {
                    focused = true
                }
            }
        }
        .padding(.bottom, 8)
        .presentationDetents([.height(220)])
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done".localized) {
                    focused = false
                }
            }
        }
    }
}

struct FloatingTextInputField: View {
    let placeholder: String
    let title: String
    @Binding var value: String
    var width: CGFloat? = nil
    var keyboardType: UIKeyboardType = .default
    var allowEmpty: Bool = true
    var normalize: (String) -> String = { $0 }
    var accessibilityIdentifier: String? = nil

    @State private var showEditor = false
    @State private var draft = ""

    private var fieldWidth: CGFloat? { width }

    var body: some View {
        Button {
            draft = ""
            showEditor = true
        } label: {
            Text(value.isEmpty ? placeholder : value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(value.isEmpty ? .secondary : .primary)
                .padding(.horizontal, 2)
                .frame(width: fieldWidth, alignment: .leading)
                .frame(maxWidth: fieldWidth == nil ? .infinity : nil, alignment: .leading)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "floating_text_input_field")
        .sheet(isPresented: $showEditor) {
            FloatingInputEditorSheet(
                title: title,
                placeholder: placeholder,
                currentValue: value,
                keyboardType: keyboardType,
                confirmEnabled: { input in
                    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    return allowEmpty ? true : !trimmed.isEmpty
                },
                onConfirm: { input in
                    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !allowEmpty && trimmed.isEmpty { return }
                    value = normalize(trimmed)
                },
                draft: $draft
            )
        }
    }
}

struct FloatingIntInputField: View {
    let placeholder: String
    let title: String
    @Binding var value: Int
    var width: CGFloat? = nil
    var minValue: Int? = nil
    var maxValue: Int? = nil
    var accessibilityIdentifier: String? = nil

    @State private var showEditor = false
    @State private var draft = ""

    var body: some View {
        Button {
            draft = ""
            showEditor = true
        } label: {
            Text("\(value)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 2)
                .frame(width: width, alignment: .trailing)
                .frame(minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "floating_int_input_field")
        .sheet(isPresented: $showEditor) {
            FloatingInputEditorSheet(
                title: title,
                placeholder: placeholder,
                currentValue: "\(value)",
                keyboardType: .numberPad,
                confirmEnabled: { input in
                    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !trimmed.isEmpty
                },
                onConfirm: { input in
                    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let parsed = Int(trimmed) else { return }
                    var normalized = parsed
                    if let minValue { normalized = max(minValue, normalized) }
                    if let maxValue { normalized = min(maxValue, normalized) }
                    value = normalized
                },
                draft: $draft
            )
        }
    }
}

struct FloatingDoubleInputField: View {
    let placeholder: String
    let title: String
    @Binding var value: Double
    var width: CGFloat? = nil
    var minValue: Double? = nil
    var maxValue: Double? = nil
    var precision: ClosedRange<Int> = 0...2
    var accessibilityIdentifier: String? = nil

    @State private var showEditor = false
    @State private var draft = ""

    private var displayText: String {
        let maxFraction = max(0, precision.upperBound)
        return String(format: "%.\(maxFraction)f", value)
    }

    var body: some View {
        Button {
            draft = ""
            showEditor = true
        } label: {
            Text(displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 2)
                .frame(width: width, alignment: .trailing)
                .frame(minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "floating_double_input_field")
        .sheet(isPresented: $showEditor) {
            FloatingInputEditorSheet(
                title: title,
                placeholder: placeholder,
                currentValue: displayText,
                keyboardType: .decimalPad,
                confirmEnabled: { input in
                    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !trimmed.isEmpty
                },
                onConfirm: { input in
                    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                    guard let parsed = Double(trimmed) else { return }
                    var normalized = parsed
                    if let minValue { normalized = max(minValue, normalized) }
                    if let maxValue { normalized = min(maxValue, normalized) }
                    value = normalized
                },
                draft: $draft
            )
        }
    }
}
