import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agrobravo/core/services/notification_navigation_service.dart';

/// Serviço responsável por inicializar e exibir notificações locais.
/// Usado para exibir o banner de notificação quando o app está em foreground,
/// tanto no Android quanto no iOS, e acionar a navegação ao tocar.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificações Importantes',
    description: 'Este canal é usado para notificações importantes do app.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Inicializa o serviço, cria o canal Android e registra o handler de tap.
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          dev.log(
            '[NOTIF] Local notification tapped. payload=${response.payload}',
            name: 'local_notification_service',
          );
          // Payload contém o target_route; delega a navegação ao serviço central.
          NotificationNavigationService.navigateFromLocalNotification(
            response.payload,
          );
        },
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        dev.log('[NOTIF] Android channel registered', name: 'local_notification_service');
      }
    } catch (e) {
      dev.log('[NOTIF] Failed to initialize: $e', name: 'local_notification_service');
    }
  }

  /// Exibe uma notificação local com [title], [body] e [payload] (target_route).
  /// Funciona tanto no Android quanto no iOS.
  static Future<void> showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      await _notificationsPlugin.show(
        // ID único por título para evitar substituir notificações de tipos distintos.
        title.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      dev.log('[NOTIF] Failed to show notification: $e', name: 'local_notification_service');
    }
  }
}
