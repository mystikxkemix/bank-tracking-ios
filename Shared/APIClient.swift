import Foundation

/// Every failure of an API call, with a French message ready for the UI.
enum APIError: LocalizedError, Equatable {
    /// No valid session: the user must log in again.
    case unauthorized
    /// The API answered with an error; `message` is already user-facing French text.
    case server(status: Int, message: String)
    case insecureConnection
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Ta session a expiré. Reconnecte-toi."
        case .server(_, let message):
            return message
        case .insecureConnection:
            return "Le serveur doit être en HTTPS (https://...)."
        case .network(let message):
            return "Serveur injoignable : \(message)"
        case .decoding:
            return "Réponse du serveur inattendue. L'app et le serveur ne sont peut-être pas à jour."
        }
    }
}

/// Thin JSON client over `/api`. The session lives in the `bt_session` cookie:
/// - in the app, `HTTPCookieStorage.shared` keeps it (it survives restarts, the server gives it a max age);
/// - in the widget, there is no shared cookie jar, so the token copied in `SharedStore` is sent by hand.
final class APIClient {
    static let sessionCookieName: String = "bt_session"

    let baseURL: URL
    private let session: URLSession
    /// Set in the widget only: sent as the `bt_session` cookie on every request.
    private let sessionToken: String?
    private let decoder: JSONDecoder = JSONDecoder()
    private let encoder: JSONEncoder = JSONEncoder()

    init(baseURL: URL, session: URLSession = .shared, sessionToken: String? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.sessionToken = sessionToken
    }

    /// Current value of the session cookie for this server (after login), to share with the widget.
    var storedSessionToken: String? {
        session.configuration.httpCookieStorage?.cookies(for: baseURL)?
            .first { (cookie: HTTPCookie) -> Bool in cookie.name == APIClient.sessionCookieName }?.value
    }

    /// Builds `<base>/api<path>?query`. Keeps any path prefix of the base URL (reverse proxy sub-path).
    func url(_ path: String, query: [String: String] = [:]) -> URL {
        let base: String = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        var components: URLComponents = URLComponents(string: base + "/api" + path)!
        if !query.isEmpty {
            components.queryItems = query.keys.sorted().map { (key: String) -> URLQueryItem in
                URLQueryItem(name: key, value: query[key])
            }
        }
        return components.url!
    }

    func get<Response: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> Response {
        let request: URLRequest = URLRequest(url: url(path, query: query))
        let data: Data = try await send(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// POST without a response body (the API answers 204).
    func post<Body: Encodable>(_ path: String, body: Body) async throws {
        var request: URLRequest = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        _ = try await send(request)
    }

    func post(_ path: String) async throws {
        var request: URLRequest = URLRequest(url: url(path))
        request.httpMethod = "POST"
        _ = try await send(request)
    }

    /// Forgets the session cookie of this server.
    func clearCookies() {
        guard let storage: HTTPCookieStorage = session.configuration.httpCookieStorage else { return }
        for cookie in storage.cookies(for: baseURL) ?? [] {
            storage.deleteCookie(cookie)
        }
    }

    private func send(_ original: URLRequest) async throws -> Data {
        var request: URLRequest = original
        if let token: String = sessionToken {
            request.httpShouldHandleCookies = false
            request.setValue("\(APIClient.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .appTransportSecurityRequiresSecureConnection {
            throw APIError.insecureConnection
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http: HTTPURLResponse = response as? HTTPURLResponse else {
            throw APIError.network("réponse invalide")
        }
        if (200..<300).contains(http.statusCode) {
            return data
        }
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        if let payload: APIErrorPayload = try? decoder.decode(APIErrorPayload.self, from: data) {
            throw APIError.server(status: http.statusCode, message: payload.error.message)
        }
        throw APIError.server(status: http.statusCode, message: "Erreur du serveur (\(http.statusCode)).")
    }
}
