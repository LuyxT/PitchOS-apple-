import Foundation

struct ProfilePermissionService {
    func permissionSnapshot(
        viewer: PersonProfile?,
        viewerAdminPermissions: Set<AdminPermission>,
        target: PersonProfile
    ) -> ProfilePermissionSnapshot {
        guard let viewer else {
            return ProfilePermissionSnapshot(
                canViewMedicalInternals: false,
                canViewInternalNotes: false,
                canEditCore: false,
                canEditRoles: false,
                canEditSports: false,
                canEditOwnGoalsOnly: false,
                canEditMedical: false,
                canEditResponsibilities: false,
                canDeleteProfile: false
            )
        }

        let isSelf = viewer.id == target.id
        let viewerRoles = Set(viewer.core.roles)
        let targetRoles = Set(target.core.roles)

        let adminCanManagePeople = viewerAdminPermissions.contains(.managePeople)
        let adminCanManageSettings = viewerAdminPermissions.contains(.manageSettings)
        let isHeadCoach = viewerRoles.contains(.headCoach)
        let isTrainerFamily = !viewerRoles.intersection([
            .headCoach, .assistantCoach, .coachingStaff, .athleticCoach, .analyst
        ]).isEmpty
        let isMedical = viewerRoles.contains(.physiotherapist)
        let isManagerial = viewerRoles.contains(.teamManager) || viewerRoles.contains(.boardMember)
        let viewerIsPlayer = viewerRoles.count == 1 && viewerRoles.contains(.player)
        let targetIsPlayer = targetRoles.contains(.player)

        let canViewMedicalInternals = isSelf || isMedical || isHeadCoach || viewerRoles.contains(.assistantCoach) || viewerRoles.contains(.athleticCoach)
        let canViewInternalNotes = isSelf || canViewMedicalInternals || isManagerial || adminCanManagePeople

        let canEditCore = isSelf || adminCanManagePeople || isHeadCoach || isManagerial
        let canEditRoles = adminCanManagePeople || isHeadCoach || adminCanManageSettings

        let canEditSports: Bool
        if targetIsPlayer {
            canEditSports = isHeadCoach || isMedical || viewerRoles.contains(.assistantCoach) || viewerRoles.contains(.athleticCoach) || adminCanManagePeople
        } else {
            canEditSports = isHeadCoach || adminCanManagePeople
        }

        let canEditOwnGoalsOnly = isSelf && targetIsPlayer && viewerIsPlayer
        let canEditMedical = isMedical || isHeadCoach || viewerRoles.contains(.assistantCoach) || adminCanManagePeople
        let canEditResponsibilities = isHeadCoach || isManagerial || adminCanManagePeople || (isSelf && isTrainerFamily)
        let canDeleteProfile = adminCanManagePeople || isHeadCoach

        return ProfilePermissionSnapshot(
            canViewMedicalInternals: canViewMedicalInternals,
            canViewInternalNotes: canViewInternalNotes,
            canEditCore: canEditCore,
            canEditRoles: canEditRoles,
            canEditSports: canEditSports || canEditOwnGoalsOnly,
            canEditOwnGoalsOnly: canEditOwnGoalsOnly,
            canEditMedical: canEditMedical,
            canEditResponsibilities: canEditResponsibilities,
            canDeleteProfile: canDeleteProfile
        )
    }
}
