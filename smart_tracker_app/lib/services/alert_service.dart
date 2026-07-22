import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertService {
  AlertService._();

  static final AlertService instance = AlertService._();

  static const int _notificationId = 9001;
  static const String _stopActionId = 'STOP_ALARM';
  static const String _geofenceAckKey = 'ack_geofence_episode';
  static const String _emergencyAckKey = 'ack_emergency_episode';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;
  bool _alarmPlaying = false;

  bool get alarmPlaying => _alarmPlaying;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.actionId != _stopActionId) return;

    final alertKind = response.payload;
    if (alertKind == 'EMERGENCY' || alertKind == 'GEOFENCE') {
      await acknowledge(alertKind!);
    }

    await stopAlarm();
  }

  Future<void> startAlarm({
    required String alertKind,
    required String title,
    required String body,
  }) async {
    await initialize();

    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(AssetSource('audio/emergency_alarm.wav'));
    _alarmPlaying = true;

    const androidDetails = AndroidNotificationDetails(
      'smart_guardian_emergency',
      'Smart Guardian emergency alerts',
      channelDescription:
          'Urgent geofence and emergency-button alerts from Smart Guardian.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _stopActionId,
          'STOP ALARM',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: alertKind,
    );
  }

  Future<void> stopAlarm() async {
    await _player.stop();
    _alarmPlaying = false;
    await _notifications.cancel(id: _notificationId);
  }

  Future<bool> isAcknowledged(String alertKind) async {
    final preferences = await SharedPreferences.getInstance();
    if (alertKind == 'GEOFENCE') {
      return preferences.getBool(_geofenceAckKey) ?? false;
    }
    return preferences.getBool(_emergencyAckKey) ?? false;
  }

  Future<void> acknowledge(String alertKind) async {
    final preferences = await SharedPreferences.getInstance();
    if (alertKind == 'GEOFENCE') {
      await preferences.setBool(_geofenceAckKey, true);
    } else {
      await preferences.setBool(_emergencyAckKey, true);
    }
  }

  Future<void> resetAcknowledgement(String alertKind) async {
    final preferences = await SharedPreferences.getInstance();
    if (alertKind == 'GEOFENCE') {
      await preferences.setBool(_geofenceAckKey, false);
    } else {
      await preferences.setBool(_emergencyAckKey, false);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
