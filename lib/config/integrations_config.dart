class IntegrationsConfig {
  static const String emailJsServiceId = 'service_b5ez4ix';
  static const String emailJsTemplateId = 'template_17hmw12';
  static const String emailJsPublicKey = 'LEnABj81nmpvvGCDJ';
  static const String emailJsAccessToken = 'VC9ew3T8WgVHGrzF_8k0O';

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
    'potohubsystem@gmail.com',
    'olanalans12345@gmail.com',
    'excel_gesite@yahoo.com'
  ];

  static const List<String> sampleClientReportRecipients = <String>[
    // Add actual client email addresses here
    // 'client@actualdomain.com',
  ];

  static const String dragonpayBaseUrl = 'https://test.dragonpay.ph/Pay.aspx';
  static const String dragonpayMerchantRequestUrl =
      'https://test.dragonpay.ph/MerchantRequest.aspx';
  static const String dragonpayMerchantId = 'YOUR_DRAGONPAY_MERCHANT_ID';
  static const String dragonpayPassword = 'YOUR_DRAGONPAY_PASSWORD';
  static const String dragonpayCurrency = 'PHP';
}
