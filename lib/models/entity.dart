// lib/models/entity.dart
class Entity {
  final int? id;
  final String title;
  final double lat;
  final double lon;
  final String? image;

  Entity({
    this.id,
    required this.title,
    required this.lat,
    required this.lon,
    this.image,
  });

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      title: json['title'],
      lat: json['lat'] is String ? double.parse(json['lat']) : json['lat'],
      lon: json['lon'] is String ? double.parse(json['lon']) : json['lon'],
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'lat': lat,
      'lon': lon,
      if (image != null) 'image': image,
    };
  }

  String getFullImageUrl() {
    if (image == null || image!.isEmpty) return '';

    // If it's already a full URL, return it
    if (image!.startsWith('http')) return image!;

    // If it's a local file path, return as is
    if (image!.startsWith('/')) return image!;

    // Otherwise, it's a relative path from the API - add the base URL
    return 'https://labs.anontech.info/cse489/t3/${image!}';
  }

  Entity copyWith({
    int? id,
    String? title,
    double? lat,
    double? lon,
    String? image,
  }) {
    return Entity(
      id: id ?? this.id,
      title: title ?? this.title,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      image: image ?? this.image,
    );
  }
}