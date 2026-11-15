import SwiftUI
import Observation

/// The only way in: sign in with the account you created on the WebBlock website.
struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var model = AuthViewModel()

    var body: some View {
        ZStack {
            AuthBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Image("webblocks-logo").resizable().scaledToFit().frame(height: 56)
                        .accessibilityLabel("WebBlocks")

                    (Text("Pick up right\nwhere you ").foregroundStyle(Color.wbText)
                     + Text("left off.").foregroundStyle(Color.wbBrand))
                        .font(.system(size: 28, weight: .bold))
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
        .fullScreenCover(isPresented: $model.showForgotPassword) {
            ForgotPasswordFlow(initialEmail: model.email) { changedEmail in
                if let changedEmail { model.email = changedEmail; model.password = "" }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back").font(.title2.bold()).foregroundStyle(.wbText)
                Text("Sign in to manage your websites.").font(.subheadline).foregroundStyle(.wbMuted)
            }

            Button { model.showGoogleChooser = true } label: {
                HStack(spacing: Space.xs) {
                    GoogleGlyph().frame(width: 22, height: 22)
                    Text("Continue with Google")
                }
            }
            .buttonStyle(.wbGoogle)

            HStack(spacing: Space.s) {
                Rectangle().fill(.wbBorder).frame(height: 1)
                Text("or").font(.footnote).foregroundStyle(.wbMuted)
                Rectangle().fill(.wbBorder).frame(height: 1)
            }

            LabeledField(title: "Email", text: $model.email, prompt: "you@example.com",
                         error: model.emailError, keyboard: .emailAddress,
                         contentType: .emailAddress, capitalization: .never)
            LabeledField(title: "Password", text: $model.password, prompt: "Your password",
                         error: model.passwordError, isSecure: true, revealable: true, contentType: .password)

            HStack {
                Spacer()
                Button("Forgot password?") { model.showForgotPassword = true }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.wbBrand)
            }
            .padding(.top, -Space.xs)

            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.wbRed)
                    .padding(Space.s).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.wbRedSoft, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }

            LoadingButton(title: "Sign in", isLoading: model.isLoading) {
                Task { await model.signIn(appState: appState) }
            }

            Text("Use the account you created on the WebBlock website.")
                .font(.footnote).foregroundStyle(.wbMuted)
                .frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
        }
        .padding(Space.l)
        .glass(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
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
                        else { Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.wbBrand) }
                    }
                    .padding(.vertical, Space.s).padding(.horizontal, Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.wbCard, in: Capsule())
                    .overlay(Capsule().stroke(Color.wbBrand.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: Color.wbBrand.opacity(0.15), radius: 10, y: 4)
                    .contentShape(Capsule())
                }
                .buttonStyle(.wbCardPress)
                .disabled(model.isLoading)
                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.wbRed)
                }
                Spacer()
            }
            .padding(Space.screen)
            .liquidBackdrop()
            .navigationTitle("Choose an account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Forgot password flow (3 steps)

// MARK: - View model

@MainActor @Observable
final class ForgotPasswordViewModel {
    var step = 1
    var email: String
    var code = ""
    var newPassword = ""
    var confirm = ""
    var isLoading = false
    var errorMessage: String?
    var secondsLeft = 300
    var goingBack = false

    private let service: WebBlockService
    init(email: String, service: WebBlockService = ServiceLocator.current) {
        self.email = email
        self.service = service
    }

    var isEmailValid: Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !email.contains(" ")
    }

    // Password rules
    var hasLength: Bool { newPassword.count >= 8 }
    var hasUpperAndNumber: Bool {
        newPassword.contains(where: \.isUppercase) && newPassword.contains(where: \.isNumber)
    }
    var hasSymbol: Bool { newPassword.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace } }
    var strength: Int {
        guard !newPassword.isEmpty else { return 0 }
        return [hasLength, hasUpperAndNumber, hasSymbol, newPassword.count >= 12].filter { $0 }.count
    }
    var strengthLabel: String { ["", "Weak", "Fair", "Good", "Strong"][strength] }
    var matches: Bool { !confirm.isEmpty && confirm == newPassword }
    var canUpdate: Bool { hasLength && hasUpperAndNumber && matches && !isLoading }

    var timerText: String { String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60) }

    func tick() { if secondsLeft > 0 { secondsLeft -= 1 } }

    func goBack() { goingBack = true; errorMessage = nil; step = max(1, step - 1) }
    func goTo(_ s: Int) { goingBack = s < step; errorMessage = nil; step = s }

    func sendCode() async {
        guard isEmailValid else {
            errorMessage = email.isEmpty ? "Enter your email address." : "Enter a valid email address."
            return
        }
        await run {
            try await service.requestPasswordReset(email: email)
            code = ""; secondsLeft = 300
            goingBack = false; step = 2
        }
    }

    func resend() async {
        await run { try await service.requestPasswordReset(email: email); code = ""; secondsLeft = 300 }
    }

    func verify() async {
        guard secondsLeft > 0 else { errorMessage = "This code has expired. Tap “Resend code” to get a new one."; return }
        guard code.count == 6 else { errorMessage = "Enter the 6-digit code we emailed you."; return }
        await run {
            try await service.verifyResetCode(email: email, code: code)
            goingBack = false; step = 3
        }
    }

    func update() async -> Bool {
        guard hasLength, hasUpperAndNumber else {
            errorMessage = "Use at least 8 characters, with one uppercase letter and one number."
            return false
        }
        guard !confirm.isEmpty else { errorMessage = "Confirm your new password."; return false }
        guard matches else { errorMessage = "Passwords don’t match."; return false }
        var ok = false
        await run {
            try await service.resetPassword(email: email, code: code, newPassword: newPassword)
            ok = true
        }
        return ok
    }

    private func run(_ work: () async throws -> Void) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { try await work() } catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Flow (3 steps)

struct ForgotPasswordFlow: View {
    /// Called when the flow closes; the email is non-nil when the password was updated.
    let onFinish: (String?) -> Void
    @State private var model: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss

    init(initialEmail: String, onFinish: @escaping (String?) -> Void) {
        _model = State(initialValue: ForgotPasswordViewModel(email: initialEmail))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            AuthBackground()

            VStack(spacing: 0) {
                topBar
                progress.padding(.top, Space.s)

                ScrollView {
                    ZStack {
                        switch model.step {
                        case 1: EmailStep(model: model)
                        case 2: CodeStep(model: model)
                        default: PasswordStep(model: model) {
                            onFinish(model.email); dismiss()
                        }
                        }
                    }
                    .id(model.step)
                    .transition(.asymmetric(
                        insertion: .move(edge: model.goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: model.goingBack ? .trailing : .leading).combined(with: .opacity)))
                    .padding(.horizontal, Space.screen).padding(.top, Space.l)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.step)
    }

    private var topBar: some View {
        HStack {
            Button {
                if model.step == 1 { onFinish(nil); dismiss() } else { model.goBack() }
            } label: {
                Label("Back", systemImage: "chevron.left").font(.body.weight(.medium)).foregroundStyle(Color.wbBrand)
            }
            .buttonStyle(.wbCardPress)
            Spacer()
            Text("Step \(model.step) of 3").font(.headline).foregroundStyle(.wbText)
            Spacer()
            Label("Back", systemImage: "chevron.left").font(.body.weight(.medium)).hidden()
        }
        .padding(.horizontal, Space.screen).padding(.top, Space.xs)
    }

    private var progress: some View {
        HStack(spacing: Space.xs) {
            ForEach(1...3, id: \.self) { i in
                Capsule().fill(Color.wbBrand.opacity(0.18))
                    .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 0.5))
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: i <= model.step ? geo.size.width : 0)
                                .shadow(color: Color(hex: 0x4379D6).opacity(0.35), radius: 3, y: 1)
                        }
                    }
                    .frame(height: 6)
            }
        }
        .padding(.horizontal, Space.screen)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: model.step)
    }
}

/// Faint graph-paper grid behind the flow.
private struct GridBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            let step: CGFloat = 40
            var x: CGFloat = 0
            while x < size.width { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += step }
            var y: CGFloat = 0
            while y < size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)); y += step }
            ctx.stroke(path, with: .color(Color.wbBrand.opacity(0.06)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct StepHeading: View {
    let title: String
    let subtitle: Text
    var body: some View {
        VStack(spacing: Space.xs) {
            Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(.wbText)
            subtitle.font(.body).foregroundStyle(.wbMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}

private struct ErrorLine: View {
    let message: String?
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.wbRed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Step 1: email

private struct EmailStep: View {
    @Bindable var model: ForgotPasswordViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            StepHeading(title: "Forgot your password?",
                        subtitle: Text("Enter the email you signed up with and we’ll help you reset it."))
                .padding(.bottom, Space.s)
            LabeledField(title: "Email", text: $model.email, prompt: "you@example.com",
                         error: model.email.isEmpty || model.isEmailValid ? nil : "Enter a valid email address.",
                         keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never,
                         hint: "We’ll send a 6-digit code to reset your password.")
            ErrorLine(message: model.errorMessage)
            LoadingButton(title: "Send code", isLoading: model.isLoading) { Task { await model.sendCode() } }
        }
    }
}

// MARK: - Step 2: 6-digit code

private struct CodeStep: View {
    @Bindable var model: ForgotPasswordViewModel
    @FocusState private var focused: Bool
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            StepHeading(title: "Check your email",
                        subtitle: Text("We sent a 6-digit code to ") + Text(model.email).fontWeight(.semibold).foregroundColor(Color.wbText)
                                  + Text(". Enter it below to reset your password."))
                .padding(.bottom, Space.s)

            ZStack {
                TextField("", text: $model.code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .focused($focused).opacity(0.02).frame(height: 1)
                    .onChange(of: model.code) { _, new in
                        let digits = String(new.filter(\.isNumber).prefix(6))
                        if digits != new { model.code = digits }
                    }
                HStack(spacing: Space.xs) {
                    ForEach(0..<6, id: \.self) { i in codeBox(i) }
                }
                .contentShape(Rectangle()).onTapGesture { focused = true }
            }

            HStack {
                Label {
                    Text("Code expires in ").foregroundStyle(.wbMuted) + Text(model.timerText).fontWeight(.bold).foregroundColor(Color.wbText)
                } icon: { Image(systemName: "clock").foregroundStyle(.wbMuted) }
                .font(.footnote)
                Spacer()
                Button("Resend code") { Task { await model.resend() } }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Color.wbBrand)
                    .disabled(model.isLoading)
            }
            ErrorLine(message: model.errorMessage)

            LoadingButton(title: "Verify code", isLoading: model.isLoading) { Task { await model.verify() } }

            HStack(spacing: 4) {
                Text("Can’t find it? Check your spam folder or").foregroundStyle(.wbMuted)
                Button("change email") { model.goTo(1) }.foregroundStyle(Color.wbBrand).fontWeight(.semibold)
            }
            .font(.footnote).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }
        .onAppear { focused = true }
        .onReceive(timer) { _ in model.tick() }
    }

    private func codeBox(_ i: Int) -> some View {
        let chars = Array(model.code)
        let isCurrent = focused && i == min(chars.count, 5)
        return Text(i < chars.count ? String(chars[i]) : "")
            .font(.title2.weight(.semibold)).foregroundStyle(.wbText)
            .frame(maxWidth: .infinity).frame(height: 62)
            .glass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCurrent ? Color.wbBrand : Color.wbBorder, lineWidth: isCurrent ? 1.5 : 1))
            .overlay {
                if isCurrent && i >= chars.count { BlinkingCaret() }
            }
            .scaleEffect(i < chars.count ? 1 : 0.97)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: chars.count)
    }
}

private struct BlinkingCaret: View {
    @State private var on = true
    var body: some View {
        Rectangle().fill(Color.wbBrand).frame(width: 2, height: 26).opacity(on ? 1 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever()) { on.toggle() } }
    }
}

// MARK: - Step 3: new password

private struct PasswordStep: View {
    @Bindable var model: ForgotPasswordViewModel
    let done: () -> Void
    @State private var showNew = false
    @State private var showConfirm = false

    private var strengthTint: Color {
        switch model.strength { case 1: .wbRed; case 2: .wbAmber; default: .wbGreen }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            StepHeading(title: "Set a new password",
                        subtitle: Text("Code verified. Choose a new password for ")
                                  + Text(model.email).fontWeight(.semibold).foregroundColor(Color.wbText) + Text("."))
                .padding(.bottom, Space.s)

            LabeledField(title: "New password", text: $model.newPassword, prompt: "New password",
                         isSecure: true, revealable: true, contentType: .newPassword)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule().fill(i < model.strength ? strengthTint : Color.wbBorder).frame(height: 4)
                    }
                }
                HStack {
                    Text("Password strength").font(.footnote).foregroundStyle(.wbMuted)
                    Spacer()
                    Text(model.strengthLabel).font(.footnote.weight(.bold)).foregroundStyle(strengthTint)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.strength)

            VStack(alignment: .leading, spacing: Space.xs) {
                rule("At least 8 characters", model.hasLength)
                rule("One uppercase letter and one number", model.hasUpperAndNumber)
                rule("One symbol (optional)", model.hasSymbol)
            }

            LabeledField(title: "Confirm new password", text: $model.confirm, prompt: "Confirm new password",
                         error: !model.confirm.isEmpty && !model.matches ? "Passwords don’t match." : nil,
                         isSecure: true, revealable: true, contentType: .newPassword)

            ErrorLine(message: model.errorMessage)

            LoadingButton(title: "Update password", isLoading: model.isLoading) {
                Task { if await model.update() { done() } }
            }

            Text("Next, you’ll sign in with your new password.")
                .font(.footnote).foregroundStyle(.wbMuted).frame(maxWidth: .infinity)
        }
    }

    private func rule(_ text: String, _ ok: Bool) -> some View {
        Label(text, systemImage: ok ? "checkmark.circle" : "circle")
            .font(.subheadline).foregroundStyle(ok ? Color.wbGreen : Color.wbMuted)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: ok)
    }
}


// MARK: - Google button

/// The four-colour Google "G", drawn as arcs so no image asset is needed.
struct GoogleGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let w = d * 0.2
            ZStack {
                arc(0, 50, Color(hex: 0x4285F4), w)
                arc(50, 135, Color(hex: 0x34A853), w)
                arc(135, 205, Color(hex: 0xFBBC05), w)
                arc(205, 315, Color(hex: 0xEA4335), w)
                Rectangle().fill(Color(hex: 0x4285F4))
                    .frame(width: d * 0.5, height: w)
                    .position(x: d * 0.75, y: d / 2)
            }
            .frame(width: d, height: d)
            .padding(w / 2)
        }
        .accessibilityHidden(true)
    }

    private func arc(_ from: Double, _ to: Double, _ color: Color, _ width: CGFloat) -> some View {
        Circle().inset(by: width / 2)
            .trim(from: from / 360, to: to / 360)
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }
}

/// White pill with a soft border (no shadow), centred icon + label (the "Continue with Google" look).
struct GoogleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(.wbText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .liquidGlass(in: Capsule(), interactive: true, glow: false)
            .overlay(Capsule().stroke(Color.wbBorder, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GoogleButtonStyle {
    static var wbGoogle: GoogleButtonStyle { .init() }
}
