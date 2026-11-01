class FarmerProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? location;
  final String role; // 'farmer' or 'buyer'

  FarmerProfile({required this.id, this.email, this.fullName, this.phone, this.location, this.role = 'buyer'});

  bool get isFarmer => role == 'farmer';

  factory FarmerProfile.fromJson(Map<String, dynamic> json) => FarmerProfile(
        id: json['id'] ?? json['Id'] ?? '',
        email: json['email'] ?? json['Email'],
        fullName: json['fullName'] ?? json['FullName'],
        phone: json['phone'] ?? json['Phone'],
        location: json['location'] ?? json['Location'],
        role: json['role'] ?? json['Role'] ?? 'buyer',
      );
}
