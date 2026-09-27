import Foundation
import Network
import Observation

// MARK: - Phone Login Server
//
// Lets the user type their Boosteroid email/password on their phone instead
// of with the Siri Remote. While the login screen is visible, a tiny HTTP
// server listens on the local network and LoginView shows its URL as a QR
// code. The phone's page POSTs the credentials back here, and they go through
// exactly the same AuthManager login as the on-screen form.
//
// Plain HTTP: there's no way to get a trusted certificate for a LAN IP, so
// the password crosses the home network unencrypted. The random pairing code
// in the URL keeps other devices on the network from posting to it blindly,
// and the listener only runs while the login screen is on screen.
@Observable
final class PhoneLoginServer {
    /// What the QR code encodes — nil until the listener is ready, or when
    /// there's no usable network interface.
    private(set) var url: URL?

    // Internal state only — `url` is the one thing the UI observes.
    @ObservationIgnored private var listener: NWListener?
    // Held directly rather than as an async callback closure: with this
    // project's approachable-concurrency settings, converting LoginView's
    // MainActor closure to a stored async function type miscompiled and
    // shifted the arguments (password arrived as the email) at runtime.
    @ObservationIgnored private weak var authManager: AuthManager?
    @ObservationIgnored private var pairingCode = ""
    @ObservationIgnored private var isSigningIn = false

    private static let maxRequestSize = 16 * 1024

    func start(authManager: AuthManager) {
        stop()
        self.authManager = authManager
        pairingCode = Self.makePairingCode()

        guard let listener = try? NWListener(using: .tcp) else { return }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            Task { @MainActor in
                // Ignore late updates from a listener stop() already replaced.
                guard let self, let listener, self.listener === listener else { return }
                self.listenerStateChanged(state)
            }
        }
        self.listener = listener
        listener.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        authManager = nil
        url = nil
    }

    private func listenerStateChanged(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port, let host = Self.localIPv4Address() else {
                url = nil
                return
            }
            url = URL(string: "http://\(host):\(port.rawValue)/\(pairingCode)")
        case .failed, .cancelled:
            url = nil
        default:
            break
        }
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffered: Data())
    }

    /// Accumulates until a full request (headers + Content-Length body) has
    /// arrived — a POST from Safari often comes in more than one chunk.
    private func receive(on connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestSize) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else {
                    connection.cancel()
                    return
                }
                var buffered = buffered
                if let data { buffered.append(data) }
                if let request = HTTPRequest(parsing: buffered) {
                    await self.respond(to: request, on: connection)
                } else if isComplete || error != nil || buffered.count > Self.maxRequestSize {
                    connection.cancel()
                } else {
                    self.receive(on: connection, buffered: buffered)
                }
            }
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) async {
        guard request.path == "/" + pairingCode else {
            Self.send(status: "404 Not Found", html: Self.expiredPage, on: connection)
            return
        }
        switch request.method {
        case "GET":
            Self.send(status: "200 OK", html: Self.formPage(), on: connection)
        case "POST":
            let fields = Self.parseForm(request.body)
            // Same trimming rule as the TV form: the email only, never the password.
            let email = (fields["email"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let password = fields["password"] ?? ""
            guard !email.isEmpty, !password.isEmpty else {
                Self.send(status: "200 OK", html: Self.formPage(email: email, error: "Enter both your email and password."), on: connection)
                return
            }
            guard let authManager, !isSigningIn else {
                Self.send(status: "200 OK", html: Self.formPage(email: email, error: "The TV is already signing in. Wait a moment and try again."), on: connection)
                return
            }
            isSigningIn = true
            let error = await authManager.submitCredentialsFromPhone(email: email, password: password)
            isSigningIn = false
            if let error {
                Self.send(status: "200 OK", html: Self.formPage(email: email, error: error), on: connection)
            } else {
                Self.send(status: "200 OK", html: Self.successPage, on: connection)
            }
        default:
            Self.send(status: "405 Method Not Allowed", html: Self.expiredPage, on: connection)
        }
    }

    private static func send(status: String, html: String, on connection: NWConnection) {
        let body = Data(html.utf8)
        let header = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: text/html; charset=utf-8\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: Helpers

    /// Unambiguous characters only (no 0/o, 1/l/i), in case someone types the
    /// URL by hand. randomElement() uses the system CSPRNG.
    private static func makePairingCode() -> String {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<10).map { _ in alphabet.randomElement()! })
    }

    /// The Apple TV's own address on the LAN. Prefers en0, then any other
    /// en* interface — Wi-Fi and Ethernet swap names between Apple TV models.
    private static func localIPv4Address() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var candidates: [(interface: String, address: String)] = []
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  entry.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
                continue
            }
            let hostString = host.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            candidates.append((String(cString: entry.ifa_name), hostString))
        }
        return candidates.first { $0.interface == "en0" }?.address
            ?? candidates.first { $0.interface.hasPrefix("en") }?.address
    }

    private static func parseForm(_ body: Data) -> [String: String] {
        var fields: [String: String] = [:]
        for pair in String(decoding: body, as: UTF8.self).split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            fields[formDecode(parts[0])] = parts.count > 1 ? formDecode(parts[1]) : ""
        }
        return fields
    }

    private static func formDecode(_ value: Substring) -> String {
        value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
    }

    private static func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: Pages

    private static func formPage(email: String = "", error: String? = nil) -> String {
        let errorBlock = error.map { #"<p class="error">\#(htmlEscape($0))</p>"# } ?? ""
        return page("""
            <h1>Sign in to Boosteroid</h1>
            <p>Your Apple TV will sign in with these details.</p>
            \(errorBlock)
            <form method="post" onsubmit="var b=this.querySelector('button');b.disabled=true;b.textContent='Signing in…'">
              <input name="email" type="email" placeholder="Email" value="\(htmlEscape(email))" autocomplete="username" autocapitalize="off" autocorrect="off" required>
              <input name="password" type="password" placeholder="Password" autocomplete="current-password" required>
              <button type="submit">Sign In</button>
            </form>
            """)
    }

    private static let successPage = page("""
        <h1>Signed in</h1>
        <p>Your Apple TV is signed in. You can close this page.</p>
        """)

    private static let expiredPage = page("""
        <h1>Link expired</h1>
        <p>Scan the QR code on your TV again.</p>
        """)

    private static func page(_ body: String) -> String {
        """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Afterburner sign in</title>
        <style>
        body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#1b1d21;color:#fff;font:17px -apple-system,system-ui,sans-serif}
        main{width:100%;max-width:380px;padding:24px;box-sizing:border-box}
        h1{font-size:24px;margin:0 0 8px}
        p{color:#a9adb5;line-height:1.4}
        input,button{display:block;width:100%;box-sizing:border-box;font:inherit;padding:14px;border-radius:12px;margin-top:12px}
        input{border:1px solid #3a3e46;background:#25282e;color:#fff}
        button{border:0;background:linear-gradient(90deg,#7d3bed,#4f45e6,#3b82f5);color:#fff;font-weight:600}
        button:disabled{opacity:.6}
        .error{background:#3a1c22;color:#ffb4bf;padding:12px;border-radius:12px;white-space:pre-wrap;word-break:break-word;font-size:14px}
        </style></head><body><main>\(body)</main></body></html>
        """
    }
}

// MARK: - HTTP Request

private nonisolated struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    /// nil until `data` holds the whole header block plus Content-Length
    /// bytes of body.
    init?(parsing data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: data[..<headerEnd.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        let contentLength = lines.dropFirst().lazy.compactMap { line -> Int? in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                return nil
            }
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }.first ?? 0

        let body = data[headerEnd.upperBound...]
        guard body.count >= contentLength else { return nil }

        method = String(requestLine[0])
        path = String(requestLine[1])
        self.body = Data(body.prefix(contentLength))
    }
}
