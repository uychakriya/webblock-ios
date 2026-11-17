import Foundation

/// RFC 9457 problem details, the union of the five services' shapes (Android `ProblemDto`).
private struct ApiProblem: Decodable {
    var type: String?
    var title: String?
    var status: Int?
    var detail: String?
    var code: String?
    var requestId: String?
    var fieldErrors: [String: [String]]?
    var errors: [FieldError]?

    struct FieldError: Decodable {
        var field: String?
        var code: String?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        status = try? c.decodeIfPresent(Int.self, forKey: .status)
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
        code = try? c.decodeIfPresent(String.self, forKey: .code)
        requestId = try? c.decodeIfPresent(String.self, forKey: .requestId)
        fieldErrors = try? c.decodeIfPresent([String: [String]].self, forKey: .fieldErrors)
        errors = try? c.decodeIfPresent([FieldError].self, forKey: .errors)
    }

    private enum Keys: String, CodingKey { case type, title, status, detail, code, requestId, fieldErrors, errors }
}

/// A v2 answer that is not 2xx. `code` is always kebab-case: the end of `type`
/// (`urn:webblock:problem:<code>`), else Project's UPPER_SNAKE `code` converted, else `http-<status>`.
struct ApiException: Error, LocalizedError, Sendable {
    let status: Int
    let code: String
    let title: String?
    let detail: String?
    let requestId: String?
    /// Seconds from `Retry-After` (only `otp-resend-too-soon` sends it).
    let retryAfterSeconds: Int?
    let fieldErrors: [String: [String]]

    var errorDescription: String? { ApiMessages.forProblem(self) }

    private static let typePrefix = "urn:webblock:problem:"

    static func parse(status: Int, body: Data?, retryAfter: String?, requestIdHeader: String?) -> ApiException {
        // A body that is not a problem (an HTML error page from the edge) leaves only the status.
        let problem = body.flatMap { $0.isEmpty ? nil : try? JSONDecoder().decode(ApiProblem.self, from: $0) }
        var fields = problem?.fieldErrors ?? [:]
        if fields.isEmpty, let errors = problem?.errors {
            for error in errors {
                guard let field = error.field else { continue }
                fields[field, default: []].append(error.code ?? "")
            }
        }
        return ApiException(
            status: status,
            code: codeOf(problem) ?? "http-\(status)",
            title: problem?.title,
            detail: problem?.detail,
            requestId: requestIdHeader ?? problem?.requestId,
            retryAfterSeconds: retryAfter.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) },
            fieldErrors: fields
        )
    }

    private static func codeOf(_ problem: ApiProblem?) -> String? {
        let fromType = problem?.type.flatMap { $0.hasPrefix(typePrefix) ? String($0.dropFirst(typePrefix.count)) : nil }
        let fromCode = problem?.code?.lowercased().replacingOccurrences(of: "_", with: "-")
        let value = fromType ?? fromCode
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// Plain sentences for the problem codes the owner can act on (same wording as Android `ApiMessages`).
enum ApiMessages {
    static let noConnection = "No internet connection."
    static let unexpectedAnswer = "The server sent an answer the app doesn't understand. Please try again later."
    static let generic = "Something went wrong. Please try again."
    static let changedElsewhere = "This product was changed somewhere else. Pull to refresh, then try again."

    private static let byCode: [String: String] = [
        "invalid-credentials": "The email or password is wrong.",
        "session-expired": "Your session has ended. Please sign in again.",
        "account-suspended": "This account is suspended. Contact WebBlock support.",
        "account-not-found": "Create your account on the WebBlock website first, then sign in here.",
        "sign-in-code-invalid": "Google sign-in didn't finish. Try again.",
        "account-email-in-use": "This email already has a WebBlock account. Sign in with its email and password.",
        "otp-too-many-attempts": "Too many wrong codes. Ask for a new code and try again.",
        "otp-invalid": "That code isn't right. Try again.",
        "otp-expired": "That code has expired. Ask for a new one.",
        "verification-token-invalid": "The reset has expired. Start again.",
        "password-too-weak": "Use 8 or more characters, with an upper case letter, a lower case letter and a digit.",
        "storage-limit-reached": "Your website's photo storage is full. Remove photos on the WebBlock website, then try again.",
        "photo-limit-reached": "Your plan's photo limit is reached. Remove a photo or upgrade your plan on the WebBlock website.",
    ]

    static func forProblem(_ error: ApiException) -> String {
        if error.code == "otp-resend-too-soon" {
            return "Wait \(waitText(error.retryAfterSeconds)) before asking for a new code."
        }
        if let text = byCode[error.code] { return text }
        if let text = fieldMessage(error.fieldErrors) { return text }
        if let detail = error.detail, !detail.trimmingCharacters(in: .whitespaces).isEmpty { return detail }
        if let title = error.title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return forStatus(error.status)
    }

    /// The server's field codes in plain words, e.g. `description: FIELD_LENGTH_INVALID`.
    private static let fieldNames: [String: String] = [
        "name": "Product name", "description": "Description", "price": "Price", "category": "Category",
        "imageUrl": "Photo", "phone": "Phone", "email": "Email", "address": "Address", "mapsUrl": "Maps link",
        "hours": "Opening hours", "password": "Password",
    ]
    private static let lengthRules: [String: String] = [
        "name": "Product name must be 2 to 120 characters.",
        "description": "Description must be 10 to 300 characters, or left empty.",
    ]

    private static func fieldMessage(_ fields: [String: [String]]) -> String? {
        guard let (field, codes) = fields.sorted(by: { $0.key < $1.key }).first else { return nil }
        let code = codes.first ?? ""
        let name = fieldNames[field] ?? field.prefix(1).uppercased() + field.dropFirst()
        switch code {
        case "FIELD_LENGTH_INVALID": return lengthRules[field] ?? "\(name) is too short or too long."
        case "VALUE_INVALID", "FIELD_INVALID": return "\(name) isn’t valid. Check it and try again."
        case "FIELD_REQUIRED", "NotBlank", "NotNull": return "\(name) is required."
        default:
            // User and Notification send readable sentences instead of codes.
            return code.contains(" ") ? code : "Check \(name.lowercased()) and try again."
        }
    }

    private static func waitText(_ seconds: Int?) -> String {
        guard let seconds else { return "a minute" }
        return seconds == 1 ? "1 second" : "\(seconds) seconds"
    }

    private static func forStatus(_ status: Int) -> String {
        switch status {
        case 401: return "Please sign in again."
        case 403: return "You don't have permission to do this."
        case 404: return "Not found."
        case 500...: return "Server error. Please try again later."
        default: return generic
        }
    }
}
