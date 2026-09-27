import SwiftUI
import UIKit

/// The app's very first screen — no separate splash/"tap to sign in" screen
/// in front of it. Design decision: get straight to the email/password form,
/// no extra remote click needed to reveal it.
struct LoginView: View {
    @Environment(AuthManager.self) var authManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var phoneLogin = PhoneLoginServer()
    @State private var phoneLoginQR: UIImage?

    var body: some View {
        ZStack {
            AuroraBackground()
            switch authManager.loginPhase {
            case .credentialsEntry:
                credentialsEntry
            case .exchangingTokens:
                exchangingView
            case .failed(let message):
                failedView(message: message)
            }
        }
        // Runs for as long as the login screen is up — including the
        // failed state, so the phone can simply retry from its own page.
        .onAppear { phoneLogin.start(authManager: authManager) }
        .onDisappear { phoneLogin.stop() }
        .onChange(of: phoneLogin.url) { _, url in
            phoneLoginQR = url.flatMap { QRCode.make(from: $0.absoluteString) }
        }
    }

    // MARK: Credentials Entry
    //
    // CONFIRMED 2026-07-27/28 by capturing the real Android TV app's traffic
    // (Frida SSL-pinning bypass + mitmproxy): a direct email/password login,
    // no Cloudflare Turnstile challenge involved (that only gates the
    // browser-facing /auth/login page, not this REST endpoint) — exactly
    // what that app's own "Sign in Manually" screen does.
    private var credentialsEntry: some View {
        VStack(spacing: 44) {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(BoosteroidTheme.brandGradient)
                    Text("Afterburner")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 64, weight: .heavy))
                .shadow(color: BoosteroidTheme.violet.opacity(0.6), radius: 30)

                Text("Unofficial Apple TV client for Boosteroid")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.65))
            }

            HStack(alignment: .center, spacing: 64) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Sign in to Boosteroid")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    credentialsForm
                }
                .frame(width: 600)

                if let qr = phoneLoginQR {
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 1, height: 360)
                    phoneLoginPanel(qr: qr)
                        .frame(width: 440)
                }
            }
            .padding(56)
            .glassPanel(cornerRadius: 36)
        }
        .padding(60)
    }

    private var credentialsForm: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                // .textInputAutocapitalization(.never) matters here: without
                // it, tvOS's on-screen keyboard capitalizes the first letter
                // by default, silently turning "name@x.com" into
                // "Name@x.com" — a real reported symptom ("we could not find
                // those credentials" with a confirmed-correct password) that
                // this fixes.
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .padding(.top, 8)

            Button("Sign In") {
                authManager.submitCredentials(email: email, password: password)
            }
            // .bordered (not .borderedProminent) + .gray: gives the standard
            // tvOS look used everywhere else in the app — translucent gray
            // fill with white text by default, and the system auto-inverts
            // to a solid white fill with dark text on focus. borderedProminent
            // keeps a solid fill at all times, so tint(.white) here produced
            // a white background with white label text — invisible.
            .buttonStyle(.bordered)
            .tint(.gray)
            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
        }
    }

    // MARK: Phone Login
    //
    // See PhoneLoginServer: the QR code opens a sign-in page served by this
    // Apple TV itself, so the password can be typed on the phone instead.
    private func phoneLoginPanel(qr: UIImage) -> some View {
        VStack(spacing: 20) {
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .frame(width: 260, height: 260)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            Text("Or sign in with your phone")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Scan the code with your phone's camera. Your phone must be on the same network as this Apple TV.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Exchanging Tokens

    private var exchangingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            Text("Signing in...")
                .font(.title2)
                .foregroundStyle(.white)
        }
    }

    // MARK: Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 32) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text("Sign In Failed")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
            // Diagnostic messages (raw response bodies) can be long — scroll
            // rather than clip off-screen.
            ScrollView {
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)

            Button("Try Again") { authManager.login() }
                .buttonStyle(.bordered)
                .tint(.gray)
        }
        .padding(80)
    }
}
