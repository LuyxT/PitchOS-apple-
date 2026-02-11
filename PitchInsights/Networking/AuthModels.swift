import Foundation

struct AuthUserDTO: Codable {
    let id: String
    let email: String
    let organizationId: String?
    let createdAt: Date?
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let passwordConfirmation: String
    let role: String
    let inviteCode: String?
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?
}

struct RegisterResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?
}

struct RefreshRequest: Codable {
    let refreshToken: String
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?
}
