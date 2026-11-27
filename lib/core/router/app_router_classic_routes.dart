part of 'app_router.dart';

/// Classic and shared feature routes inside the main [ShellRoute].
List<RouteBase> _classicShellRoutes(Ref ref) => [
  // Members (for players/helpers when showMembersList is enabled)
  GoRoute(
    path: '/members',
    name: 'members',
    pageBuilder: (context, state) => AppPageTransitions.none(
      child: const RdMembersPage(),
      state: state,
    ),
  ),

  // Parents Portal (for parents to manage children's attendance)
  GoRoute(
    path: '/parents',
    name: 'parentsPortal',
    pageBuilder: (context, state) => AppPageTransitions.none(
      child: const RdEventsPage(),
      state: state,
    ),
  ),

  // Planning
  GoRoute(
    path: '/planning',
    name: 'planning',
    builder: (context, state) {
      final attendanceId = int.tryParse(
        state.uri.queryParameters['attendanceId'] ?? '',
      );
      // ORG_PLANS: open a specific plan of a Termin with several plans
      // SOL_FIX22: negative / invalid values are reset to null (first plan)
      final rawPlan = int.tryParse(state.uri.queryParameters['plan'] ?? '');
      final planIndex = rawPlan != null && rawPlan >= 0 ? rawPlan : null;
      return PlanningPage(attendanceId: attendanceId, initialPlanIndex: planIndex);
    },
  ),

  // Export
  GoRoute(
    path: '/export',
    name: 'export',
    builder: (context, state) => const RdExportPage(),
  ),

  // Settings
  // MESSAGES: Mitteilung detail (recipients + admins, Ionic /tabs/messages/:id)
  GoRoute(
    path: '/messages/:id',
    name: 'messageDetail',
    builder: (context, state) =>
        MessageDetailPage(messageId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '/settings',
    name: 'settings',
    redirect: (context, state) =>
        state.uri.path == '/settings' ? RedesignRoutes.me : null,
    routes: [
      // MESSAGES: Mitteilungen list (admins/responsibles, Ionic /tabs/settings/messages)
      GoRoute(
        path: 'messages',
        name: 'messages',
        builder: (context, state) => const RdMessagesPage(),
      ),
      // AUTO_MESSAGES (Ionic 4.18): /tabs/settings/auto-messages(/:id)
      GoRoute(
        path: 'auto-messages',
        name: 'autoMessages',
        builder: (context, state) => const AutoMessageListPage(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'autoMessageRule',
            builder: (context, state) => AutoMessageRulePage(
              ruleId: state.pathParameters['id'] ?? 'new',
              template: state.uri.queryParameters['template'],
              initialTab: state.uri.queryParameters['tab'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'team-organization',
        name: 'teamOrganization',
        builder: (context, state) => RdTeamPage(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: 'team-organization/topics',
        name: 'teamTopics',
        builder: (context, state) => const RdTeamTopicsPage(),
      ),
      GoRoute(
        path: 'team-organization/meeting/:attendanceId',
        name: 'teamMeeting',
        redirect: (context, state) =>
            int.tryParse(state.pathParameters['attendanceId'] ?? '') == null
                ? '/settings/team-organization'
                : null,
        builder: (context, state) =>
            RdMeetingPage(attendanceId: int.parse(state.pathParameters['attendanceId']!)),
      ),
      GoRoute(
        path: 'tasks/:id',
        name: 'taskDetail',
        builder: (context, state) => TaskDetailPage(taskId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: 'agenda-items/:id',
        name: 'agendaItemDetail',
        builder: (context, state) => AgendaItemDetailPage(itemId: state.pathParameters['id'] ?? 'new'),
      ),
      GoRoute(
        path: 'protocol/:attendanceId',
        name: 'protocol',
        redirect: (context, state) =>
            int.tryParse(state.pathParameters['attendanceId'] ?? '') == null
                ? '/settings/team-organization'
                : null,
        builder: (context, state) => ProtocolPage(
          attendanceId: int.parse(state.pathParameters['attendanceId']!),
        ),
      ),
      GoRoute(
        path: 'notifications',
        name: 'notifications',
        builder: (context, state) => const RdNotificationsPage(),
      ),
      GoRoute(
        path: 'general',
        name: 'general',
        builder: (context, state) => const RdGeneralSettingsPage(),
      ),
      GoRoute(
        path: 'types',
        name: 'attendanceTypes',
        redirect: (context, state) =>
            state.uri.path == '/settings/types' ? RedesignRoutes.attendanceTypes : null,
        routes: [
          GoRoute(
            path: ':id',
            name: 'attendanceTypeEdit',
            builder: (context, state) => AttendanceTypeEditPage(
              typeId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'voice-leader',
        name: 'voiceLeader',
        builder: (context, state) => const RdVoiceLeaderPage(),
      ),
      GoRoute(
        path: 'shifts',
        name: 'shifts',
        redirect: (context, state) =>
            state.uri.path == '/settings/shifts' ? RedesignRoutes.shiftPlans : null,
        routes: [
          GoRoute(
            path: ':id',
            name: 'shiftDetail',
            builder: (context, state) => ShiftDetailPage(
              shiftId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ),
      // ORG_PLANS: Ablaufplanung, Org-Pläne & Organisation
      GoRoute(
        path: 'planung',
        name: 'adHocPlanning',
        builder: (context, state) => const PublicPlanningPage(inApp: true),
      ),
      GoRoute(
        path: 'org-plans',
        name: 'orgPlans',
        builder: (context, state) => const OrgPlansPage(),
        routes: [
          GoRoute(
            path: 'planung',
            name: 'orgPlansPlanning',
            builder: (context, state) => const PublicPlanningPage(inApp: true, fromOrgPlans: true),
          ),
        ],
      ),
      GoRoute(
        path: 'org-settings',
        name: 'orgSettings',
        builder: (context, state) => const RdOrgSettingsPage(),
        routes: [
          GoRoute(
            path: 'planning-templates',
            name: 'orgPlanningTemplates',
            builder: (context, state) => const OrgPlanningTemplatesPage(),
          ),
          GoRoute(
            path: 'person-fields',
            name: 'orgPersonFields',
            builder: (context, state) => const RdOrgPersonFieldsPage(),
          ),
          // Ionic 4.17.13: Werke in der Organisation suchen (?q=)
          GoRoute(
            path: 'songs',
            name: 'orgSongs',
            builder: (context, state) => RdOrgSongsPage(
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
        ],
      ),
      // ORG_PLANS end
      // Chat-Assistent
      GoRoute(
        path: 'assistant',
        name: 'assistant',
        builder: (context, state) => const AssistantPage(),
      ),
      // LEGAL_HELP: help center + account deletion
      GoRoute(
        path: 'help',
        name: 'help',
        builder: (context, state) => const RdHelpPage(),
        routes: [
          GoRoute(
            path: 'article/:id',
            name: 'helpArticle',
            builder: (context, state) => RdHelpArticlePage(
              articleId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: 'glossary',
            name: 'helpGlossary',
            builder: (context, state) => const RdHelpGlossaryPage(),
          ),
        ],
      ),
      GoRoute(
        path: 'delete-account',
        name: 'deleteAccount',
        builder: (context, state) => const DeleteAccountPage(),
      ),
      GoRoute(
        path: 'files',
        name: 'files',
        builder: (context, state) => FilesPage(
          initialPath: state.uri.queryParameters['path'],
          openFileName: state.uri.queryParameters['open'],
        ),
      ),
      GoRoute(
        path: 'general/branding',
        name: 'branding',
        builder: (context, state) => const RdBrandingPage(),
      ),
      GoRoute(
        path: 'general/link-persons',
        name: 'linkPersons',
        builder: (context, state) => const RdLinkPersonsPage(),
      ),
      // END SETTINGS_EXT
      GoRoute(
        path: 'administration',
        name: 'administration',
        // Ionic SuperDeveloperGuard
        redirect: (context, state) =>
            ref.read(isSuperDeveloperProvider) ? null : RedesignRoutes.me,
        builder: (context, state) => const AdministrationPage(),
      ),
      // PEOPLE_IMPORT: Personenübergabe (Ionic settings/handover)
      GoRoute(
        path: 'handover',
        name: 'handover',
        builder: (context, state) => const RdHandoverPage(),
        routes: [
          GoRoute(
            path: 'detail',
            name: 'handoverDetail',
            builder: (context, state) {
              final data = state.extra is HandoverData ? state.extra as HandoverData : null;
              return RdHandoverDetailPage(data: data);
            },
          ),
        ],
      ),
    ],
  ),

  // DASHBOARD: usage analytics (Ionic /tabs/dashboard, SuperDeveloperGuard)
  GoRoute(
    path: '/dashboard',
    name: 'usageDashboard',
    redirect: (context, state) =>
        ref.read(isSuperDeveloperProvider) ? null : RedesignRoutes.me,
    builder: (context, state) => const UsageDashboardPage(),
  ),
];
