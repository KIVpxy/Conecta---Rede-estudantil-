import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/signup_page.dart';
import '../features/library/library_page.dart';
import '../features/materials/create_material_page.dart';
import '../features/materials/material_post_page.dart';
import '../features/materials/materials_page.dart';
import '../features/messages/conversation_page.dart';
import '../features/messages/create_group_page.dart';
import '../features/messages/messages_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/profile_page.dart';
import '../features/search/search_page.dart';
import '../features/projects/create_project_page.dart';
import '../features/projects/edit_project_page.dart';
import '../features/projects/discover_page.dart';
import '../features/projects/project_detail_page.dart';
import '../features/ranking/ranking_page.dart';
import '../features/school/school_page.dart';
import '../features/status/status_page.dart';
import 'app_shell.dart';
import 'auth_state.dart';

/// Rotas do MVP (ver SPEC.md seção 7).
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/status',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.loggedIn;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!loggedIn && !goingToAuth) return '/login';
      if (loggedIn && goingToAuth) return '/status';
      if (state.matchedLocation == '/') return '/status';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/signup', builder: (_, _) => const SignUpPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/status', builder: (_, _) => const StatusPage()),
          GoRoute(
              path: '/projetos', builder: (_, _) => const DiscoverPage()),
          GoRoute(path: '/escola', builder: (_, _) => const SchoolPage()),
          GoRoute(
              path: '/materiais',
              builder: (_, _) => const MaterialsPage()),
          GoRoute(
              path: '/materiais/novo',
              builder: (_, _) => const CreateMaterialPage()),
          GoRoute(
            path: '/materiais/:id',
            builder: (_, state) =>
                MaterialPostPage(postId: state.pathParameters['id']!),
          ),
          GoRoute(
              path: '/mensagens',
              builder: (_, _) => const MessagesPage()),
          GoRoute(
              path: '/biblioteca',
              builder: (_, _) => const LibraryPage()),
          GoRoute(
              path: '/mensagens/novo-grupo',
              builder: (_, _) => const CreateGroupPage()),
          GoRoute(
            path: '/mensagens/:id',
            builder: (_, state) => ConversationPage(
                conversationId: state.pathParameters['id']!),
          ),
          GoRoute(
              path: '/editar-perfil',
              builder: (_, _) => const EditProfilePage()),
          GoRoute(
              path: '/pesquisa',
              builder: (_, state) =>
                  SearchPage(initialQuery: state.uri.queryParameters['q'] ?? ''),
          ),
          GoRoute(
              path: '/projetos/novo',
              builder: (_, _) => const CreateProjectPage()),
          GoRoute(
            path: '/projetos/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/projetos/:id/editar',
            builder: (_, state) =>
                EditProjectPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(
              path: '/ranking', builder: (_, _) => const RankingPage()),
          GoRoute(
            path: '/perfil/:username',
            builder: (_, state) =>
                ProfilePage(username: state.pathParameters['username']!),
          ),
        ],
      ),
    ],
  );
});
