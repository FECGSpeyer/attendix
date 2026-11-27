part of 'app_router.dart';

/// Redesign shell routes (Heute, Termine, Mitglieder, Werke, Ich, Verwalten).
List<RouteBase> _redesignShellRoutes(Ref ref) => [
  // REDESIGN: "Heute", "Termine", "Mitglieder", "Werke", "Ich" and "Ich › Darstellung" (Beta)
  GoRoute(
    path: RedesignRoutes.today,
    name: 'redesignToday',
    pageBuilder: (context, state) => AppPageTransitions.none(
      child: const RdTodayPage(),
      state: state,
    ),
  ),
  GoRoute(
    path: RedesignRoutes.events,
    name: 'redesignEvents',
    pageBuilder: (context, state) => AppPageTransitions.none(
      // Wide screens: the next Termin is open next to the list.
      child: rdUseSplit(context) ? const RdEventsSplitHome() : const RdEventsPage(),
      state: state,
    ),
    routes: [
      GoRoute(
        path: 'neu',
        name: 'redesignEventCreate',
        builder: (context, state) => RdEventCreatePage(
          initialDate: state.extra is DateTime ? state.extra as DateTime : null,
        ),
      ),
      GoRoute(
        path: 'meine/:paId',
        name: 'redesignOwnEvent',
        builder: (context, state) => RdOwnEventPage(
          personAttendanceId: state.pathParameters['paId'] ?? '',
        ),
      ),
      GoRoute(
        path: ':id/bearbeiten',
        name: 'redesignEventEdit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null ? const RdEventsPage() : RdEventEditPage(attendanceId: id);
        },
      ),
      GoRoute(
        path: ':id',
        name: 'redesignEvent',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          final detail = id == null
              ? null
              : RdEventPage(
                  key: ValueKey('rd-event-$id'),
                  attendanceId: id,
                  initialTab: state.uri.queryParameters['tab'] == 'anwesenheit'
                      ? RdEventTab.record
                      : RdEventTab.overview,
                );
          // Wide screens: list and Termin side by side; one page
          // for every Termin, so the list keeps its state.
          if (rdUseSplit(context)) {
            return NoTransitionPage<void>(
              key: const ValueKey('rd-events-split'),
              child: RdSplitView(
                list: const RdEventsPage(),
                detail: detail,
                selectedId: id,
                emptyText: context.l10n.redesignSplitEventsEmpty,
              ),
            );
          }
          return MaterialPage<void>(key: state.pageKey, child: detail ?? const RdEventsPage());
        },
      ),
    ],
  ),
  GoRoute(
    path: RedesignRoutes.members,
    name: 'redesignMembers',
    pageBuilder: (context, state) => AppPageTransitions.none(
      child: rdUseSplit(context)
          ? RdSplitView(
              list: const RdMembersPage(),
              detail: null,
              selectedId: null,
              emptyText: context.l10n.redesignSplitMembersEmpty,
              empty: const RdMembersOverviewPanel(),
            )
          : const RdMembersPage(),
      state: state,
    ),
    routes: [
      // Before ':id': "neu" is no person id.
      GoRoute(
        path: 'neu',
        name: 'redesignPersonCreate',
        builder: (context, state) => RdPersonCreatePage(prefill: PersonCreatePrefill.from(state.extra)),
      ),
      // Archiv and "Anfrage prüfen" from the Mitglieder tab stay in
      // the tab (before ':id').
      GoRoute(
        path: 'archiv',
        name: 'redesignMembersArchive',
        builder: (context, state) => const RdArchivePage(fromMembers: true),
      ),
      GoRoute(
        path: 'anfrage/:id',
        name: 'redesignMembersReview',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const RdMembersPage();
          return RdPendingReviewPage(key: ValueKey('rd-members-review-$id'), personId: id, fromMembers: true);
        },
      ),
      GoRoute(
        path: 'problemfaelle',
        name: 'redesignCriticalMembers',
        builder: (context, state) => RdCriticalMembersPage(from: state.uri.queryParameters['von']),
      ),
      GoRoute(
        path: ':id/bearbeiten',
        name: 'redesignPersonEdit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? const RdMembersPage()
              : RdPersonEditPage(key: ValueKey('rd-person-edit-$id'), personId: id);
        },
      ),
      GoRoute(
        path: ':id',
        name: 'redesignPerson',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          final detail = id == null ? null : RdPersonPage(key: ValueKey('rd-person-$id'), personId: id);
          if (rdUseSplit(context)) {
            return NoTransitionPage<void>(
              key: const ValueKey('rd-members-split'),
              child: RdSplitView(
                list: const RdMembersPage(),
                detail: detail,
                selectedId: id,
                emptyText: context.l10n.redesignSplitMembersEmpty,
                empty: const RdMembersOverviewPanel(),
              ),
            );
          }
          return MaterialPage<void>(key: state.pageKey, child: detail ?? const RdMembersPage());
        },
        routes: [
          GoRoute(
            path: 'verlauf',
            name: 'redesignPersonHistory',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return MaterialPage<void>(
                key: state.pageKey,
                child: id == null ? const RdMembersPage() : RdPersonHistoryPage(personId: id),
              );
            },
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: RedesignRoutes.works,
    name: 'redesignWorks',
    pageBuilder: (context, state) => AppPageTransitions.none(
      child: rdUseSplit(context)
          ? RdSplitView(
              list: const RdWorksPage(),
              detail: null,
              selectedId: null,
              emptyText: context.l10n.redesignSplitWorksEmpty,
              emptyIcon: Icons.library_music_outlined,
              empty: const RdWorksOverviewPanel(),
            )
          : const RdWorksPage(),
      state: state,
    ),
    routes: [
      // Before ':id', which would take "import" for a Werk.
      GoRoute(
        path: 'werkliste',
        name: 'redesignWorkListImport',
        builder: (context, state) => const SongImportPage(),
      ),
      GoRoute(
        path: 'import',
        name: 'redesignWorksImport',
        // The browser's back button changes the address without a
        // pop; the page asks before its answers are lost.
        onExit: kIsWeb ? rdImportOnExit : null,
        builder: (context, state) => const RdImportPage(),
      ),
      GoRoute(
        path: 'neu',
        name: 'redesignWorkCreate',
        builder:
            (context, state) =>
                RdWorkCreatePage(collectionId: int.tryParse(state.uri.queryParameters['sammlung'] ?? '')),
      ),
      GoRoute(
        path: 'mappe',
        name: 'redesignFolder',
        builder: (context, state) => const RdFolderPage(),
      ),
      GoRoute(
        path: 'sammlungen',
        name: 'redesignCollections',
        builder: (context, state) => const RdCollectionsPage(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'redesignCollection',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return id == null
                  ? const RdCollectionsPage()
                  : RdCollectionEditPage(key: ValueKey('rd-collection-$id'), collectionId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: ':id/bearbeiten',
        name: 'redesignWorkEdit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? const RdWorksPage()
              : RdWorkEditPage(key: ValueKey('rd-work-edit-$id'), songId: id);
        },
      ),
      GoRoute(
        path: ':id',
        name: 'redesignWork',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          final detail = id == null ? null : RdWorkPage(key: ValueKey('rd-work-$id'), songId: id);
          // Wide screens: list and Werk side by side (files are
          // edited on the right while the list stays).
          if (rdUseSplit(context)) {
            return NoTransitionPage<void>(
              key: const ValueKey('rd-works-split'),
              child: RdSplitView(
                list: const RdWorksPage(),
                detail: detail,
                selectedId: id,
                emptyText: context.l10n.redesignSplitWorksEmpty,
                emptyIcon: Icons.library_music_outlined,
                empty: const RdWorksOverviewPanel(),
              ),
            );
          }
          return MaterialPage<void>(key: state.pageKey, child: detail ?? const RdWorksPage());
        },
      ),
    ],
  ),
  GoRoute(
    path: RedesignRoutes.me,
    name: 'redesignMe',
    pageBuilder: (context, state) => AppPageTransitions.none(
      child: const RdMePage(),
      state: state,
    ),
    routes: [
      GoRoute(
        path: 'darstellung',
        name: 'redesignAppearance',
        builder: (context, state) => const RdAppearancePage(),
      ),
      GoRoute(
        path: 'benachrichtigungen',
        builder: (context, state) => const RdNotificationsPage(),
      ),
      // "Meine Gruppen" keeps the tab bar (same list as /tenants).
      GoRoute(
        path: 'gruppen',
        builder: (context, state) => const TenantSelectionPage(inTab: true),
      ),
      GoRoute(
        path: 'verwaltung',
        name: 'redesignManage',
        // Wide screens: areas on the left, the chosen one on the right.
        builder: (context, state) => rdUseSplit(context) ? const RdManageSplit() : const RdManagePage(),
        routes: [
          // Fixed pages before the `:area` pattern.
          GoRoute(
            path: 'auswertung',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.statistics, const RdStatsPage()),
          ),
          GoRoute(
            path: 'mitteilung',
            builder: (context, state) => const RdMessageComposePage(),
          ),
          // Settings of the old "Allgemein", split by where they act.
          GoRoute(
            path: 'anmeldung',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.registration, const RdGeneralSettingsPage(section: RdTenantSettings.registration)),
          ),
          GoRoute(
            path: 'abmeldegruende',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.reasons, const RdGeneralSettingsPage(section: RdTenantSettings.reasons)),
          ),
          GoRoute(
            path: 'problemfaelle',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.critical, const RdGeneralSettingsPage(section: RdTenantSettings.critical)),
          ),
          GoRoute(
            path: 'feiertage',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.holidays, const RdGeneralSettingsPage(section: RdTenantSettings.holidays)),
          ),
          // Pages that live under /settings too, here so they open next
          // to the list on wide screens.
          GoRoute(
            path: 'name',
            pageBuilder: (context, state) =>
                rdManageRoutePage(context, state, RdManageEntry.general, const RdGeneralSettingsPage()),
          ),
          GoRoute(
            path: 'mitteilungen',
            pageBuilder: (context, state) =>
                rdManageRoutePage(context, state, RdManageEntry.announcements, const RdMessagesPage()),
          ),
          GoRoute(
            path: 'organisation',
            pageBuilder: (context, state) =>
                rdManageRoutePage(context, state, RdManageEntry.organisation, const RdOrgSettingsPage()),
          ),
          // Verwaltungslisten (RedesignRoutes.groups etc.).
          GoRoute(
            path: 'werkhistorie',
            builder: (context, state) => const RdWorkHistoryPage(),
          ),
          GoRoute(
            path: 'werk-kategorien',
            builder: (context, state) => const RdWorkCategoriesPage(),
          ),
          GoRoute(
            path: 'gruppen-kategorien',
            builder: (context, state) => const RdGroupCategoriesPage(),
          ),
          GoRoute(
            path: 'gruppen',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.groups, const RdGroupsPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  return id == null
                      ? const RdGroupsPage()
                      : RdGroupEditPage(key: ValueKey('rd-group-edit-$id'), groupId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'lehrer',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.teachers, const RdTeachersPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  return id == null
                      ? const RdTeachersPage()
                      : RdTeacherEditPage(key: ValueKey('rd-teacher-edit-$id'), teacherId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'zusatzfelder',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.extraFields, const RdExtraFieldsPage()),
            routes: [
              GoRoute(
                path: ':list/:id',
                builder: (context, state) {
                  final list = state.pathParameters['list'];
                  final id = state.pathParameters['id'] ?? '';
                  if ((list != 'personen' && list != 'werke') || id.isEmpty) {
                    return const RdExtraFieldsPage();
                  }
                  return RdExtraFieldEditPage(
                    key: ValueKey('rd-extra-field-edit-$list-$id'),
                    song: list == 'werke',
                    fieldId: id,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'terminarten',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.attendanceTypes, const RdAttendanceTypesPage()),
          ),
          GoRoute(
            path: 'schichtplaene',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.shiftPlans, const RdShiftPlansPage()),
          ),
          GoRoute(
            path: 'rollen',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.rolesPermissions, const RdRolePermissionsPage()),
          ),
          // One role; an unknown segment shows the list. A sibling of
          // the list, not its child: on wide screens both are the
          // one page next to the Verwaltung list (same page key).
          GoRoute(
            path: 'rollen/:role',
            pageBuilder: (context, state) {
              final view = RdRoleView.fromKey(state.pathParameters['role']) ?? RdRoleView.list;
              return rdManageRoutePage(
                context,
                state,
                RdManageEntry.rolesPermissions,
                RdRolePermissionsPage(key: ValueKey('rd-role-${view.name}'), view: view),
              );
            },
          ),
          // Admins, Eltern and Beobachter are rows of Rollen und
          // Rechte: on wide screens that entry stays marked.
          GoRoute(
            path: 'admins',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.rolesPermissions, const RdAdminsPage()),
          ),
          GoRoute(
            path: 'eltern',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.rolesPermissions, const RdParentsPage()),
          ),
          GoRoute(
            path: 'beobachter',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.rolesPermissions, const RdViewersPage()),
          ),
          GoRoute(
            path: 'archiv',
            pageBuilder: (context, state) => rdManageRoutePage(context, state, RdManageEntry.archive, const RdArchivePage()),
          ),
          GoRoute(
            path: 'freigaben',
            builder: (context, state) => RdPendingPage(from: state.uri.queryParameters['von']),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) return const RdPendingPage();
                  return RdPendingReviewPage(key: ValueKey('rd-review-$id'), personId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: ':area',
            pageBuilder: (context, state) {
              final area = RdManageArea.fromKey(state.pathParameters['area']);
              // Old links to a section: the overview next to the list.
              if (rdUseSplit(context)) {
                return const NoTransitionPage<void>(
                  key: ValueKey('rd-manage-split'),
                  child: RdManageSplit(),
                );
              }
              return MaterialPage<void>(key: state.pageKey, child: RdManageAreaPage(area: area));
            },
          ),
        ],
      ),
    ],
  ),
];
