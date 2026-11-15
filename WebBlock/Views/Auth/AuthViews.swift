import SwiftUI

/// The only way in: sign in with the account you created on the WebBlock website.
struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var model = AuthViewModel()

    var body: some View {
        ZStack {
            AuthBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    HStack(spacing: Space.xs) {
                        BrandMark(size: 36)
                        Text("WebBlock").font(.title3.bold()).foregroundStyle(.wbText)
                    }

                    (Text("Pick up right\nwhere you ").foregroundStyle(Color.wbText)
                     + Text("left off.").foregroundStyle(Color.wbBrand))
                        .font(.system(size: 34, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    card
                }
                .padding(.horizontal, Space.screen)
                .padding(.vertical, Space.l)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $model.showGoogleChooser) {
            GoogleChooserSheet(model: model).presentationDetents([.medium])
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back").font(.title2.bold()).foregroundStyle(.wbText)
                Text("Sign in to manage your websites.").font(.subheadline).foregroundStyle(.wbMuted)
            }

            Button { model.showGoogleChooser = true } label: {
                Label("Continue with Google", systemImage: "g.circle.fill")
            }
            .buttonStyle(.wbSecondary)

            HStack(spacing: Space.s) {
                Rectangle().fill(.wbBorder).frame(height: 1)
                Text("or").font(.footnote).foregroundStyle(.wbMuted)
                Rectangle().fill(.wbBorder).frame(height: 1)
            }

            LabeledField(title: "Email", text: $model.email, prompt: "you@example.com",
                         error: model.emailError, keyboard: .emailAddress,
                         contentType: .emailAddress, capitalization: .never)
            LabeledField(title: "Password", text: $model.password, prompt: "Your password",
                         isSecure: true, revealable: true, contentType: .password)

            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.wbRed)
                    .padding(Space.s).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.wbRedSoft, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }

            LoadingButton(title: "Sign in", isLoading: model.isLoading) {
                Task { await model.signIn(appState: appState) }
            }
            .disabled(!model.canSignIn)

            Text("Use the account you created on the WebBlock website.")
                .font(.footnote).foregroundStyle(.wbMuted)
                .frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
        }
        .padding(Space.l)
        .background(.wbCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.wbBorder, lineWidth: 1))
        .shadow(color: Color(hex: 0x4379D6).opacity(0.12), radius: 24, y: 10)
    }
}

// MARK: - Google account chooser

struct GoogleChooserSheet: View {
    @Bindable var model: AuthViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("to continue to WebBlock").font(.subheadline).foregroundStyle(.wbMuted)
                Button {
                    Task { await model.signInWithGoogle(appState: appState) }
                } label: {
                    HStack(spacing: Space.s) {
                        AvatarView(initials: "SS", size: 40)
                        VStack(alignment: .leading) {
                            Text("Sovannarith Soeun").font(.body.weight(.semibold)).foregroundStyle(.wbText)
                            Text("sovannarith@gmail.com").font(.footnote).foregroundStyle(.wbMuted)   // SAMPLE account
                        }
                        Spacer()
                        if model.isLoading { ProgressView() }
                    }
                    .wbCard()
                }
                .buttonStyle(.plain)
                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.wbRed)
                }
                Spacer()
            }
            .padding(Space.screen)
            .background(.wbBackground)
            .navigationTitle("Choose an account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
