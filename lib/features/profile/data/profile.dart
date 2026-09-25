final RegExp _storedPhone = RegExp(r'^9665\d{8}$');

class Profile {
  const Profile({
    required this.name,
    required this.phone,
    this.isBusiness = false,
    this.businessName,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final Object? name = json['name'];
    final Object? phone = json['phone'];
    final Object? isBusiness = json['is_business'];
    final Object? businessName = json['business_name'];
    if (name != null && name is! String) {
      throw FormatException('profiles.name is not a string', name);
    }
    if (phone is! String || !_storedPhone.hasMatch(phone)) {
      throw FormatException('profiles.phone is not 9665XXXXXXXX', phone);
    }
    if (isBusiness is! bool) {
      throw FormatException('profiles.is_business is not a bool', isBusiness);
    }
    if (businessName != null && businessName is! String) {
      throw FormatException(
        'profiles.business_name is not a string',
        businessName,
      );
    }
    return Profile(
      name: name as String?,
      phone: phone,
      isBusiness: isBusiness,
      businessName: businessName as String?,
    );
  }

  final String? name;
  final String phone;
  final bool isBusiness;

  final String? businessName;

  Profile afterOnboarding({
    required String name,
    required bool isBusiness,
    required String? businessName,
  }) => Profile(
    name: name,
    phone: phone,
    isBusiness: isBusiness,
    businessName: businessName,
  );
}
