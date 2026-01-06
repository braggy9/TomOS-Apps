import AuthenticationServices
import Foundation
import Security

// MARK: - M365 Calendar Manager

class M365CalendarManager: NSObject, ObservableObject {
    static let shared = M365CalendarManager()

    // Azure App Registration - Mixtape Running Supply tenant (multi-tenant)
    private let clientId = "5b4341ac-767a-494d-ba4c-8ac6f0c1876f"
    private let redirectUri = "msauth.com.tomos.app://auth"
    private let scopes = "Calendars.Read User.Read offline_access"
    private let authority = "https://login.microsoftonline.com/common"

    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var userName: String?
    @Published var m365Events: [M365CalendarEvent] = []
    @Published var powerAutomateEvents: [M365CalendarEvent] = []
    @Published var error: String?

    private var accessToken: String?

    // Combined events from both sources
    var allEvents: [M365CalendarEvent] {
        let combined = m365Events + powerAutomateEvents
        return combined.sorted { $0.startDate < $1.startDate }
    }
    private var refreshToken: String?
    private var webAuthSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        loadTokensFromKeychain()
        // Also fetch Power Automate synced events (work calendar fallback)
        Task { await fetchPowerAutomateEvents() }
    }

    // MARK: - Authentication

    func signIn(from anchor: ASPresentationAnchor) {
        let authEndpoint = "\(authority)/oauth2/v2.0/authorize"
        let responseType = "code"
        let state = UUID().uuidString

        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: responseType),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let authURL = components.url else {
            error = "Failed to create auth URL"
            return
        }

        isLoading = true

        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "msauth.com.tomos.app"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        // User cancelled - not an error
                        return
                    }
                    self?.error = error.localizedDescription
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self?.error = "No authorization code received"
                    return
                }

                Task {
                    await self?.exchangeCodeForTokens(code: code)
                }
            }
        }

        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }

    private func exchangeCodeForTokens(code: String) async {
        let tokenEndpoint = "\(authority)/oauth2/v2.0/token"

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "scope": scopes
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                self.refreshToken = tokenResponse.refreshToken
                self.isSignedIn = true
                self.saveTokensToKeychain()
            }

            await fetchUserProfile()
            await fetchCalendarEvents()

        } catch {
            await MainActor.run {
                self.error = "Token exchange failed: \(error.localizedDescription)"
            }
        }
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        isSignedIn = false
        userName = nil
        m365Events = []
        deleteTokensFromKeychain()
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken else { return false }

        let tokenEndpoint = "\(authority)/oauth2/v2.0/token"

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "scope": scopes
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                if let newRefresh = tokenResponse.refreshToken {
                    self.refreshToken = newRefresh
                }
                self.saveTokensToKeychain()
            }
            return true
        } catch {
            await MainActor.run {
                self.signOut()
            }
            return false
        }
    }

    // MARK: - Graph API Calls

    private func fetchUserProfile() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                if await refreshAccessToken() {
                    await fetchUserProfile()
                }
                return
            }

            let user = try JSONDecoder().decode(GraphUser.self, from: data)
            await MainActor.run {
                self.userName = user.displayName
            }
        } catch {
            print("Failed to fetch user profile: \(error)")
        }
    }

    func fetchCalendarEvents() async {
        guard let token = accessToken else { return }

        await MainActor.run { self.isLoading = true }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 7, to: startOfDay)!

        let dateFormatter = ISO8601DateFormatter()
        let startTime = dateFormatter.string(from: startOfDay)
        let endTime = dateFormatter.string(from: endOfDay)

        let urlString = "https://graph.microsoft.com/v1.0/me/calendarview?startDateTime=\(startTime)&endDateTime=\(endTime)&$orderby=start/dateTime&$top=50"

        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Pacific/Auckland", forHTTPHeaderField: "Prefer") // NZ timezone

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                if await refreshAccessToken() {
                    await fetchCalendarEvents()
                }
                return
            }

            let eventsResponse = try JSONDecoder().decode(GraphCalendarResponse.self, from: data)

            await MainActor.run {
                self.m365Events = eventsResponse.value.map { M365CalendarEvent(from: $0) }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to fetch calendar: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Power Automate Fallback

    /// Fetch events from TomOS API (synced by Power Automate from work M365)
    func fetchPowerAutomateEvents() async {
        guard let url = URL(string: "https://tomos-task-api.vercel.app/api/m365-calendar") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PowerAutomateResponse.self, from: data)

            await MainActor.run {
                self.powerAutomateEvents = response.events.map { event in
                    M365CalendarEvent(
                        id: event.id,
                        title: event.subject,
                        startDate: ISO8601DateFormatter().date(from: event.start) ?? Date(),
                        endDate: ISO8601DateFormatter().date(from: event.end) ?? Date(),
                        location: event.location,
                        isAllDay: event.isAllDay,
                        organizer: event.organizer
                    )
                }
            }
        } catch {
            print("Power Automate fetch error: \(error)")
        }
    }

    // MARK: - Keychain Storage

    private let keychainService = "com.tomos.app.m365"

    private func saveTokensToKeychain() {
        if let accessToken = accessToken {
            saveToKeychain(key: "accessToken", value: accessToken)
        }
        if let refreshToken = refreshToken {
            saveToKeychain(key: "refreshToken", value: refreshToken)
        }
    }

    private func loadTokensFromKeychain() {
        accessToken = loadFromKeychain(key: "accessToken")
        refreshToken = loadFromKeychain(key: "refreshToken")
        isSignedIn = accessToken != nil

        if isSignedIn {
            Task {
                await fetchUserProfile()
                await fetchCalendarEvents()
            }
        }
    }

    private func deleteTokensFromKeychain() {
        deleteFromKeychain(key: "accessToken")
        deleteFromKeychain(key: "refreshToken")
    }

    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Presentation Context

extension M365CalendarManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
}

// MARK: - Models

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct GraphUser: Codable {
    let displayName: String
}

private struct GraphCalendarResponse: Codable {
    let value: [GraphEvent]
}

// Power Automate response from TomOS API
private struct PowerAutomateResponse: Codable {
    let events: [PowerAutomateEvent]

    struct PowerAutomateEvent: Codable {
        let id: String
        let subject: String
        let start: String
        let end: String
        let location: String?
        let isAllDay: Bool
        let organizer: String?
    }
}

private struct GraphEvent: Codable {
    let id: String
    let subject: String
    let start: GraphDateTime
    let end: GraphDateTime
    let location: GraphLocation?
    let isAllDay: Bool
    let organizer: GraphOrganizer?

    struct GraphDateTime: Codable {
        let dateTime: String
        let timeZone: String
    }

    struct GraphLocation: Codable {
        let displayName: String?
    }

    struct GraphOrganizer: Codable {
        let emailAddress: GraphEmail?

        struct GraphEmail: Codable {
            let name: String?
        }
    }
}

// MARK: - M365 Calendar Event

struct M365CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
    let organizer: String?

    // Public init for Power Automate events
    init(id: String, title: String, startDate: Date, endDate: Date, location: String?, isAllDay: Bool, organizer: String?) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.isAllDay = isAllDay
        self.organizer = organizer
    }

    fileprivate init(from event: GraphEvent) {
        self.id = event.id
        self.title = event.subject
        self.location = event.location?.displayName
        self.isAllDay = event.isAllDay
        self.organizer = event.organizer?.emailAddress?.name

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        if let start = formatter.date(from: event.start.dateTime) {
            self.startDate = start
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            self.startDate = formatter.date(from: event.start.dateTime) ?? Date()
        }

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let end = formatter.date(from: event.end.dateTime) {
            self.endDate = end
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            self.endDate = formatter.date(from: event.end.dateTime) ?? Date()
        }
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }

    var durationString: String {
        let duration = endDate.timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startDate)
    }
}
