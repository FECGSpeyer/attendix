// Code that reads role, permissions or tenant settings. Shared by the
// extractor (unit.roleMembers, roleGuarded) and parity.mjs verify-round
// (which items depend on role or tenant), so both use the same list.
// `role: 'cancel'` in alert/action sheet buttons is no role check.
export const ROLE_TEXT = /\brole\b(?!\s*:\s*['"`])|\bRole\.|isConductor|isHelper|isAdmin|isPlayer|isViewer|isParent|isApplicant|isVoiceLeader|isResponsible|isTeamLeader|isLeader|isManager|isSuperAdmin|permission|\bperm|tenantData|tenant\(\)\??\.\w|\btenant\.\w|isGeneral|isChoir|isDemo|isMainGroup|hasOrg|organisation\(\)|editableByPlayers/;
