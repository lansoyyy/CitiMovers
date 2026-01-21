import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/integrations_config.dart';

class DragonpayService {
  static final DragonpayService instance = DragonpayService._internal();

  DragonpayService._internal();

  String createPaymentUrl({
    required String txnId,
    required double amount,
    required String description,
    required String customerEmail,
    String currency = IntegrationsConfig.dragonpayCurrency,
  }) {
    final amountStr = amount.toStringAsFixed(2);

    final digestInput =
        '${IntegrationsConfig.dragonpayMerchantId}:$txnId:$amountStr:$currency:$description:$customerEmail:${IntegrationsConfig.dragonpayPassword}';
    final digest = sha1.convert(utf8.encode(digestInput)).toString();

    final uri = Uri.parse(IntegrationsConfig.dragonpayBaseUrl).replace(
      queryParameters: {
        'merchantid': IntegrationsConfig.dragonpayMerchantId,
        'txnid': txnId,
        'amount': amountStr,
        'ccy': currency,
        'description': description,
        'email': customerEmail,
        'digest': digest,
      },
    );

    return uri.toString();
  }
}
