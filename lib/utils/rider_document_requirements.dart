/// Canonical rider/helper document keys, labels, and lookup helpers.
class RiderDocumentRequirements {
  RiderDocumentRequirements._();

  static const Map<String, String> nameToKey = {
    "Driver's License": 'drivers_license',
    'Vehicle Registration (OR/CR)': 'vehicle_registration',
    'Vehicle Registration (OR)': 'vehicle_registration_or',
    'Vehicle Registration (CR)': 'vehicle_registration_cr',
    'NBI Clearance': 'nbi_clearance',
    'Drug Test': 'drug_test',
    'National Police Clearance': 'national_police_clearance',
    'Fit to Work': 'fit_to_work',
    'Resume': 'resume',
    'Valid ID': 'valid_id',
    'Unit Photo (Front - Plate Visible)': 'unit_photo_front_plate_visible',
    'Insurance': 'insurance',
    'Helper 1 - Drug Test': 'helper_1_drug_test',
    'Helper 1 - National Police Clearance': 'helper_1_national_police_clearance',
    'Helper 1 - Fit to Work': 'helper_1_fit_to_work',
    'Helper 1 - Resume': 'helper_1_resume',
    'Helper 1 - Valid ID': 'helper_1_valid_id',
    'Helper 2 - Drug Test': 'helper_2_drug_test',
    'Helper 2 - National Police Clearance': 'helper_2_national_police_clearance',
    'Helper 2 - Fit to Work': 'helper_2_fit_to_work',
    'Helper 2 - Resume': 'helper_2_resume',
    'Helper 2 - Valid ID': 'helper_2_valid_id',
  };

  static const Map<String, String> keyToLabel = {
    'drivers_license': "Driver's License",
    'vehicle_registration': 'Vehicle Registration (OR/CR)',
    'vehicle_registration_or': 'Vehicle Registration (OR)',
    'vehicle_registration_cr': 'Vehicle Registration (CR)',
    'nbi_clearance': 'NBI Clearance',
    'drug_test': 'Drug Test',
    'national_police_clearance': 'National Police Clearance',
    'fit_to_work': 'Fit to Work',
    'resume': 'Resume',
    'valid_id': 'Valid ID',
    'unit_photo_front_plate_visible': 'Unit Photo (Front - Plate Visible)',
    'insurance': 'Insurance',
    'helper_1_drug_test': 'Helper 1 - Drug Test',
    'helper_1_national_police_clearance': 'Helper 1 - National Police Clearance',
    'helper_1_fit_to_work': 'Helper 1 - Fit to Work',
    'helper_1_resume': 'Helper 1 - Resume',
    'helper_1_valid_id': 'Helper 1 - Valid ID',
    'helper_2_drug_test': 'Helper 2 - Drug Test',
    'helper_2_national_police_clearance': 'Helper 2 - National Police Clearance',
    'helper_2_fit_to_work': 'Helper 2 - Fit to Work',
    'helper_2_resume': 'Helper 2 - Resume',
    'helper_2_valid_id': 'Helper 2 - Valid ID',
  };

  /// Legacy admin / seeded keys mapped to canonical keys.
  static const Map<String, String> legacyKeyAliases = {
    'driverLicense': 'drivers_license',
    'nbiClearance': 'national_police_clearance',
    'ltoOr': 'vehicle_registration_or',
    'ltoCr': 'vehicle_registration_cr',
    'mvsf': 'vehicle_registration',
    'sticker': 'vehicle_registration',
    'truckPhotoFront': 'unit_photo_front_plate_visible',
    'truckPhotoBack': 'unit_photo_front_plate_visible',
    'truckPhotoLeft': 'unit_photo_front_plate_visible',
    'truckPhotoRight': 'unit_photo_front_plate_visible',
    'helper1Id': 'helper_1_valid_id',
    'helper1Nbi': 'helper_1_national_police_clearance',
    'helper2Id': 'helper_2_valid_id',
    'helper2Nbi': 'helper_2_national_police_clearance',
  };

  static const List<(String section, List<(String label, String key)>)> sections = [
    (
      'Driver Documents',
      [
        ("Driver's License", 'drivers_license'),
        ('Drug Test', 'drug_test'),
        ('National Police Clearance', 'national_police_clearance'),
        ('Fit to Work', 'fit_to_work'),
        ('Resume', 'resume'),
        ('Valid ID', 'valid_id'),
      ],
    ),
    (
      'Unit Documents',
      [
        ('Vehicle Registration (OR)', 'vehicle_registration_or'),
        ('Vehicle Registration (CR)', 'vehicle_registration_cr'),
        ('Unit Photo (Front - Plate Visible)', 'unit_photo_front_plate_visible'),
        ('Insurance', 'insurance'),
      ],
    ),
    (
      'Helper 1 Documents',
      [
        ('Helper 1 - Drug Test', 'helper_1_drug_test'),
        ('Helper 1 - National Police Clearance', 'helper_1_national_police_clearance'),
        ('Helper 1 - Fit to Work', 'helper_1_fit_to_work'),
        ('Helper 1 - Resume', 'helper_1_resume'),
        ('Helper 1 - Valid ID', 'helper_1_valid_id'),
      ],
    ),
    (
      'Helper 2 Documents',
      [
        ('Helper 2 - Drug Test', 'helper_2_drug_test'),
        ('Helper 2 - National Police Clearance', 'helper_2_national_police_clearance'),
        ('Helper 2 - Fit to Work', 'helper_2_fit_to_work'),
        ('Helper 2 - Resume', 'helper_2_resume'),
        ('Helper 2 - Valid ID', 'helper_2_valid_id'),
      ],
    ),
  ];

  static String labelForKey(String key) =>
      keyToLabel[key] ?? key.replaceAll('_', ' ');

  static String? keyForName(String name) => nameToKey[name];

  static String resolveUrl(dynamic docData) {
    if (docData == null) return '';
    if (docData is String) return docData.trim();
    if (docData is Map) {
      for (final field in ['url', 'imageUrl', 'downloadUrl']) {
        final value = docData[field]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  static String resolveStatus(dynamic docData, {required String url}) {
    if (docData is Map) {
      final status = docData['status']?.toString().trim();
      if (status != null && status.isNotEmpty) return status;
      final reviewStatus = docData['reviewStatus']?.toString().trim();
      if (reviewStatus != null && reviewStatus.isNotEmpty) return reviewStatus;
    }
    return url.isNotEmpty ? 'pending' : 'not_uploaded';
  }

  /// Finds document data for a canonical [key], checking legacy aliases too.
  static dynamic findDocumentData(Map<String, dynamic> documents, String key) {
    if (documents.containsKey(key)) return documents[key];

    for (final entry in documents.entries) {
      final aliasTarget = legacyKeyAliases[entry.key];
      if (aliasTarget == key) return entry.value;
    }

    for (final entry in legacyKeyAliases.entries) {
      if (entry.value == key && documents.containsKey(entry.key)) {
        return documents[entry.key];
      }
    }

    return null;
  }

  static List<(String label, String key)> get allDocuments {
    return sections.expand((section) => section.$2).toList();
  }
}
