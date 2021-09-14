import 'package:bones_api/src/bones_api_logging.dart';
import 'package:bones_api/src/bones_api_mixin.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

final _log = logging.Logger('bones_api_test');

void main() {
  _log.handler.logToConsole();

  group('FieldsFromMap', () {
    setUp(() {});

    test('getFieldValueFromMap', () async {
      var fieldsTest = _FieldsTest();

      var map = {
        'country_code': 'US',
        'city': 'New York',
        'stateOrProvince': 'NY'
      };

      expect(
          fieldsTest.getFieldValueFromMap('country_code', map), equals('US'));
      expect(fieldsTest.getFieldValueFromMap('countrycode', map), equals('US'));
      expect(fieldsTest.getFieldValueFromMap('countryCode', map), equals('US'));
      expect(
          fieldsTest.getFieldValueFromMap('countryCode_', map), equals('US'));

      expect(fieldsTest.getFieldValueFromMap('city', map), equals('New York'));
      expect(fieldsTest.getFieldValueFromMap('City', map), equals('New York'));
      expect(fieldsTest.getFieldValueFromMap('City_', map), equals('New York'));

      expect(fieldsTest.getFieldValueFromMap('stateOrProvince', map),
          equals('NY'));
      expect(fieldsTest.getFieldValueFromMap('state_Or_Province', map),
          equals('NY'));
      expect(fieldsTest.getFieldValueFromMap('stateorprovince', map),
          equals('NY'));
    });

    test('getFieldValueFromMap', () async {
      var fieldsTest = _FieldsTest();

      var fieldsNames = ['country_code', 'city', 'state_or_province'];
      var fieldsNamesIndexes = fieldsTest.buildFieldsNamesIndexes(fieldsNames);
      var fieldsNamesLC = fieldsTest.buildFieldsNamesLC(fieldsNames);
      var fieldsNamesSimple = fieldsTest.buildFieldsNamesSimple(fieldsNames);

      expect(
          fieldsTest.getFieldsValuesFromMap(
              fieldsNames,
              {
                'country_code': 'US',
                'city': 'New York',
                'stateOrProvince': 'NY'
              },
              fieldsNamesIndexes: fieldsNamesIndexes,
              fieldsNamesLC: fieldsNamesLC,
              fieldsNamesSimple: fieldsNamesSimple),
          equals({
            'country_code': 'US',
            'city': 'New York',
            'state_or_province': 'NY'
          }));

      expect(
          fieldsTest.getFieldsValuesFromMap(
              fieldsNames,
              {
                'countrycode': 'US',
                'City': 'New York',
                'stateOrProvince': 'NY'
              },
              fieldsNamesIndexes: fieldsNamesIndexes,
              fieldsNamesLC: fieldsNamesLC,
              fieldsNamesSimple: fieldsNamesSimple),
          equals({
            'country_code': 'US',
            'city': 'New York',
            'state_or_province': 'NY'
          }));

      expect(
          fieldsTest.getFieldsValuesFromMap(
              fieldsNames,
              {
                'countryCode': 'US',
                'City': 'New York',
                'state_Or_Province': 'NY'
              },
              fieldsNamesIndexes: fieldsNamesIndexes,
              fieldsNamesLC: fieldsNamesLC,
              fieldsNamesSimple: fieldsNamesSimple),
          equals({
            'country_code': 'US',
            'city': 'New York',
            'state_or_province': 'NY'
          }));
    });
  });
}

class _FieldsTest with FieldsFromMap {}
