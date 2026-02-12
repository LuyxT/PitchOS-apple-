import Foundation

struct AuthUserDTO: Codable {
    let id: String
    let email: String
    let role: String?
    let clubId: String?
    let teamId: String?
    let organizationId: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case role
        case clubId
        case teamId
        case organizationId
        case createdAt
    }

    init(
        id: String,
        email: String,
        role: String?,
        clubId: String?,
        teamId: String?,
        organizationId: String?,
        createdAt: Date?
    ) {
        self.id = id
        self.email = email
        self.role = role
        self.clubId = clubId
        self.teamId = teamId
        self.organizationId = organizationId
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        role = try? container.decodeIfPresent(String.self, forKey: .role)
        let directClub = try? container.decodeIfPresent(String.self, forKey: .clubId)
        let org = try? container.decodeIfPresent(String.self, forKey: .organizationId)
        teamId = try? container.decodeIfPresent(String.self, forKey: .teamId)
        clubId = directClub ?? org ?? nil
        organizationId = org ?? directClub ?? nil
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let passwordConfirmation: String
    let role: String
    let inviteCode: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case role
        case inviteCode
    }
}

struct LoginResponse: Codable {
    let success: Bool?
    let token: String?
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let boolSuccess = try? container.decodeIfPresent(Bool.self, forKey: .success) {
            success = boolSuccess
        } else if let stringSuccess = try? container.decodeIfPresent(String.self, forKey: .success) {
            success = stringSuccess.lowercased() == "true"
        } else {
            success = nil
        }
        token = try? container.decodeIfPresent(String.self, forKey: .token)
        let decodedAccess = try? container.decodeIfPresent(String.self, forKey: .accessToken)
        let decodedRefresh = try? container.decodeIfPresent(String.self, forKey: .refreshToken)
        accessToken = decodedAccess ?? token ?? ""
        refreshToken = decodedRefresh ?? token ?? ""
        user = try? container.decodeIfPresent(AuthUserDTO.self, forKey: .user)
    }

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case accessToken
        case refreshToken
        case user
    }
}

struct RegisterResponse: Codable {
    let success: Bool?
    let token: String?
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let boolSuccess = try? container.decodeIfPresent(Bool.self, forKey: .success) {
            success = boolSuccess
        } else if let stringSuccess = try? container.decodeIfPresent(String.self, forKey: .success) {
            success = stringSuccess.lowercased() == "true"
        } else {
            success = nil
        }
        token = try? container.decodeIfPresent(String.self, forKey: .token)
        let decodedAccess = try? container.decodeIfPresent(String.self, forKey: .accessToken)
        let decodedRefresh = try? container.decodeIfPresent(String.self, forKey: .refreshToken)
        accessToken = decodedAccess ?? token ?? ""
        refreshToken = decodedRefresh ?? token ?? ""
        user = try? container.decodeIfPresent(AuthUserDTO.self, forKey: .user)
    }

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case accessToken
        case refreshToken
        case user
    }
}

struct RefreshRequest: Codable {
    let refreshToken: String
}

struct RefreshResponse: Codable {
    let success: Bool?
    let token: String?
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let boolSuccess = try? container.decodeIfPresent(Bool.self, forKey: .success) {
            success = boolSuccess
        } else if let stringSuccess = try? container.decodeIfPresent(String.self, forKey: .success) {
            success = stringSuccess.lowercased() == "true"
        } else {
            success = nil
        }
        token = try? container.decodeIfPresent(String.self, forKey: .token)
        let decodedAccess = try? container.decodeIfPresent(String.self, forKey: .accessToken)
        let decodedRefresh = try? container.decodeIfPresent(String.self, forKey: .refreshToken)
        accessToken = decodedAccess ?? token ?? ""
        refreshToken = decodedRefresh ?? token ?? ""
        user = try? container.decodeIfPresent(AuthUserDTO.self, forKey: .user)
    }

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case accessToken
        case refreshToken
        case user
    }
}
