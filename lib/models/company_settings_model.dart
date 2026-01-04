class CompanySettingsModel {
  final String id;
  final String companyName;
  final String address;
  final String phone;
  final String gstNumber;
  final String logoUrl;
  final String footerMessage;
  final String termsAndConditions;
  final bool useThermal80mm; // false = 58mm, true = 80mm
  final bool preferA4;
  final double gstRate; // Added GST Rate

  CompanySettingsModel({
    required this.id,
    required this.companyName,
    required this.address,
    required this.phone,
    required this.gstNumber,
    required this.logoUrl,
    required this.footerMessage,
    required this.termsAndConditions,
    this.useThermal80mm = true,
    this.preferA4 = false,
    this.gstRate = 12.0,
  });

  factory CompanySettingsModel.fromMap(String id, Map<String, dynamic> data) {
    return CompanySettingsModel(
      id: id,
      companyName: data['company_name'] ?? 'Factory Name',
      address: data['address'] ?? 'Factory Address',
      phone: data['phone'] ?? '',
      gstNumber: data['gst_number'] ?? '',
      logoUrl: data['logo_url'] ?? '',
      footerMessage: data['footer_message'] ?? 'Thank you for your business!',
      termsAndConditions: data['terms'] ?? '',
      useThermal80mm: data['use_thermal_80mm'] ?? true,
      preferA4: data['prefer_a4'] ?? false,
      gstRate: (data['gst_rate'] ?? 12.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_name': companyName,
      'address': address,
      'phone': phone,
      'gst_number': gstNumber,
      'logo_url': logoUrl,
      'footer_message': footerMessage,
      'terms': termsAndConditions,
      'use_thermal_80mm': useThermal80mm,
      'prefer_a4': preferA4,
      'gst_rate': gstRate,
    };
  }
  
  // Default Factory Settings
  static CompanySettingsModel defaults() {
    return CompanySettingsModel(
      id: 'company_profile',
      companyName: 'Namkeen Factory',
      address: 'Industrial Area, City',
      phone: '9876543210',
      gstNumber: '22AAAAA0000A1Z5',
      logoUrl: '',
      footerMessage: 'Quality is our priority.',
      termsAndConditions: 'Goods once sold will not be taken back.',
      gstRate: 12.0,
    );
  }
  
  CompanySettingsModel copyWith({
    String? companyName,
    String? address,
    String? phone,
    String? gstNumber,
    String? logoUrl,
    String? footerMessage,
    String? termsAndConditions,
    bool? useThermal80mm,
    bool? preferA4,
    double? gstRate,
  }) {
    return CompanySettingsModel(
      id: id,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstNumber: gstNumber ?? this.gstNumber,
      logoUrl: logoUrl ?? this.logoUrl,
      footerMessage: footerMessage ?? this.footerMessage,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      useThermal80mm: useThermal80mm ?? this.useThermal80mm,
      preferA4: preferA4 ?? this.preferA4,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}
