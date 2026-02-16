//  4
//  Toast.swift
//  KaxhyapUI
//
//  Created by Sachin Kaxhyap on 16/02/2026.
//

import SwiftUI

// MARK: - Toast Style

/// Defines the visual style of the toast.
///
/// - `clear`: A translucent glass/material background.
/// - `prominent(Color)`: A colored background with white foreground text.
public enum ToastStyle {
    /// A clear glass/material style.
    case clear
    /// A prominent style with a specified background color.
    case prominent(Color)
}

// MARK: - Toast Modifier

@available(iOS 17.0, macOS 14.0, *)
private struct ToastModifier: ViewModifier {
    let message: String
    @Binding var isPresented: Bool
    let systemImage: String?
    let assetImage: String?
    let style: ToastStyle
    let duration: TimeInterval
    let actionTitle: String?
    let onAction: (() -> Void)?
    
    @State private var dismissTask: Task<Void, Never>?
    @State private var presentedAt: Double = 0
    
    private var hasAction: Bool {
        actionTitle != nil
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    toastView
                        .padding(.bottom, 16)
                        .zIndex(presentedAt)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            presentedAt = Date.now.timeIntervalSinceReferenceDate
                            scheduleDismiss()
                        }
                        .onDisappear {
                            dismissTask?.cancel()
                        }
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: isPresented)
    }
    
    // MARK: Toast View Router
    
    @ViewBuilder
    private var toastView: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            switch style {
            case .clear:
                glassToastClear
            case .prominent(let color):
                glassToastProminent(color: color)
            }
        } else {
            switch style {
            case .clear:
                fallbackToastClear
            case .prominent(let color):
                fallbackToastProminent(color: color)
            }
        }
    }
    
    // MARK: iOS 26+ Glass Toasts
    
    @available(iOS 26.0, macOS 26.0, *)
    private var glassToastClear: some View {
        HStack {
            imageView
            
            Text(message)
            
            if let actionTitle {
                Button(actionTitle) {
                    dismissAfterAction()
                }
                .font(.footnote)
                .buttonStyle(.glass)
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, hasAction ? 4 : 8)
        .padding(.leading)
        .padding(.trailing, hasAction ? 0 : 16)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Capsule()
                .glassEffect(.clear.interactive())
        }
    }
    
    @available(iOS 26.0, macOS 26.0, *)
    private func glassToastProminent(color: Color) -> some View {
        HStack {
            imageView
            
            Text(message)
            
            if let actionTitle {
                Button(actionTitle) {
                    dismissAfterAction()
                }
                .font(.footnote)
                .padding(7)
                .padding(.horizontal, 4)
                .glassEffect(.clear.interactive())
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, hasAction ? 4 : 8)
        .padding(.leading)
        .padding(.trailing, hasAction ? 0 : 16)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Capsule()
                .foregroundStyle(color)
                .glassEffect(.clear.interactive())
        }
        .foregroundStyle(.white)
    }
    
    // MARK: Fallback Toasts (pre-iOS 26)
    
    private var fallbackToastClear: some View {
        HStack {
            imageView
            
            Text(message)
            
            if let actionTitle {
                Button(actionTitle) {
                    dismissAfterAction()
                }
                .font(.footnote)
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, hasAction ? 4 : 8)
        .padding(.leading)
        .padding(.trailing, hasAction ? 0 : 16)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }
    
    private func fallbackToastProminent(color: Color) -> some View {
        HStack {
            imageView
            
            Text(message)
            
            if let actionTitle {
                Button(actionTitle) {
                    dismissAfterAction()
                }
                .font(.footnote)
                .padding(7)
                .padding(.horizontal, 4)
                .background {
                    Capsule()
                        .foregroundStyle(.ultraThinMaterial)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, hasAction ? 4 : 8)
        .padding(.leading)
        .padding(.trailing, hasAction ? 0 : 16)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Capsule()
                .foregroundStyle(color)
        }
        .foregroundStyle(.white)
    }
    
    // MARK: Image
    
    @ViewBuilder
    private var imageView: some View {
        if let systemImage {
            Image(systemName: systemImage)
        } else if let assetImage {
            Image(assetImage)
        }
    }
    
    // MARK: Dismiss
    
    private func dismissAfterAction() {
        onAction?()
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
    
    // MARK: Auto-Dismiss
    
    private func scheduleDismiss() {
        dismissTask?.cancel()
        let duration = self.duration
        guard duration > 0 else { return }
        let binding = $isPresented
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                await MainActor.run {
                    binding.wrappedValue = false
                }
            }
        }
    }
}

// MARK: - View Extension

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    
    /// Presents a toast notification from the bottom of the view.
    ///
    /// The toast automatically adapts to the platform — using glass effects on iOS 26+
    /// and material backgrounds on earlier versions.
    ///
    /// ```swift
    /// .toast(
    ///     message: "Saved successfully",
    ///     isPresented: $showToast,
    ///     systemImage: "checkmark.circle",
    ///     style: .prominent(.blue),
    ///     duration: 2.0,
    ///     actionTitle: "Undo"
    /// ) {
    ///     viewModel.undo()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - message: The text to display in the toast.
    ///   - isPresented: A binding that controls the visibility of the toast.
    ///   - systemImage: An optional SF Symbol name to display alongside the message.
    ///   - style: The visual style of the toast (`.clear` or `.prominent(Color)`).
    ///   - duration: How long the toast is displayed before auto-dismissing (in seconds). Set to `0` to disable auto-dismiss.
    ///   - actionTitle: An optional title for an action button displayed in the toast.
    ///   - action: An optional closure to execute when the action button is tapped.
    func toast(
        message: String,
        isPresented: Binding<Bool>,
        systemImage: String? = nil,
        style: ToastStyle = .clear,
        duration: TimeInterval = 2.0,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        modifier(
            ToastModifier(
                message: message,
                isPresented: isPresented,
                systemImage: systemImage,
                assetImage: nil,
                style: style,
                duration: duration,
                actionTitle: actionTitle,
                onAction: action
            )
        )
    }
    
    /// Presents a toast notification from the bottom of the view with a custom asset image.
    ///
    /// - Parameters:
    ///   - message: The text to display in the toast.
    ///   - isPresented: A binding that controls the visibility of the toast.
    ///   - image: The name of a custom image asset to display alongside the message.
    ///   - style: The visual style of the toast (`.clear` or `.prominent(Color)`).
    ///   - duration: How long the toast is displayed before auto-dismissing (in seconds). Set to `0` to disable auto-dismiss.
    ///   - actionTitle: An optional title for an action button displayed in the toast.
    ///   - action: An optional closure to execute when the action button is tapped.
    func toast(
        message: String,
        isPresented: Binding<Bool>,
        image: String,
        style: ToastStyle = .clear,
        duration: TimeInterval = 2.0,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        modifier(
            ToastModifier(
                message: message,
                isPresented: isPresented,
                systemImage: nil,
                assetImage: image,
                style: style,
                duration: duration,
                actionTitle: actionTitle,
                onAction: action
            )
        )
    }
}

// MARK: - Preview

@available(iOS 17.0, macOS 14.0, *)
#Preview("Toast Showcase") {
    struct ToastPreview: View {
        @State private var showClear = false
        @State private var showClearAction = false
        @State private var showProminent = false
        @State private var showProminentAction = false
        
        var body: some View {
            VStack(spacing: 16) {
                Spacer()
                
                Button("Clear") {
                    showClear = true
                }
                .buttonStyle(.bordered)
                
                Button("Clear + Action") {
                    showClearAction = true
                }
                .buttonStyle(.bordered)
                
                Button("Prominent") {
                    showProminent = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Prominent + Action") {
                    showProminentAction = true
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .toast(
                message: "Copied to clipboard",
                isPresented: $showClear,
                systemImage: "checkmark.circle",
                style: .clear,
                duration: 3.0
            )
            .toast(
                message: "Copied to clipboard",
                isPresented: $showClearAction,
                systemImage: "checkmark.circle",
                style: .clear,
                duration: 3.0,
                actionTitle: "Undo"
            ) {
                showClearAction = false
            }
            .toast(
                message: "Saved successfully",
                isPresented: $showProminent,
                systemImage: "checkmark.circle",
                style: .prominent(.blue),
                duration: 3.0
            )
            .toast(
                message: "Saved successfully",
                isPresented: $showProminentAction,
                systemImage: "arrow.uturn.backward",
                style: .prominent(.blue),
                duration: 3.0,
                actionTitle: "Undo"
            ) {
                showProminentAction = false
            }
        }
    }
    
    return ToastPreview()
}
