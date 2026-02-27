class User {
  final int id;
  final String name;
  final String mobile;
  final String role;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final int? hospitalId;
  
  // Pharma Professional fields
  final String? companyName;
  final String? product1;
  final String? product2;
  final String? product3;
  final String? product4;
  
  // Doctor fields
  final String? degree;
  final String? instituteName;
  final String? experience1;
  final String? experience2;
  final String? experience3;
  final String? experience4;

  User({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.hospitalId,
    this.companyName,
    this.product1,
    this.product2,
    this.product3,
    this.product4,
    this.degree,
    this.instituteName,
    this.experience1,
    this.experience2,
    this.experience3,
    this.experience4,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      mobile: json['mobile'],
      role: json['role'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      addressLine3: json['address_line3'],
      hospitalId: json['hospital_id'],
      companyName: json['company_name'],
      product1: json['product1'],
      product2: json['product2'],
      product3: json['product3'],
      product4: json['product4'],
      degree: json['degree'],
      instituteName: json['institute_name'],
      experience1: json['experience1'],
      experience2: json['experience2'],
      experience3: json['experience3'],
      experience4: json['experience4'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'role': role,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'address_line3': addressLine3,
      'hospital_id': hospitalId,
      'company_name': companyName,
      'product1': product1,
      'product2': product2,
      'product3': product3,
      'product4': product4,
      'degree': degree,
      'institute_name': instituteName,
      'experience1': experience1,
      'experience2': experience2,
      'experience3': experience3,
      'experience4': experience4,
    };
  }
}



