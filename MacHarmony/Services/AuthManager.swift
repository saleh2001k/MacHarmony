//
//  AuthManager.swift
//  MacHarmony
//
//  Manages license authentication.
//  Supports two flows:
//    1. Browser-based: opens macharmony.com/app-login in Safari, polls for token
//    2. Native: magic link or password directly in-app (no browser required)
//  Stores auth state in Keychain (survives reinstall, encrypted).
//  Validates auth on every launch; applies 7-day offline grace period.
//  Trial users get full access for 3 days; paywall shown on expiry.
//

import Combine
import Foundation
import IOKit
import Security
import AppKit

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown              // checking Keychain on startup
    case unauthenticated      // no stored auth — show sign-in screen
    case authenticating       // waiting for email link click
    case validating           // calling validate-session or exchanging token
    case authenticated        // paid license valid
    case trial(daysLeft: Int) // active trial — show trial banner
    case trialExpired         // trial over — show paywall
    case offlineGrace(Int)    // server unreachable, N grace days remaining
    case expired              // grace period over — must re-auth
    case deviceConflict       // another Mac is active — visit /transfer
}

// MARK: - Keychain auth record

private struct AuthRecord: Codable {
    let email: String
    let deviceId: String
    let lastValidated: Date
    var licenseType: String    // "paid" or "trial"
    var trialEndsAt: Date?
}

// MARK: - API response types

private struct VerifyResponse: Decodable {
    let success: Bool?
    let email: String?
    let error: String?
    let code: String?
}

private struct ValidateResponse: Decodable {
    let valid: Bool
    let reason: String?
    let rateLimited: Bool?
    let licenseType: String?
    let trialEndsAt: String?
}

private struct PollResponse: Decodable {
    let pending: Bool?
    let success: Bool?
    let email: String?
    let code: String?
    let licenseType: String?
    let trialEndsAt: String?
}

private struct PasswordSignInResponse: Decodable {
    let access_token: String?
    let error_description: String?
    let error: String?
}

private struct CreateAppTokenResponse: Decodable {
    let token: String?
    let error: String?
    let code: String?
}

private struct CreateTrialResponse: Decodable {
    let success: Bool?
    let resent: Bool?
    let error: String?
    let code: String?
}

// MARK: - Website URLs

enum MacHarmonySite {
    static let origin = "https://macharmony.com"
    static var loginBaseURL: String { "\(origin)/app-login" }
    static var transferURL: URL { URL(string: "\(origin)/transfer")! }
    static var purchaseURL: URL { URL(string: "\(origin)/purchase")! }
    static var trialURL: URL { URL(string: "\(origin)/trial")! }
}

// MARK: - AuthManager

@MainActor
final class AuthManager: ObservableObject {

    @Published var state: AuthState = .unknown

    // ── Configuration ─────────────────────────────────────────────────────────
    private let supabaseURL        = "https://pjrmiyopkqzammvjcevo.supabase.co"
    private let supabaseAnonKey    = "sb_publishable_Ms0af_zvPwX64QCtbEv1aw_r00241Hu"
    private let edgeFunctionBase   = "https://pjrmiyopkqzammvjcevo.supabase.co/functions/v1"
    private let gracePeriodDays    = 7

    // ── Keychain keys ─────────────────────────────────────────────────────────
    private let keychainService    = "com.macharmony.auth"
    private let keychainAccount    = "auth-record"

    // ── Polling ───────────────────────────────────────────────────────────────
    private var pollTask: Task<Void, Never>?

    // MARK: - Device Fingerprint (IOPlatformUUID)

    nonisolated func deviceFingerprint() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }
        guard service != 0 else { return nil }
        return IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }

    nonisolated func deviceDisplayName() -> String {
        Host.current().localizedName ?? "Unknown Mac"
    }

    // MARK: - Browser-based Login (opens Safari)

    func openBrowserForLogin() {
        guard let fingerprint = deviceFingerprint() else {
            state = .unauthenticated
            return
        }
        let encodedName = deviceDisplayName()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Unknown%20Mac"
        var components = URLComponents(string: MacHarmonySite.loginBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "device_id",   value: fingerprint),
            URLQueryItem(name: "device_name", value: encodedName),
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
        state = .authenticating
        startPolling(deviceId: fingerprint)
    }

    // MARK: - Native Login: Password
    // Returns nil on success, or an error code string on failure.

    func signInWithPassword(email: String, password: String) async -> String? {
        guard let deviceId = deviceFingerprint() else {
            state = .unauthenticated
            return "NO_DEVICE"
        }
        state = .validating

        do {
            // 1. Authenticate via Supabase password
            let signIn = try await callPasswordSignIn(email: email, password: password)
            guard let accessToken = signIn.access_token else {
                state = .unauthenticated
                return "WRONG_PASSWORD"
            }

            // 2. Create an app token (validates license, handles trial expiry check)
            let appTokenResult = try await callCreateAppToken(
                accessToken: accessToken,
                deviceId: deviceId
            )

            if let code = appTokenResult.code {
                switch code {
                case "TRIAL_EXPIRED":   state = .trialExpired;    return "TRIAL_EXPIRED"
                case "NO_LICENSE":      state = .unauthenticated; return "NO_LICENSE"
                case "DEVICE_CONFLICT": state = .deviceConflict;  return "DEVICE_CONFLICT"
                default:                state = .unauthenticated; return code
                }
            }
            guard appTokenResult.token != nil else {
                state = .unauthenticated
                return "UNKNOWN_ERROR"
            }

            // 3. Consume the token via poll to get full license info (trial vs paid)
            let poll = try await callPollAppToken(deviceId: deviceId)
            if let email = poll.email, poll.success == true {
                handlePollSuccess(email: email, deviceId: deviceId, poll: poll)
                return nil
            } else {
                state = .unauthenticated
                return poll.code ?? "UNKNOWN_ERROR"
            }
        } catch {
            state = .unauthenticated
            return "NETWORK_ERROR"
        }
    }

    // MARK: - Native Login: Magic Link (existing user)

    func sendMagicLink(email: String) async {
        guard let deviceId = deviceFingerprint() else {
            state = .unauthenticated
            return
        }
        state = .validating

        do {
            try await callSendOtp(email: email, deviceId: deviceId)
            state = .authenticating
            startPolling(deviceId: deviceId)
        } catch {
            state = .unauthenticated
        }
    }

    // MARK: - Native Login: Start Trial

    func startTrial(email: String) async -> (success: Bool, errorCode: String?) {
        guard let deviceId = deviceFingerprint() else {
            return (false, "NO_DEVICE")
        }
        state = .validating

        do {
            let result = try await callCreateTrial(email: email, deviceId: deviceId)
            if result.success == true || result.resent == true {
                state = .authenticating
                startPolling(deviceId: deviceId)
                return (true, nil)
            } else {
                state = .unauthenticated
                return (false, result.code)
            }
        } catch {
            state = .unauthenticated
            return (false, "NETWORK_ERROR")
        }
    }

    // MARK: - Poll for token

    private func startPolling(deviceId: String) {
        pollTask?.cancel()
        pollTask = Task {
            let start = Date()
            let deadline = start.addingTimeInterval(5 * 60)
            var attempt = 0

            while !Task.isCancelled && Date() < deadline {
                let delayNs: UInt64 = attempt == 0
                    ? 500_000_000
                    : (Date().timeIntervalSince(start) < 10 ? 1_000_000_000 : 2_000_000_000)
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }
                attempt += 1

                if let result = try? await callPollAppToken(deviceId: deviceId) {
                    if result.pending == true { continue }

                    if result.success == true, let email = result.email {
                        handlePollSuccess(email: email, deviceId: deviceId, poll: result)
                        return
                    } else if result.code == "DEVICE_CONFLICT" {
                        state = .deviceConflict
                        return
                    } else if result.code == "TRIAL_EXPIRED" {
                        state = .trialExpired
                        return
                    }
                }
            }
            // Timed out — leave in .authenticating so user can retry
        }
    }

    private func handlePollSuccess(email: String, deviceId: String, poll: PollResponse) {
        let licenseType = poll.licenseType ?? "paid"
        var trialEndsAt: Date? = nil

        if licenseType == "trial", let trialEndsStr = poll.trialEndsAt {
            trialEndsAt = ISO8601DateFormatter().date(from: trialEndsStr)
        }

        let record = AuthRecord(
            email: email,
            deviceId: deviceId,
            lastValidated: Date(),
            licenseType: licenseType,
            trialEndsAt: trialEndsAt
        )
        saveAuthRecord(record)

        if licenseType == "trial", let ends = trialEndsAt {
            let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: ends).day ?? 0)
            state = .trial(daysLeft: daysLeft)
        } else {
            state = .authenticated
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Handle Deep Link (macharmony://auth?token=<x>)

    func handleDeepLink(_ url: URL) async {
        guard url.scheme == "macharmony",
              url.host == "auth",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              let deviceId = deviceFingerprint()
        else { return }

        switch state {
        case .authenticated, .offlineGrace, .trial:
            stopPolling()
            return
        default:
            break
        }

        stopPolling()
        state = .validating

        do {
            let result = try await callVerifyToken(token: token, deviceId: deviceId)
            if result.success == true, let email = result.email {
                let record = AuthRecord(
                    email: email,
                    deviceId: deviceId,
                    lastValidated: Date(),
                    licenseType: "paid",
                    trialEndsAt: nil
                )
                saveAuthRecord(record)
                state = .authenticated
            } else if result.code == "DEVICE_CONFLICT" {
                state = .deviceConflict
            } else {
                state = .unauthenticated
            }
        } catch {
            state = .unauthenticated
        }
    }

    // MARK: - Validate on Launch

    func validateOnLaunch() async {
        guard let record = loadAuthRecord() else {
            state = .unauthenticated
            return
        }
        state = .validating

        do {
            let result = try await callValidateSession(
                email: record.email,
                deviceId: record.deviceId
            )

            if result.valid || result.rateLimited == true {
                let licenseType = result.licenseType ?? record.licenseType
                var trialEndsAt: Date? = record.trialEndsAt
                if let trialStr = result.trialEndsAt {
                    trialEndsAt = ISO8601DateFormatter().date(from: trialStr)
                }

                let updated = AuthRecord(
                    email: record.email,
                    deviceId: record.deviceId,
                    lastValidated: Date(),
                    licenseType: licenseType,
                    trialEndsAt: trialEndsAt
                )
                saveAuthRecord(updated)

                if licenseType == "trial", let ends = trialEndsAt {
                    let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: ends).day ?? 0)
                    state = .trial(daysLeft: daysLeft)
                } else {
                    state = .authenticated
                }

            } else if result.reason == "trial_expired" {
                deleteAuthRecord()
                state = .trialExpired

            } else if result.reason == "device_mismatch" {
                deleteAuthRecord()
                state = .deviceConflict

            } else {
                deleteAuthRecord()
                state = .unauthenticated
            }
        } catch {
            handleOffline(record: record)
        }
    }

    private func handleOffline(record: AuthRecord) {
        let daysSince = Calendar.current.dateComponents(
            [.day],
            from: record.lastValidated,
            to: Date()
        ).day ?? (gracePeriodDays + 1)

        // Trial users: check if trial itself has expired
        if record.licenseType == "trial", let trialEnds = record.trialEndsAt {
            if trialEnds < Date() {
                deleteAuthRecord()
                state = .trialExpired
                return
            }
            let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEnds).day ?? 0)
            state = .trial(daysLeft: daysLeft)
            return
        }

        if daysSince <= gracePeriodDays {
            state = .offlineGrace(gracePeriodDays - daysSince)
        } else {
            deleteAuthRecord()
            state = .expired
        }
    }

    // MARK: - Sign Out

    func signOut() {
        stopPolling()
        deleteAuthRecord()
        state = .unauthenticated
    }

    // MARK: - Keychain Helpers

    private func keychainQuery() -> [String: Any] {
        [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }

    private func saveAuthRecord(_ record: AuthRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        var query = keychainQuery()
        query[kSecValueData as String] = data
        let updateStatus = SecItemUpdate(
            keychainQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private func loadAuthRecord() -> AuthRecord? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(AuthRecord.self, from: data)
    }

    private func deleteAuthRecord() {
        SecItemDelete(keychainQuery() as CFDictionary)
    }

    // MARK: - API Calls

    private func callVerifyToken(token: String, deviceId: String) async throws -> VerifyResponse {
        let url = URL(string: "\(edgeFunctionBase)/verify-app-token")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["token": token, "device_id": deviceId])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(VerifyResponse.self, from: data)
    }

    private func callPollAppToken(deviceId: String) async throws -> PollResponse {
        var components = URLComponents(string: "\(edgeFunctionBase)/poll-app-token")!
        components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        var req = URLRequest(url: components.url!, timeoutInterval: 8)
        req.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(PollResponse.self, from: data)
    }

    private func callValidateSession(email: String, deviceId: String) async throws -> ValidateResponse {
        let url = URL(string: "\(edgeFunctionBase)/validate-session")!
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email, "device_id": deviceId])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(ValidateResponse.self, from: data)
    }

    private func callPasswordSignIn(email: String, password: String) async throws -> PasswordSignInResponse {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(PasswordSignInResponse.self, from: data)
    }

    private func callSendOtp(email: String, deviceId: String) async throws {
        let deviceName = deviceDisplayName()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Unknown%20Mac"
        let encodedDeviceId = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
        let redirectTo = "\(MacHarmonySite.origin)/app-login/callback?device_id=\(encodedDeviceId)&device_name=\(deviceName)"

        let url = URL(string: "\(supabaseURL)/auth/v1/otp")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        let body: [String: Any] = [
            "email": email,
            "create_user": false,
            "options": ["redirect_to": redirectTo]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    private func callCreateAppToken(accessToken: String, deviceId: String) async throws -> CreateAppTokenResponse {
        let url = URL(string: "\(edgeFunctionBase)/create-app-token")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body: [String: String] = ["device_id": deviceId, "device_name": deviceDisplayName()]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(CreateAppTokenResponse.self, from: data)
    }

    private func callCreateTrial(email: String, deviceId: String) async throws -> CreateTrialResponse {
        let url = URL(string: "\(edgeFunctionBase)/create-trial")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "email": email,
            "device_id": deviceId,
            "device_name": deviceDisplayName()
        ]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(CreateTrialResponse.self, from: data)
    }
}
