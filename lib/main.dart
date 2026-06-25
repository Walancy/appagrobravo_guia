import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/router/app_router.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:agrobravo/features/itinerary/presentation/cubit/itinerary_cubit.dart';
import 'package:agrobravo/core/cubits/global_alert_cubit.dart';
import 'package:agrobravo/core/cubits/theme_cubit.dart';
import 'package:agrobravo/core/cubits/language_cubit.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agrobravo/core/services/event_alarm_service.dart';
import 'package:agrobravo/core/services/notification_navigation_service.dart';
import 'dart:developer';

/// Handler de mensagens em background (precisa ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

/// Solicita permissão de push e salva o token FCM em public.users.
Future<void> setupFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // Registra handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicita permissão ao usuário (iOS mostra o diálogo nativo)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _getFcmTokenAndSave(messaging);
      // Atualiza token quando ele rotacionar
      messaging.onTokenRefresh.listen(_saveFcmToken);
    }
  } catch (e, stack) {
    debugPrint('Erro ao configurar FCM/Permissões: $e\n$stack');
  }
}

/// No iOS, o APNS token é registrado de forma assíncrona pelo sistema.
/// Aguarda até 10 tentativas com delay crescente antes de chamar getToken().
Future<void> _getFcmTokenAndSave(FirebaseMessaging messaging) async {
  // Em Android não há APNS token — pula a espera
  if (!defaultTargetPlatform.name.contains('iOS') &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    try {
      final token = await messaging.getToken();
      if (token != null) _saveFcmToken(token);
    } catch (e) {
      debugPrint('Erro ao obter FCM token (Android): $e');
    }
    return;
  }

  // iOS: aguarda APNS token com retry exponencial
  for (int attempt = 1; attempt <= 10; attempt++) {
    try {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null) {
        // APNS token disponível — agora podemos obter o FCM token
        final token = await messaging.getToken();
        if (token != null) _saveFcmToken(token);
        return;
      }
    } catch (_) {}

    // Aguarda antes da próxima tentativa (500ms, 1s, 1.5s... até 5s)
    await Future.delayed(Duration(milliseconds: 500 * attempt));
  }

  debugPrint('FCM: APNS token não disponível após 10 tentativas. Push pode não funcionar.');
}

void _saveFcmToken(String token) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  Supabase.instance.client
      .from('users')
      .update({'fcm_token': token})
      .eq('id', userId)
      .then((_) => debugPrint('FCM token salvo: $token'))
      .catchError((e) => debugPrint('Erro ao salvar FCM token: $e'));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isFirebaseSupported = kIsWeb || 
      defaultTargetPlatform == TargetPlatform.android || 
      defaultTargetPlatform == TargetPlatform.iOS || 
      defaultTargetPlatform == TargetPlatform.macOS;

  if (isFirebaseSupported) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Erro ao inicializar Firebase: $e');
    }
  }

  // Em produção, injete as chaves via --dart-define-from-file=.env (ou --dart-define).
  // Os nomes das constantes devem bater exatamente com as chaves do arquivo .env.
  const supabaseUrl = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY');

  String resolvedUrl = supabaseUrl;
  String resolvedAnonKey = supabaseAnonKey;

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    try {
      await dotenv.load(fileName: '.env');
      resolvedUrl = dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
      resolvedAnonKey = dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '';
    } catch (e) {
      debugPrint('Erro ao carregar o arquivo .env: $e');
    }
  }

  await initializeDateFormatting('pt_BR', null);

  await Supabase.initialize(
    url: resolvedUrl,
    anonKey: resolvedAnonKey,
  );

  // Escuta mudanças de estado de autenticação para atualizar o fcm_token reativamente
  if (isFirebaseSupported) {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      final user = session?.user;

      debugPrint('Supabase AuthChangeEvent: $event, user: ${user?.id}');

      if (user != null && (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed)) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await Supabase.instance.client
                .from('users')
                .update({'fcm_token': token})
                .eq('id', user.id);
            debugPrint('FCM token atualizado reativamente para o usuário: ${user.id}');
          }
        } catch (e) {
          debugPrint('Erro ao salvar FCM token reativamente: $e');
        }
      }
    });
  }

  configureDependencies();

  // Configurações de UI do Sistema (Edge-to-Edge)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  if (isFirebaseSupported) {
    try {
      setupFCM();
      NotificationNavigationService.initialize();
    } catch (e) {
      debugPrint('Erro ao configurar FCM: $e');
    }
  }

  // Inicializa o serviço de alarmes locais (check-out de eventos)
  await EventAlarmService.instance.init();

  runApp(
    DevicePreview(
      enabled: kDebugMode && kIsWeb,
      builder: (context) => const AgroBravoApp(),
    ),
  );
}

class AgroBravoApp extends StatefulWidget {
  const AgroBravoApp({super.key});

  @override
  State<AgroBravoApp> createState() => _AgroBravoAppState();
}

class _AgroBravoAppState extends State<AgroBravoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationNavigationService.markRouterReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<ThemeCubit>()),
        BlocProvider(create: (context) => getIt<LanguageCubit>()),
        BlocProvider(
          create: (context) => getIt<AuthCubit>()..checkAuthStatus(),
        ),
        BlocProvider(create: (context) => getIt<DocumentsCubit>()),
        BlocProvider(create: (context) => getIt<NotificationsCubit>()),
        BlocProvider(create: (context) => getIt<ItineraryCubit>()),
        BlocProvider(create: (context) => GlobalAlertCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LanguageCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                title: 'AgroBravo',
                debugShowCheckedModeBanner: false,
                themeMode: themeMode,
                theme: ThemeData(
                  primaryColor: AppColors.primary,
                  scaffoldBackgroundColor: AppColors.background,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.primary,
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                    brightness: Brightness.light,
                  ),
                  useMaterial3: true,
                  dividerColor: AppColors.backgroundLight,
                  dividerTheme: const DividerThemeData(
                    color: AppColors.backgroundLight,
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.backgroundLight.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.4), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.4), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                darkTheme: ThemeData(
                  primaryColor: AppColors.primary,
                  scaffoldBackgroundColor: AppColors.backgroundDark,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.primary,
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.surfaceDark,
                    onSurface: AppColors.textPrimaryDark,
                    brightness: Brightness.dark,
                  ),
                  useMaterial3: true,
                  dividerColor: AppColors.backgroundLightDark,
                  dividerTheme: const DividerThemeData(
                    color: AppColors.backgroundLightDark,
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.backgroundLightDark.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.textPrimaryDark.withOpacity(0.4), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.textPrimaryDark.withOpacity(0.4), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                locale: locale,
                supportedLocales: const [
                  Locale('pt', 'BR'),
                  Locale('en', 'US'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) {
                  Widget app = GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: child!,
                  );
                  if (kDebugMode && kIsWeb) {
                    app = DevicePreview.appBuilder(context, app);
                  }
                  return app;
                },
                routerConfig: appRouter,
              );
            },
          );
        },
      ),
    );
  }
}
