import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/integrations_config.dart';

class DragonpayStatusResult {
  final String? refNo;
  final String? merchantId;
  final String? txnId;
  final double? amount;
  final String? currency;
  final String? description;
  final String? status;
  final String? email;
  final String? procId;
  final String? procMsg;

  const DragonpayStatusResult({
    this.refNo,
    this.merchantId,
    this.txnId,
    this.amount,
    this.currency,
    this.description,
    this.status,
    this.email,
    this.procId,
    this.procMsg,
  });

  factory DragonpayStatusResult.fromJson(Map<String, dynamic> json) {
    return DragonpayStatusResult(
      refNo: json['RefNo']?.toString(),
      merchantId: json['MerchantId']?.toString(),
      txnId: json['TxnId']?.toString(),
      amount: (json['Amount'] as num?)?.toDouble(),
      currency: json['Currency']?.toString(),
      description: json['Description']?.toString(),
      status: json['Status']?.toString(),
      email: json['Email']?.toString(),
      procId: json['ProcId']?.toString(),
      procMsg: json['ProcMsg']?.toString(),
    );
  }
}

class DragonpayStatusService {
  static final DragonpayStatusService instance = DragonpayStatusService._();

  DragonpayStatusService._();

  /// Checks transaction status using Dragonpay MerchantRequest model:
  /// GET MerchantRequest.aspx?op=GETSTATUS&merchantid=...&merchantpwd=...&txnid=...
  ///
  /// NOTE: This requires merchant password and is not safe to ship in production.
  /// In production, this should be done via a server/Cloud Function.
  Future<DragonpayStatusResult?> getStatus({required String txnId}) async {
    try {
      final uri =
          Uri.parse(IntegrationsConfig.dragonpayMerchantRequestUrl).replace(
        queryParameters: {
          'op': 'GETSTATUS',
          'merchantid': IntegrationsConfig.dragonpayMerchantId,
          'merchantpwd': IntegrationsConfig.dragonpayPassword,
          'txnid': txnId,
        },
      );

      final resp = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return null;
      }

      final content = resp.body;
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return DragonpayStatusResult.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  /// Validates Dragonpay return/postback digest (when available).
  /// Digest format commonly used by Dragonpay return samples:
  /// sha1(txnid + refno + status + message + password)
  bool verifyReturnDigest({
    required String txnId,
    required String refNo,
    required String status,
    required String message,
    required String digest,
  }) {
    final input =
        '$txnId$refNo$status$message${IntegrationsConfig.dragonpayPassword}';
    final computed = sha1.convert(utf8.encode(input)).toString();
    return computed.toLowerCase() == digest.toLowerCase();
  }
}
