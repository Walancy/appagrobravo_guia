import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrobravo/core/router/app_router.dart';
import 'package:agrobravo/features/auth/presentation/pages/login_page.dart';
import 'package:agrobravo/features/auth/presentation/widgets/auth_mode.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:agrobravo/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/auth/domain/entities/user_entity.dart';
import 'package:agrobravo/features/home/presentation/pages/home_page.dart';
import 'package:agrobravo/core/cubits/theme_cubit.dart';
import 'package:agrobravo/core/cubits/language_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:agrobravo/features/itinerary/presentation/cubit/itinerary_cubit.dart';
import 'package:agrobravo/core/cubits/global_alert_cubit.dart';
import 'package:agrobravo/features/home/presentation/cubit/feed_cubit.dart';
import 'package:agrobravo/features/home/presentation/cubit/feed_state.dart';
import 'package:agrobravo/features/home/presentation/cubit/guide_home_cubit.dart';
import 'package:agrobravo/features/home/domain/repositories/feed_repository.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_state.dart';
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockAuthCubit extends Mock implements AuthCubit {}
class MockThemeCubit extends Mock implements ThemeCubit {}
class MockLanguageCubit extends Mock implements LanguageCubit {}
class MockDocumentsCubit extends Mock implements DocumentsCubit {}
class MockNotificationsCubit extends Mock implements NotificationsCubit {}
class MockItineraryCubit extends Mock implements ItineraryCubit {}
class MockGlobalAlertCubit extends Mock implements GlobalAlertCubit {}
class MockFeedCubit extends Mock implements FeedCubit {}
class MockGuideHomeCubit extends Mock implements GuideHomeCubit {}
class MockFeedRepository extends Mock implements FeedRepository {}
class MockProfileCubit extends Mock implements ProfileCubit {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockAuthCubit mockAuthCubit;
  late MockThemeCubit mockThemeCubit;
  late MockLanguageCubit mockLanguageCubit;
  late MockDocumentsCubit mockDocumentsCubit;
  late MockNotificationsCubit mockNotificationsCubit;
  late MockItineraryCubit mockItineraryCubit;
  late MockGlobalAlertCubit mockGlobalAlertCubit;
  late MockFeedCubit mockFeedCubit;
  late MockGuideHomeCubit mockGuideHomeCubit;
  late MockFeedRepository mockFeedRepository;
  late MockProfileCubit mockProfileCubit;

  setUp(() {
    getIt.allowReassignment = true;
    mockAuthRepository = MockAuthRepository();
    mockAuthCubit = MockAuthCubit();
    mockThemeCubit = MockThemeCubit();
    mockLanguageCubit = MockLanguageCubit();
    mockDocumentsCubit = MockDocumentsCubit();
    mockNotificationsCubit = MockNotificationsCubit();
    mockItineraryCubit = MockItineraryCubit();
    mockGlobalAlertCubit = MockGlobalAlertCubit();
    mockFeedCubit = MockFeedCubit();
    mockGuideHomeCubit = MockGuideHomeCubit();
    mockFeedRepository = MockFeedRepository();
    mockProfileCubit = MockProfileCubit();

    getIt.registerSingleton<AuthCubit>(mockAuthCubit);
    getIt.registerSingleton<ThemeCubit>(mockThemeCubit);
    getIt.registerSingleton<LanguageCubit>(mockLanguageCubit);
    getIt.registerSingleton<DocumentsCubit>(mockDocumentsCubit);
    getIt.registerSingleton<NotificationsCubit>(mockNotificationsCubit);
    getIt.registerSingleton<ItineraryCubit>(mockItineraryCubit);
    getIt.registerSingleton<GlobalAlertCubit>(mockGlobalAlertCubit);
    getIt.registerSingleton<FeedCubit>(mockFeedCubit);
    getIt.registerSingleton<GuideHomeCubit>(mockGuideHomeCubit);
    // A home usa IndexedStack: CommunityTab (FeedRepository) e a aba Meus Dados
    // (ProfileCubit) montam junto com as demais abas.
    getIt.registerSingleton<FeedRepository>(mockFeedRepository);
    getIt.registerFactory<ProfileCubit>(() => mockProfileCubit);

    when(() => mockAuthRepository.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    
    when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
    routerRefreshStream.updateStream(mockAuthCubit.stream);

    // Stub states & streams
    when(() => mockThemeCubit.state).thenReturn(ThemeMode.system);
    when(() => mockThemeCubit.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockLanguageCubit.state).thenReturn(const Locale('pt'));
    when(() => mockLanguageCubit.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockDocumentsCubit.state).thenReturn(const DocumentsState.initial());
    when(() => mockDocumentsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockDocumentsCubit.loadDocuments()).thenAnswer((_) async {});

    when(() => mockNotificationsCubit.state).thenReturn(const NotificationsState.initial());
    when(() => mockNotificationsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockNotificationsCubit.loadNotifications()).thenAnswer((_) async {});

    when(() => mockItineraryCubit.state).thenReturn(const ItineraryState.initial());
    when(() => mockItineraryCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockItineraryCubit.loadUserItinerary()).thenAnswer((_) async {});

    when(() => mockGlobalAlertCubit.state).thenReturn(false);
    when(() => mockGlobalAlertCubit.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockFeedCubit.state).thenReturn(const FeedState.initial());
    when(() => mockFeedCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockFeedCubit.loadFeed()).thenAnswer((_) async {});

    when(() => mockGuideHomeCubit.state).thenReturn(const GuideHomeState.initial());
    when(() => mockGuideHomeCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockGuideHomeCubit.loadMissions()).thenAnswer((_) async {});

    when(() => mockFeedRepository.getCurrentUserId()).thenReturn('test-user-id');

    // Estado loaded (e não initial) para evitar o SettingsShimmer, cuja animação
    // infinita dentro do IndexedStack faz o pumpAndSettle estourar timeout.
    const fakeProfile = ProfileEntity(
      id: 'test-user-id',
      name: 'Guia Teste',
      avatarUrl: null,
      coverUrl: null,
      jobTitle: null,
      bio: null,
      missionName: null,
      email: null,
      phone: null,
      cpf: null,
      ssn: null,
      zipCode: null,
      state: null,
      city: null,
      street: null,
      number: null,
      neighborhood: null,
      complement: null,
      birthDate: null,
      nationality: null,
      passport: null,
      foodPreferences: null,
      medicalRestrictions: null,
      connectionsCount: 0,
      postsCount: 0,
      missionsCount: 0,
      isGuide: true,
    );
    when(() => mockProfileCubit.state).thenReturn(
      const ProfileState.loaded(profile: fakeProfile, posts: [], isMe: true),
    );
    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockProfileCubit.loadProfile()).thenAnswer((_) async {});

    // Stub close methods for all cubits to prevent Null type errors when widgets are unmounted
    when(() => mockAuthCubit.close()).thenAnswer((_) async {});
    when(() => mockThemeCubit.close()).thenAnswer((_) async {});
    when(() => mockLanguageCubit.close()).thenAnswer((_) async {});
    when(() => mockDocumentsCubit.close()).thenAnswer((_) async {});
    when(() => mockNotificationsCubit.close()).thenAnswer((_) async {});
    when(() => mockItineraryCubit.close()).thenAnswer((_) async {});
    when(() => mockGlobalAlertCubit.close()).thenAnswer((_) async {});
    when(() => mockFeedCubit.close()).thenAnswer((_) async {});
    when(() => mockGuideHomeCubit.close()).thenAnswer((_) async {});
    when(() => mockProfileCubit.close()).thenAnswer((_) async {});
  });

  Widget buildTestWidget({required Widget child}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: mockAuthCubit),
        BlocProvider<ThemeCubit>.value(value: mockThemeCubit),
        BlocProvider<LanguageCubit>.value(value: mockLanguageCubit),
        BlocProvider<DocumentsCubit>.value(value: mockDocumentsCubit),
        BlocProvider<NotificationsCubit>.value(value: mockNotificationsCubit),
        BlocProvider<ItineraryCubit>.value(value: mockItineraryCubit),
        BlocProvider<GlobalAlertCubit>.value(value: mockGlobalAlertCubit),
        BlocProvider<FeedCubit>.value(value: mockFeedCubit),
        BlocProvider<GuideHomeCubit>.value(value: mockGuideHomeCubit),
      ],
      child: child,
    );
  }

  testWidgets(
    'Deve exibir a tela de Nova Senha ao acessar a rota /reset-password',
    (WidgetTester tester) async {
      when(() => mockAuthCubit.state).thenReturn(const AuthState.initial());
      when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());

      appRouter.go('/reset-password');

      await tester.pumpWidget(
        buildTestWidget(
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Nova senha:'), findsOneWidget);
    },
  );

  testWidgets(
    'Deve redirecionar para Nova Senha quando o AuthCubit emitir passwordRecovery',
    (WidgetTester tester) async {
      final stateController = StreamController<AuthState>.broadcast();
      when(() => mockAuthCubit.state).thenReturn(const AuthState.initial());
      when(
        () => mockAuthCubit.stream,
      ).thenAnswer((_) => stateController.stream);
      routerRefreshStream.updateStream(mockAuthCubit.stream);

      await tester.pumpWidget(
        buildTestWidget(
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      // Give it time to render initial state
      await tester.pump();

      // Simula o evento de recuperação
      stateController.add(const AuthState.passwordRecovery());

      // Wait for BlocListener to catch it and animation to finish
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Nova senha:'), findsOneWidget);

      stateController.close();
    },
  );

  testWidgets(
    'Deve redirecionar para login (/) quando o AuthCubit emitir unauthenticated',
    (WidgetTester tester) async {
      final stateController = StreamController<AuthState>.broadcast();
      const user = UserEntity(
        id: '123',
        email: 'guia@test.com',
        name: 'Guia Teste',
        roles: ['GUIA'],
      );

      when(() => mockAuthCubit.state).thenReturn(const AuthState.authenticated(user));
      when(
        () => mockAuthCubit.stream,
      ).thenAnswer((_) => stateController.stream);
      routerRefreshStream.updateStream(mockAuthCubit.stream);

      appRouter.go('/home');

      await tester.pumpWidget(
        buildTestWidget(
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Deve renderizar a HomePage já que está autenticado
      expect(find.byType(HomePage), findsOneWidget);

      // Simula o logout
      when(() => mockAuthCubit.state).thenReturn(const AuthState.unauthenticated());
      stateController.add(const AuthState.unauthenticated());

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Deve ter redirecionado para a LoginPage
      expect(find.byType(LoginPage), findsOneWidget);

      stateController.close();
    },
  );
}
