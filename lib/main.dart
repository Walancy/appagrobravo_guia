import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:agrobravo/core/services/local_notification_service.dart';

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

    // iOS foreground: mantém alert:true para que o iOS exiba o banner do sistema.
    // O tap no banner dispara onMessageOpenedApp (mesmo com app em foreground),
    // que já tem o handler de navegação correto.
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Erro ao setar ForegroundNotificationPresentationOptions: $e');
    }

    // Registra handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Escuta mensagens recebidas em primeiro plano (foreground).
    // iOS: o sistema exibe o banner (alert:true) e o tap aciona onMessageOpenedApp.
    // Android: o sistema não exibe banner em foreground, usamos local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message received: ${message.messageId}');
      if (defaultTargetPlatform == TargetPlatform.android) {
        final notification = message.notification;
        if (notification != null) {
          final targetRoute = message.data['target_route']?.toString();
          LocalNotificationService.showNotification(
            notification.title ?? 'AgroBravo',
            notification.body ?? '',
            payload: targetRoute,
          );
        }
      }
    });


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
      // Registra ANTES do _getFcmTokenAndSave para capturar tokens entregues
      // assincronamente pelo iOS durante o período de espera do APNS.
      messaging.onTokenRefresh.listen(_saveFcmToken);
      await _getFcmTokenAndSave(messaging);
    }
  } catch (e, stack) {
    debugPrint('Erro ao configurar FCM/Permissões: $e\n$stack');
  }
}

/// No iOS, o APNS token é entregue de forma assíncrona pelo sistema operacional.
/// A abordagem correta é confiar no `onTokenRefresh` como fonte primária e tentar
/// `getToken()` com um delay inicial para dar tempo ao iOS de registrar o APNS token.
Future<void> _getFcmTokenAndSave(FirebaseMessaging messaging) async {
  // Android: sem APNS, obtém token diretamente
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    try {
      final token = await messaging.getToken();
      if (token != null) _saveFcmToken(token);
    } catch (e) {
      debugPrint('Erro ao obter FCM token (Android): $e');
    }
    return;
  }

  // iOS: aguarda o APNS token com retry espaçado (máx ~30s no total)
  // O SDK Firebase internamente aguarda o APNS token ao chamar getToken().
  // Delays progressivos cobrem a janela assíncrona do APNs registration.
  const delays = [1000, 2000, 3000, 5000, 8000, 10000]; // ms
  for (int i = 0; i < delays.length; i++) {
    await Future.delayed(Duration(milliseconds: delays[i]));
    try {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null) {
        debugPrint('APNS token obtido na tentativa ${i + 1}: $apnsToken');
        final token = await messaging.getToken();
        if (token != null) {
          _saveFcmToken(token);
          return;
        }
      } else {
        debugPrint('iOS tentativa ${i + 1}/${delays.length}: APNS token ainda null...');
      }
    } catch (e) {
      debugPrint('iOS tentativa ${i + 1} erro: $e');
    }
  }

  // Após todas as tentativas, loga aviso. O onTokenRefresh salvará quando chegar.
  debugPrint(
    'FCM: APNS token não disponível após ${delays.length} tentativas. '
    'O token será salvo via onTokenRefresh quando o iOS registrar o dispositivo.',
  );
}

void _saveFcmToken(String token) async {
  var userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) break;
    }
  }
  if (userId == null) {
    debugPrint('FCM: userId null após aguardar restauração de sessão.');
    return;
  }
  try {
    await Supabase.instance.client
        .from('users')
        .update({'fcm_token': token})
        .eq('id', userId);
    debugPrint('FCM token salvo com sucesso no Supabase para user $userId: $token');
  } catch (e) {
    debugPrint('Erro ao salvar FCM token no Supabase: $e');
  }
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
      // Atualiza FCM somente no login real, não em tokenRefreshed (ocorre a cada ~1h)
      if (data.event == AuthChangeEvent.signedIn) {
        _getFcmTokenAndSave(FirebaseMessaging.instance);
      }
    });
  }

  configureDependencies();

  // Configurações de UI do Sistema (Edge-to-Edge)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  if (isFirebaseSupported) {
    try {
      await LocalNotificationService.initialize();
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
                theme: _buildLightTheme(),
                darkTheme: _buildDarkTheme(),
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

  ThemeData _buildLightTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      brightness: Brightness.light,
    ).copyWith(
      outlineVariant: AppColors.textPrimary.withValues(alpha: 0.03),
      outline: AppColors.textPrimary.withValues(alpha: 0.05),
    );
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base,
      textTheme: GoogleFonts.barlowTextTheme(),
      dividerColor: AppColors.textPrimary.withValues(alpha: 0.03),
      dividerTheme: DividerThemeData(color: AppColors.textPrimary.withValues(alpha: 0.01), space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.01)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      listTileTheme: const ListTileThemeData(
        minLeadingWidth: 0,
        horizontalTitleGap: 12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.grey.shade300;
        }),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.backgroundLightDark,
      onSurface: AppColors.textPrimaryDark,
      brightness: Brightness.dark,
    ).copyWith(
      outlineVariant: Colors.white.withValues(alpha: 0.03),
      outline: Colors.white.withValues(alpha: 0.05),
    );
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: base,
      textTheme: GoogleFonts.barlowTextTheme(ThemeData.dark().textTheme),
      dividerColor: Colors.white.withValues(alpha: 0.03),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.01), space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.backgroundLightDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.01)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLightDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
      ),
      listTileTheme: const ListTileThemeData(
        minLeadingWidth: 0,
        horizontalTitleGap: 12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.grey.shade600;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return const Color(0xFF3A3A3A);
        }),
      ),
    );
  }
}
