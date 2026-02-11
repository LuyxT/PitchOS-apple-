import Foundation

struct RegisterRequest: Codable {
    let email: String
    let password: String
}

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
    let city: String?
    let postalCode: String?
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
    let clubId: String
    let teamName: String
    let league: String?
}

struct TeamDTO: Codable {
    let id: String
    let name: String
    let organizationId: String?
}
