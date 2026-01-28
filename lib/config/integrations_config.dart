class IntegrationsConfig {
  static const String emailJsServiceId = 'service_etivm0m';
  static const String emailJsTemplateId = 'template_1iyw0ub';
  static const String emailJsPublicKey = 'eJcxJq9HWCWKMp-5M';
  static const String emailJsAccessToken = '3w8ighMcLUC7poVnW9-7o';

  static const String reportSenderEmail = 'admin@citimovers.net';
  static const String reportSenderName = 'CitiMovers';

  static const List<String> internalReportRecipients = <String>[
    // 'admin@citimovers.net',
    // 'clientmanager@citimovers.net',
    // 'operator@citimovers.net',
    // 'pod@citimovers.net',
    // 'billing@citimovers.net',
    // 'finance@citimovers.net',
    // 'president@citimovers.net',
    'excel_gesite@yahoo.com',
    'potohubsystem@gmail.com',
    'Tyoinxmarie@gmail.com'
  ];

  static const List<String> sampleClientReportRecipients = <String>[
    'client@example.com',
    'client.manager@example.com',
    'client.pod@example.com',
    'client.billing@example.com',
    'client.finance@example.com',
    'client.admin@example.com',
  ];

  static const String dragonpayBaseUrl = 'https://test.dragonpay.ph/Pay.aspx';
  static const String dragonpayMerchantRequestUrl =
      'https://test.dragonpay.ph/MerchantRequest.aspx';
  static const String dragonpayMerchantId = 'YOUR_DRAGONPAY_MERCHANT_ID';
  static const String dragonpayPassword = 'YOUR_DRAGONPAY_PASSWORD';
  static const String dragonpayCurrency = 'PHP';
}
