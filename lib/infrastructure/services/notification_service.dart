import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback for handling notification taps
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  // Handle notification tap - payload contains 'material:$materialId'
  // Navigation will be handled by the app when it's in foreground
}

/// Service for local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Request permission on Android 13+
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Show a notification for concept extraction ready
  Future<void> showConceptExtractionReady({
    required int materialId,
    required String materialTitle,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'concept_extraction',
      'Concept Extraction',
      channelDescription: 'Notifications for concept extraction',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.show(
      materialId,
      'Ready to extract concepts',
      'Tap to extract concepts from "$materialTitle"',
      details,
      payload: 'material:$materialId',
    );
  }

  /// Show a notification for processing complete
  Future<void> showProcessingComplete({
    required int materialId,
    required String materialTitle,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'processing_complete',
      'Processing Complete',
      channelDescription: 'Notifications for material processing',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.show(
      materialId,
      'Material processed',
      '"$materialTitle" is ready. Tap to extract concepts.',
      details,
      payload: 'material:$materialId',
    );
  }
}
