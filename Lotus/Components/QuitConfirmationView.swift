//
//  QuitConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct QuitConfirmationView: View {
    @ObservedObject var browserState: BrowserState

    var body: some View {
        LotusConfirmationDialog(
            iconStyle: .custom(
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.95, blue: 1.0),
                        Color(red: 0.55, green: 0.78, blue: 0.95),
                        Color(red: 0.95, green: 0.70, blue: 0.55),
                        Color(red: 0.98, green: 0.85, blue: 0.40)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                systemImage: "camera.macro"
            ),
            title: "Are you sure you want to quit Lotus?",
            subtitle: "You may lose unsaved work in your tabs.",
            onCancel: { browserState.cancelQuit() }
        ) {
            EmptyView()
        } secondaryActions: {
            LotusDialogSecondaryButton(title: "Always quit") {
                browserState.confirmQuit(alwaysQuit: true)
            }
        } actions: {
            LotusDialogCancelButton {
                browserState.cancelQuit()
            }

            LotusDialogActionButton(title: "Quit", isDestructive: true) {
                browserState.confirmQuit(alwaysQuit: false)
            }
        }
        .background {
            Button("") {
                browserState.confirmQuit(alwaysQuit: false)
            }
            .keyboardShortcut("q", modifiers: .command)
            .opacity(0)
            .focusable(false)
        }
    }
}
