import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/integrations_config.dart';

class EmailJsAttachment {
  final String fileName;
  final String content;
  final String? contentType;

  const EmailJsAttachment({
    required this.fileName,
    required this.content,
    this.contentType,
  });

  Map<String, dynamic> toTemplateParams(String paramPrefix) {
    return {
      '${paramPrefix}_filename': fileName,
      '${paramPrefix}_content': content,
      if (contentType != null) '${paramPrefix}_content_type': contentType,
    };
  }
}

class EmailJsService {
  static final EmailJsService instance = EmailJsService._internal();

  EmailJsService._internal();

  Future<bool> sendTemplateEmail({
    required String toEmail,
    required String subject,
    required Map<String, dynamic> templateParams,
  }) async {
    final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final accessToken = IntegrationsConfig.emailJsAccessToken;

    final data = <String, dynamic>{
      'service_id': IntegrationsConfig.emailJsServiceId,
      'template_id': IntegrationsConfig.emailJsTemplateId,
      'user_id': IntegrationsConfig.emailJsPublicKey,
      if (accessToken.isNotEmpty && !accessToken.startsWith('YOUR_'))
        'accessToken': accessToken,
      'template_params': <String, dynamic>{
        ...templateParams,
        'to_email': toEmail,
        'subject': subject,
        'from_email': IntegrationsConfig.reportSenderEmail,
        'from_name': IntegrationsConfig.reportSenderName,
      },
    };

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
