import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/platform/hangly_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('hangly/overlay');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'checkOverlayPermission':
          return true;
        case 'requestOverlayPermission':
          return null;
        case 'startOverlayService':
          return true;
        case 'stopOverlayService':
          return true;
        case 'isOverlayRunning':
          return false;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('HanglyChannel MethodChannel contracts', () {
    test('checkOverlayPermission invokes native method', () async {
      final hanglyChannel = HanglyChannel();
      final result = await hanglyChannel.checkOverlayPermission();

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'checkOverlayPermission');
    });

    test('startOverlayService passes parameters to native', () async {
      final hanglyChannel = HanglyChannel();
      final result = await hanglyChannel.startOverlayService(
        ropeColor: '#FFD700',
        ropeLength: 140.0,
        charmRadius: 26.0,
      );

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'startOverlayService');
      expect(log.first.arguments, {
        'charmBytes': null,
        'ropeColor': '#FFD700',
        'ropeLength': 140.0,
        'charmRadius': 26.0,
        'hapticsEnabled': true,
      });
    });

    test('stopOverlayService invokes native method', () async {
      final hanglyChannel = HanglyChannel();
      final result = await hanglyChannel.stopOverlayService();

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'stopOverlayService');
    });

    test('isOverlayRunning returns boolean', () async {
      final hanglyChannel = HanglyChannel();
      final result = await hanglyChannel.isOverlayRunning();

      expect(result, isFalse);
      expect(log, hasLength(1));
      expect(log.first.method, 'isOverlayRunning');
    });
  });
}
