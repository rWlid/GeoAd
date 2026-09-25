class Pin {
  const Pin({
    required this.adId,
    required this.locationId,
    required this.lat,
    required this.lng,
    required this.isLive,
    required this.isBusiness,
  });

  factory Pin.fromJson(Map<String, dynamic> json) => Pin(
    adId: _string(json, 'ad_id'),
    locationId: _string(json, 'location_id'),
    lat: _double(json, 'lat'),
    lng: _double(json, 'lng'),
    isLive: _bool(json, 'is_live'),
    isBusiness: _bool(json, 'is_business'),
  );

  static List<Pin> listFromJson(Object? rows) {
    if (rows is! List<dynamic>) {
      throw FormatException('nearby_ads did not return a list');
    }
    return <Pin>[
      for (final Object? row in rows)
        if (row is Map<String, dynamic>)
          Pin.fromJson(row)
        else
          throw FormatException('nearby_ads returned a non-object row'),
    ];
  }

  final String adId;
  final String locationId;
  final double lat;
  final double lng;
  final bool isLive;
  final bool isBusiness;

  String get key => '$adId:$locationId';
}

String _string(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('nearby_ads.$key is not a string', value);
  }
  return value;
}

double _double(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! num) {
    throw FormatException('nearby_ads.$key is not a number', value);
  }
  return value.toDouble();
}

bool _bool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('nearby_ads.$key is not a boolean', value);
  }
  return value;
}
