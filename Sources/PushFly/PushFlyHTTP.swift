//
//  PushFlyHTTP.swift
//  PushFly
//
//  Thin wrapper around URLSession that speaks the PushFly SDK wire
//  contract from `docs/BACKEND_API.md`:
//
//    - JSON bodies, JSON responses
//    - `Authorization: Bearer <publishableKey>` on every call
//    - `X-PushFly-SDK-Version` / `X-PushFly-SDK-Platform` identifying headers
//    - Standard `{ code, message, details? }` error envelope
//    - `Retry-After` header honoured for 429 responses
//
//  Transport is injectable so unit tests can stub responses without
//  touching the network stack.
//

import Foundation

/// Minimum surface the HTTP client needs from a URLSession-like type.
/// Lets tests supply canned responses.
public protocol PushFlyHTTPTransport: AnyObject {
    func perform(
        _ request: URLRequest,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    )
}

extension URLSession: PushFlyHTTPTransport {
    public func perform(
        _ request: URLRequest,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        let task = dataTask(with: request) { data, response, error in
            completion(data, response, error)
        }
        task.resume()
    }
}

/// Internal HTTP client. Handlers build a request, the client executes
/// it, and the completion closure receives a typed decoded value or a
/// ``PushFlyError``.
///
/// The client does not carry an `Authorization` header — the SDK
/// identifies its tenant via the app's `CFBundleIdentifier`, which
/// every request body includes.
final class PushFlyHTTPClient {
    private let transport: PushFlyHTTPTransport
    private let baseUrl: String

    init(transport: PushFlyHTTPTransport, baseUrl: String) {
        self.transport = transport
        self.baseUrl = baseUrl
        
    }

    // MARK: - Public

    /// Send a request whose response body is a decodable type.
    func send<Response: Decodable>(
        method: String,
        path: String,
        body: Encodable,
        responseType: Response.Type,
        completion: @escaping (Result<Response, PushFlyError>) -> Void
    ) {
        perform(method: method, path: path, body: body) { result in
            switch result {
            case .success(let data):
                guard !data.isEmpty else {
                    completion(.failure(PushFlyError(
                        code: .invalidResponse,
                        message: "Empty body where \(Response.self) expected."
                    )))
                    return
                }
                do {
                    let decoder = JSONDecoder()
                    let value = try decoder.decode(Response.self, from: data)
                    completion(.success(value))
                } catch {
                    completion(.failure(PushFlyError(
                        code: .invalidResponse,
                        message: "Failed to decode \(Response.self): \(error.localizedDescription)",
                        underlying: error
                    )))
                }
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    /// Send a request whose response we don't care about (204s, or
    /// `/v1/sdk/validate` where we key off the status alone).
    func sendVoid(
        method: String,
        path: String,
        body: Encodable,
        completion: @escaping (Result<Data, PushFlyError>) -> Void
    ) {
        perform(method: method, path: path, body: body, completion: completion)
    }

    // MARK: - Core

    private func perform(
        method: String,
        path: String,
        body: Encodable,
        completion: @escaping (Result<Data, PushFlyError>) -> Void
    ) {
        let urlString = baseUrl + PushFlyConfig.apiBasePath + path
        
        guard let url = URL(string: urlString) else {
            completion(.failure(PushFlyError(
                code: .invalidRequest,
                message: "Invalid URL: \(urlString)"
            )))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(PushFlyConfig.sdkVersion, forHTTPHeaderField: "X-PushFly-SDK-Version")
        request.setValue("ios", forHTTPHeaderField: "X-PushFly-SDK-Platform")
        // Not parsed by the backend, but surfaces the SDK + host app
        // in ops dashboards so triage doesn't have to unwind headers.
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        request.setValue(
            "PushFly-iOS/\(PushFlyConfig.sdkVersion) (\(bundleId))",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        } catch {
            completion(.failure(PushFlyError(
                code: .invalidRequest,
                message: "Failed to encode request body: \(error.localizedDescription)",
                underlying: error
            )))
            return
        }

        transport.perform(request) { data, response, error in
            if let error = error {
                completion(.failure(PushFlyError(
                    code: .networkError,
                    message: "Network error: \(error.localizedDescription)",
                    underlying: error
                )))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(PushFlyError(
                    code: .invalidResponse,
                    message: "Response was not an HTTPURLResponse."
                )))
                return
            }
            let body = data ?? Data()
            if (200..<300).contains(http.statusCode) {
                completion(.success(body))
                return
            }
            completion(.failure(Self.parseError(status: http.statusCode, headers: http.allHeaderFields, data: body)))
        }
    }

    /// Parse a `{ code, message, field?, details? }` error envelope
    /// into a typed ``PushFlyError``. Exposed as `static` so tests can
    /// exercise it without spinning up a full client.
    static func parseError(status: Int, headers: [AnyHashable: Any], data: Data) -> PushFlyError {
        let retryAfter: Int? = {
            if let raw = headers["Retry-After"] as? String, let v = Int(raw) { return v }
            if let raw = headers["retry-after"] as? String, let v = Int(raw) { return v }
            return nil
        }()
        struct Envelope: Decodable {
            let code: String?
            let message: String?
            let field: String?
            let details: Details?
            struct Details: Decodable { let retryAfterSeconds: Int? }
        }
        var code = PushFlyErrorCode(rawValue: "http_\(status)")
        var message = "Request failed with HTTP \(status)."
        var parsedRetry: Int? = retryAfter
        var parsedField: String? = nil
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            if let c = envelope.code, !c.isEmpty { code = PushFlyErrorCode(rawValue: c) }
            if let m = envelope.message, !m.isEmpty { message = m }
            if parsedRetry == nil, let r = envelope.details?.retryAfterSeconds { parsedRetry = r }
            if let f = envelope.field, !f.isEmpty { parsedField = f }
        }
        return PushFlyError(
            code: code,
            message: message,
            httpStatus: status,
            retryAfterSeconds: parsedRetry,
            field: parsedField
        )
    }
}

/// Type-erasing `Encodable` so the HTTP client accepts any body type
/// without generic propagation through the public surface.
private struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self.encodeFn = { try wrapped.encode(to: $0) } }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}
