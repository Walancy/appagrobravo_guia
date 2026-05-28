import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Serviço de alarmes locais para eventos do guia.
///
/// Regras:
/// - O alarme só é agendado APÓS o guia fazer check-in.
/// - Se o guia fizer check-out antes do prazo, o alarme é cancelado.
/// - A notificação só dispara SE o check-out não tiver sido realizado até [endDateTime].
/// - ID numérico da notificação é derivado do hash do [eventoId].
class EventAlarmService {
  EventAlarmService._();
  static final EventAlarmService instance = EventAlarmService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── Inicialização ──────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // 1. Inicializa o banco de dados de timezones
    tz_data.initializeTimeZones();

    // 2. Detecta e configura o timezone LOCAL real do dispositivo
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      debugPrint('[EventAlarmService] Timezone configurado: ${tzInfo.identifier}');
    } catch (e) {
      // Fallback: usa America/Sao_Paulo se não conseguir detectar
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
        debugPrint('[EventAlarmService] Timezone fallback: America/Sao_Paulo');
      } catch (_) {}
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // 3. Solicitar permissões no iOS/Android 13+
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  // ─── Agendar alarme de fim de evento ───────────────────────────────────────

  /// Agenda uma notificação para disparar em [endDateTime].
  /// Deve ser chamado imediatamente após o check-in do guia.
  /// Se [endDateTime] já tiver passado, nenhum alarme é criado.
  Future<void> agendarAlarmeCheckout({
    required String eventoId,
    required String eventoNome,
    required DateTime endDateTime,
  }) async {
    if (!_initialized) await init();

    final now = DateTime.now();

    debugPrint(
        '[EventAlarmService] Tentando agendar alarme para "$eventoNome" — endDateTime=$endDateTime | agora=$now');

    if (endDateTime.isBefore(now) || endDateTime.isAtSameMomentAs(now)) {
      debugPrint('[EventAlarmService] ⚠ endDateTime já passou — alarme ignorado.');
      return;
    }

    final id = _idForEvento(eventoId);

    // Converte para TZDateTime no timezone LOCAL do dispositivo
    final tzTime = tz.TZDateTime.from(endDateTime, tz.local);

    debugPrint(
        '[EventAlarmService] TZDateTime calculado: $tzTime (timezone: ${tz.local.name})');

    const androidDetails = AndroidNotificationDetails(
      'evento_checkout_channel',
      'Alertas de Check-out',
      channelDescription:
          'Lembrete para fazer check-out ao final da atividade',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      '⏰ Tempo esgotado: $eventoNome',
      'Você ainda não fez o check-out desta atividade. Confirme sua saída agora.',
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint(
        '[EventAlarmService] ✅ Alarme agendado para "$eventoNome" às $tzTime (id=$id)');
  }

  // ─── Cancelar alarme ────────────────────────────────────────────────────────

  /// Cancela o alarme do evento. Deve ser chamado ao fazer check-out.
  Future<void> cancelarAlarme(String eventoId) async {
    if (!_initialized) await init();
    final id = _idForEvento(eventoId);
    await _plugin.cancel(id);
    debugPrint(
        '[EventAlarmService] ✅ Alarme cancelado para eventoId=$eventoId (id=$id)');
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Converte um UUID em um ID inteiro positivo de 31 bits.
  int _idForEvento(String eventoId) {
    final hash = eventoId.hashCode.abs();
    return hash & 0x7FFFFFFF;
  }
}
