#if canImport(UIKit)
import SwiftUI

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.dismissKeyboard()
                }
            }
        }
    }
}

extension View {
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbar())
    }

    /// Dismisses the keyboard when the user taps empty space.
    /// Uses `simultaneousGesture` so buttons, links, and other controls still work.
    func dismissKeyboardOnTap() -> some View {
        self
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.dismissKeyboard()
                }
            )
    }
}
#else
import SwiftUI

extension View {
    func keyboardDoneToolbar() -> some View { self }
    func dismissKeyboardOnTap() -> some View { self }
}
#endif
