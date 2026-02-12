import Foundation

struct MembershipDTO: Codable {
    let id: String
    let organizationId: String
    let teamId: String?
    let role: String
    let status: String
}

struct OnboardingStateDTO: Codable {
    let completed: Bool
    let completedAt: Date?
    let lastStep: String?
}

struct OnboardingResolveRequest: Codable {
    let role: String
    let region: String
    let clubName: String
    let postalCode: String?
    let city: String?
    let teamName: String?
    let league: String?
    let inviteCode: String?
    let clubId: String?
}

struct OnboardingCandidateDTO: Codable {
    let clubId: String
    let clubName: String
    let city: String?
    let postalCode: String?
    let region: String?
}

struct OnboardingResolveResponse: Codable {
    let mode: String
    let clubId: String?
    let teamId: String?
    let membershipStatus: String?
    let candidates: [OnboardingCandidateDTO]?
    let message: String?
}

struct OnboardingClubDTO: Codable {
    let id: String
    let name: String
    let city: String?
    let region: String?
    let league: String?
    let inviteCode: String?
}

struct OnboardingClubActionResponse: Decodable {
    let success: Bool
    let message: String?
    let onboardingRequired: Bool?
    let nextStep: String?
    let club: OnboardingClubDTO

    enum CodingKeys: String, CodingKey {
        case success
        case club
        case clubExists
        case message
        case onboardingRequired
        case nextStep
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let explicit = try container.decodeIfPresent(Bool.self, forKey: .success) {
            success = explicit
        } else if let exists = try container.decodeIfPresent(Bool.self, forKey: .clubExists) {
            success = exists
        } else {
            success = true
        }
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        onboardingRequired = try? container.decodeIfPresent(Bool.self, forKey: .onboardingRequired)
        nextStep = try? container.decodeIfPresent(String.self, forKey: .nextStep)
        club = try container.decode(OnboardingClubDTO.self, forKey: .club)
    }
}

struct OnboardingJoinClubRequest: Codable {
    let inviteCode: String
}

struct ClubSearchResultDTO: Codable {
    let id: String
    let name: String
    let city: String?
    let postalCode: String?
    let region: String?
}

struct ClubCreateRequest: Codable {
    let name: String
    let region: String
    let city: String
}

struct ClubDTO: Codable {
    let id: String
    let name: String
    let region: String?
    let city: String?
    let postalCode: String?
}

struct ClubJoinRequest: Codable {
    let clubId: String
    let role: String
    let teamId: String?
}

struct ClubJoinResponse: Codable {
    let clubId: String
    let teamId: String?
    let membershipStatus: String?
}

struct TeamCreateRequest: Codable {
    let clubId: String?
    let name: String
    let ageGroup: String
    let league: String
}

struct TeamDTO: Codable {
    let id: String
    let name: String
    let clubId: String?
    let ageGroup: String?
    let league: String?
}
