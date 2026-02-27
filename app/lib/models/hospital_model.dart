class Hospital {
  final int id;
  final String name;
  final String email;
  final String mobile;
  final String status;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String? city;
  final String? state;
  final String? pincode;
  final bool? whatsappEnabled;
  final String? defaultUpiId;
  final String? googlePayUpiId;
  final String? phonePeUpiId;
  final String? paytmUpiId;
  final String? bhimUpiId;
  final String? paymentQrCode;

  Hospital({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.status,
    this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.city,
    this.state,
    this.pincode,
    this.whatsappEnabled,
    this.defaultUpiId,
    this.googlePayUpiId,
    this.phonePeUpiId,
    this.paytmUpiId,
    this.bhimUpiId,
    this.paymentQrCode,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      mobile: json['mobile'],
      status: json['status'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      addressLine3: json['address_line3'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      whatsappEnabled: json['whatsapp_enabled'],
      defaultUpiId: json['default_upi_id'],
      googlePayUpiId: json['google_pay_upi_id'],
      phonePeUpiId: json['phonepe_upi_id'],
      paytmUpiId: json['paytm_upi_id'],
      bhimUpiId: json['bhim_upi_id'],
      paymentQrCode: json['payment_qr_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'status': status,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'address_line3': addressLine3,
      'city': city,
      'state': state,
      'pincode': pincode,
      'whatsapp_enabled': whatsappEnabled,
      'default_upi_id': defaultUpiId,
      'google_pay_upi_id': googlePayUpiId,
      'phonepe_upi_id': phonePeUpiId,
      'paytm_upi_id': paytmUpiId,
      'bhim_upi_id': bhimUpiId,
      'payment_qr_code': paymentQrCode,
    };
  }
}



