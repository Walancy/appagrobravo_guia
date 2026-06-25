import 'package:go_router/go_router.dart';
import 'package:agrobravo/features/auth/presentation/pages/login_page.dart';
import 'package:agrobravo/features/home/presentation/pages/home_page.dart';
import 'package:agrobravo/features/home/presentation/pages/create_post_page.dart';
import 'package:agrobravo/features/home/domain/entities/post_entity.dart';
import 'package:agrobravo/features/itinerary/presentation/pages/itinerary_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/user_feed_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/connections_page.dart';
import 'package:agrobravo/features/notifications/presentation/pages/notifications_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/settings_page.dart';
import 'package:agrobravo/features/documents/presentation/pages/documents_page.dart';
import 'package:agrobravo/features/documents/presentation/pages/document_details_page.dart';
import 'package:agrobravo/features/documents/presentation/pages/document_history_page.dart';
import 'package:agrobravo/features/documents/domain/entities/document_enums.dart';
import 'package:agrobravo/features/documents/domain/entities/document_entity.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/chat/domain/entities/chat_entity.dart';
import 'package:agrobravo/features/chat/presentation/pages/individual_chat_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/food_preferences_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/medical_restrictions_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/notification_preferences_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/account_data_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/privacy_policy_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/about_us_page.dart';
import 'package:agrobravo/features/profile/presentation/pages/profile_tab.dart';
import 'package:agrobravo/features/home/presentation/pages/member_details_page.dart';
import 'package:agrobravo/features/home/presentation/pages/incident_list_page.dart';
import 'package:agrobravo/features/home/presentation/pages/expense_list_page.dart';
import 'package:agrobravo/features/auth/presentation/widgets/auth_mode.dart';
import 'package:agrobravo/features/notifications/presentation/pages/lembretes_historico_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_state.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  StreamSubscription<dynamic>? _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscribe(stream);
  }

  void _subscribe(Stream<dynamic> stream) {
    _subscription?.cancel();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  void updateStream(Stream<dynamic> newStream) {
    _subscribe(newStream);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final routerRefreshStream = GoRouterRefreshStream(getIt<AuthCubit>().stream);

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: routerRefreshStream,
  redirect: (context, state) {
    final authState = getIt<AuthCubit>().state;

    // Rota atual é pública (login ou esqueci senha / redefinir)
    final isPublicRoute = state.matchedLocation == '/' ||
                        state.matchedLocation == '/reset-password';

    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    // Se estiver carregando, mantém a rota atual
    final isLoading = authState.maybeWhen(
      loading: () => true,
      orElse: () => false,
    );
    if (isLoading) return null;

    if (isAuthenticated) {
      // Se o usuário estiver logado e cair em páginas públicas, manda para a home
      if (isPublicRoute) {
        return '/home';
      }
    } else {
      // Se não estiver logado e cair em qualquer outra tela (restrita), manda para o login (/)
      if (!isPublicRoute) {
        return '/';
      }
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/',
      pageBuilder:
          (context, state) => const NoTransitionPage(child: LoginPage()),
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder:
          (context, state) => const NoTransitionPage(
            child: LoginPage(initialAuthMode: AuthMode.resetPassword),
          ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
        final groupId = state.uri.queryParameters['groupId'];
        return NoTransitionPage(
          child: HomePage(
            key: ValueKey(state.uri.toString()),
            initialTab: tab,
            initialGroupId: groupId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/create-post',
      pageBuilder: (context, state) {
        final extra = state.extra;
        List<dynamic> images = [];
        PostEntity? postToEdit;

        if (extra is List) {
          images = extra;
        } else if (extra is Map<String, dynamic>) {
          images = (extra['initialImages'] as List?) ?? [];
          postToEdit = extra['postToEdit'] as PostEntity?;
        }

        return NoTransitionPage(
          child: CreatePostPage(initialImages: images, postToEdit: postToEdit),
        );
      },
    ),
    GoRoute(
      path: '/itinerary/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return NoTransitionPage(child: ItineraryPage(groupId: groupId));
      },
    ),
    GoRoute(
      path: '/user-feed/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final postId = state.uri.queryParameters['postId'];
        return NoTransitionPage(
          child: UserFeedPage(userId: userId, initialPostId: postId),
        );
      },
    ),
    GoRoute(
      path: '/connections/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final initialIndex =
            int.tryParse(state.uri.queryParameters['initialIndex'] ?? '0') ?? 0;
        return NoTransitionPage(
          child: ConnectionsPage(userId: userId, initialIndex: initialIndex),
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder:
          (context, state) =>
              const NoTransitionPage(child: NotificationsPage()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder:
          (context, state) => const NoTransitionPage(child: SettingsPage()),
    ),
    GoRoute(
      path: '/documents',
      pageBuilder:
          (context, state) => const NoTransitionPage(child: DocumentsPage()),
    ),
    GoRoute(
      path: '/food-preferences',
      pageBuilder:
          (context, state) =>
              const NoTransitionPage(child: FoodPreferencesPage()),
    ),
    GoRoute(
      path: '/medical-restrictions',
      pageBuilder:
          (context, state) =>
              const NoTransitionPage(child: MedicalRestrictionsPage()),
    ),
    GoRoute(
      path: '/notification-preferences',
      pageBuilder:
          (context, state) =>
              const NoTransitionPage(child: NotificationPreferencesPage()),
    ),
    GoRoute(
      path: '/document-details',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return NoTransitionPage(
          child: DocumentDetailsPage(
            type: extra['type'] as DocumentType,
            currentDocument: extra['document'] as DocumentEntity?,
            cubit: extra['cubit'] as DocumentsCubit?,
          ),
        );
      },
    ),
    GoRoute(
      path: '/document-history',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return NoTransitionPage(
          child: DocumentHistoryPage(
            type: extra['type'] as DocumentType,
            cubit: extra['cubit'] as DocumentsCubit,
          ),
        );
      },
    ),
    GoRoute(
      path: '/account-data',
      pageBuilder:
          (context, state) => const NoTransitionPage(child: AccountDataPage()),
    ),
    GoRoute(
      path: '/privacy-policy',
      pageBuilder:
          (context, state) =>
              const NoTransitionPage(child: PrivacyPolicyPage()),
    ),
    GoRoute(
      path: '/profile/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId'];
        return NoTransitionPage(child: ProfileTab(userId: userId));
      },
    ),
    GoRoute(
      path: '/about-us',
      pageBuilder:
          (context, state) => const NoTransitionPage(child: AboutUsPage()),
    ),
    GoRoute(
      path: '/member-details',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return NoTransitionPage(child: MemberDetailsPage(memberData: extra));
      },
    ),
    GoRoute(
      path: '/chat/dm/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final guide = GuideEntity(
          id: userId,
          name: extra['name'] as String? ?? 'Usuário',
          role: extra['role'] as String? ?? '',
          avatarUrl: extra['avatarUrl'] as String?,
        );
        return NoTransitionPage(child: IndividualChatPage(guide: guide));
      },
    ),
    GoRoute(
      path: '/incident-list/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return NoTransitionPage(child: IncidentListPage(groupId: groupId));
      },
    ),
    GoRoute(
      path: '/expense-list/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return NoTransitionPage(child: ExpenseListPage(groupId: groupId));
      },
    ),
    GoRoute(
      path: '/lembretes-historico/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return NoTransitionPage(
          child: LembretesHistoricoPage(groupId: groupId),
        );
      },
    ),
  ],
);
