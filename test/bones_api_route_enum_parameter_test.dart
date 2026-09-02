@TestOn('vm')
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

part 'bones_api_route_enum_parameter_test.reflection.g.dart';

@EnableReflection()
enum PaymentType { creditCard, debitCard, pix }

@EnableReflection()
enum Currency { brl, usd, eur }

class EnumParameterAPIRoot extends APIRoot {
  EnumParameterAPIRoot() : super('enum-parameter-test', '1.0');

  @override
  Set<APIModule> loadModules() => {ExternalIntegrationModule(this)};
}

@EnableReflection()
class ExternalIntegrationModule extends APIModule {
  ExternalIntegrationModule(APIRoot apiRoot)
    : super(apiRoot, 'external_integration');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  APIResponse<Map> updateOrderStatusFromBroker(
    int orderId,
    String status,
    bool paid,
    PaymentType? paymentType,
    Currency? chargedCurrency,
    double? chargedPrice,
  ) => APIResponse.ok({
    'orderId': orderId,
    'status': status,
    'paid': paid,
    'paymentType': paymentType?.name,
    'chargedCurrency': chargedCurrency?.name,
    'chargedPrice': chargedPrice,
  });
}

void main() {
  group('APIRoute enum parameter', () {
    setUpAll(() {
      ExternalIntegrationModule$reflection.boot();
    });

    test('enum parameter from `String` (enum name)', () async {
      var apiRoot = EnumParameterAPIRoot();

      var response = await apiRoot.call(
        APIRequest.post(
          '/external_integration/updateOrderStatusFromBroker',
          parameters: {
            'orderId': 198945,
            'status': 'canceled',
            'paid': false,
            'paymentType': 'creditCard',
            'chargedCurrency': 'brl',
            'chargedPrice': 12.89,
          },
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');

      expect(
        response.payload,
        equals({
          'orderId': 198945,
          'status': 'canceled',
          'paid': false,
          'paymentType': 'creditCard',
          'chargedCurrency': 'brl',
          'chargedPrice': 12.89,
        }),
      );

      apiRoot.close();
    });

    test('enum parameter from `String` (qualified enum name)', () async {
      var apiRoot = EnumParameterAPIRoot();

      var response = await apiRoot.call(
        APIRequest.post(
          '/external_integration/updateOrderStatusFromBroker',
          parameters: {
            'orderId': 198945,
            'status': 'canceled',
            'paid': false,
            'paymentType': 'PaymentType.creditCard',
            'chargedCurrency': 'Currency.brl',
            'chargedPrice': 12.89,
          },
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');

      expect(
        response.payload,
        equals({
          'orderId': 198945,
          'status': 'canceled',
          'paid': false,
          'paymentType': 'creditCard',
          'chargedCurrency': 'brl',
          'chargedPrice': 12.89,
        }),
      );

      apiRoot.close();
    });

    test('enum parameter from `String` (case insensitive)', () async {
      var apiRoot = EnumParameterAPIRoot();

      var response = await apiRoot.call(
        APIRequest.post(
          '/external_integration/updateOrderStatusFromBroker',
          parameters: {
            'orderId': 198945,
            'status': 'canceled',
            'paid': false,
            'paymentType': 'CreditCard',
            'chargedCurrency': 'BRL',
            'chargedPrice': 12.89,
          },
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');

      expect(
        response.payload,
        equals({
          'orderId': 198945,
          'status': 'canceled',
          'paid': false,
          'paymentType': 'creditCard',
          'chargedCurrency': 'brl',
          'chargedPrice': 12.89,
        }),
      );

      apiRoot.close();
    });

    test('enum parameter from JSON payload', () async {
      var apiRoot = EnumParameterAPIRoot();

      var response = await apiRoot.call(
        APIRequest.post(
          '/external_integration/updateOrderStatusFromBroker',
          payload: {
            'orderId': 198945,
            'status': 'canceled',
            'paid': false,
            'paymentType': 'creditCard',
            'chargedCurrency': 'brl',
            'chargedPrice': 12.89,
          },
          payloadMimeType: 'json',
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');

      expect(
        response.payload,
        equals({
          'orderId': 198945,
          'status': 'canceled',
          'paid': false,
          'paymentType': 'creditCard',
          'chargedCurrency': 'brl',
          'chargedPrice': 12.89,
        }),
      );

      apiRoot.close();
    });

    test('null enum parameter', () async {
      var apiRoot = EnumParameterAPIRoot();

      var response = await apiRoot.call(
        APIRequest.post(
          '/external_integration/updateOrderStatusFromBroker',
          parameters: {
            'orderId': 198945,
            'status': 'canceled',
            'paid': false,
            'chargedPrice': 12.89,
          },
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');

      expect(
        response.payload,
        equals({
          'orderId': 198945,
          'status': 'canceled',
          'paid': false,
          'paymentType': null,
          'chargedCurrency': null,
          'chargedPrice': 12.89,
        }),
      );

      apiRoot.close();
    });
  });
}
