import 'package:test/test.dart';
import 'package:tsshogi/src/helpers/time.dart';

void main() {
  group('secondsToHHMMSS', () {
    test('zero', () {
      expect(secondsToHHMMSS(0), '00:00:00');
    });
    test('1 second', () {
      expect(secondsToHHMMSS(1), '00:00:01');
    });
    test('1 minute', () {
      expect(secondsToHHMMSS(60), '00:01:00');
    });
    test('1 hour', () {
      expect(secondsToHHMMSS(3600), '01:00:00');
    });
    test('1h 2m 3s', () {
      expect(secondsToHHMMSS(3723), '01:02:03');
    });
    test('large value', () {
      expect(secondsToHHMMSS(123456), '34:17:36');
    });
  });

  group('secondsToMSS', () {
    test('zero is " 0:00"', () {
      expect(secondsToMSS(0), ' 0:00');
    });
    test('9 seconds is " 0:09"', () {
      expect(secondsToMSS(9), ' 0:09');
    });
    test('59 seconds is " 0:59"', () {
      expect(secondsToMSS(59), ' 0:59');
    });
    test('1 minute is " 1:00"', () {
      expect(secondsToMSS(60), ' 1:00');
    });
    test('9 minutes 59 seconds is " 9:59"', () {
      expect(secondsToMSS(599), ' 9:59');
    });
    test('10 minutes is "10:00"', () {
      expect(secondsToMSS(600), '10:00');
    });
    test('100 minutes is "100:00"', () {
      expect(secondsToMSS(6000), '100:00');
    });
  });

  group('millisecondsToHHMMSS', () {
    test('zero', () {
      expect(millisecondsToHHMMSS(0), '00:00:00');
    });
    test('999 ms is truncated to 00:00:00', () {
      expect(millisecondsToHHMMSS(999), '00:00:00');
    });
    test('1000 ms is 00:00:01', () {
      expect(millisecondsToHHMMSS(1000), '00:00:01');
    });
    test('1999 ms is truncated to 00:00:01', () {
      expect(millisecondsToHHMMSS(1999), '00:00:01');
    });
    test('1h 2m 3s', () {
      expect(millisecondsToHHMMSS(3723000), '01:02:03');
    });
  });

  group('millisecondsToMSS', () {
    test('zero', () {
      expect(millisecondsToMSS(0), ' 0:00');
    });
    test('999 ms truncated', () {
      expect(millisecondsToMSS(999), ' 0:00');
    });
    test('1000 ms is " 0:01"', () {
      expect(millisecondsToMSS(1000), ' 0:01');
    });
    test('10 minutes is "10:00"', () {
      expect(millisecondsToMSS(600000), '10:00');
    });
  });
}
