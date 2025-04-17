class Entity {
  final dynamic id;  // Can be int, String or null
  final String title; // Renamed from name for consistency
  final double lat; // Renamed from latitude for consistency
  final double lon; // Renamed from longitude for consistency
  final String? imageUrl;
  final String? createdBy; // Renamed from username for consistency
  final String syncStatus;  // 'synced', 'pending', 'update-pending', 'delete-pending', 'local'
  final int timestamp;

  Entity({
    this.id,
    required String title,
    required double lat,
    required double lon,
    this.imageUrl,
    this.createdBy,
    this.syncStatus = 'synced',
    required this.timestamp,
  }) : title = title,
       lat = lat,
       lon = lon;

  // For compatibility with existing code
  String get name => title;
  double get latitude => lat;
  double get longitude => lon;
  String? get image => imageUrl;
  String? get username => createdBy;

  factory Entity.fromJson(Map<String, dynamic> json) {
    double getLat(Map<String, dynamic> json) {
      try {
        if (json.containsKey('lat')) return double.parse(json['lat'].toString());
        if (json.containsKey('latitude')) return double.parse(json['latitude'].toString());
        return 0.0;
      } catch (e) {
        print('Error parsing latitude: $e');
        return 0.0;
      }
    }
    
    double getLon(Map<String, dynamic> json) {
      try {
        if (json.containsKey('lon')) return double.parse(json['lon'].toString());
        if (json.containsKey('longitude')) return double.parse(json['longitude'].toString());
        return 0.0;
      } catch (e) {
        print('Error parsing longitude: $e');
        return 0.0;
      }
    }
    
    String getTitle(Map<String, dynamic> json) {
      if (json.containsKey('title') && json['title'] != null) return json['title'].toString();
      if (json.containsKey('name') && json['name'] != null) return json['name'].toString();
      return 'Unknown';
    }
    
    String? getCreator(Map<String, dynamic> json) {
      if (json.containsKey('createdBy') && json['createdBy'] != null) return json['createdBy'].toString();
      if (json.containsKey('created_by') && json['created_by'] != null) return json['created_by'].toString();
      if (json.containsKey('creator') && json['creator'] != null) return json['creator'].toString();
      if (json.containsKey('username') && json['username'] != null) return json['username'].toString();
      return null;
    }
    
    String? getImage(Map<String, dynamic> json) {
      if (json.containsKey('imageUrl') && json['imageUrl'] != null) return json['imageUrl'].toString();
      if (json.containsKey('image') && json['image'] != null) return json['image'].toString();
      if (json.containsKey('image_url') && json['image_url'] != null) return json['image_url'].toString();
      if (json.containsKey('image_data') && json['image_data'] != null) return json['image_data'].toString();
      return null;
    }

    return Entity(
      id: json['id'] ?? json['_id'],
      title: getTitle(json),
      lat: getLat(json),
      lon: getLon(json),
      imageUrl: getImage(json),
      createdBy: getCreator(json),
      syncStatus: json['syncStatus'] ?? json['sync_status'] ?? 'synced',
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'lat': lat,
      'lon': lon,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (createdBy != null) 'createdBy': createdBy,
      'syncStatus': syncStatus,
      'timestamp': timestamp,
    };
  }

  Entity copyWith({
    dynamic id,
    String? title,
    double? lat,
    double? lon,
    String? imageUrl,
    String? createdBy,
    String? syncStatus,
    int? timestamp,
  }) {
    return Entity(
      id: id ?? this.id,
      title: title ?? this.title,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      syncStatus: syncStatus ?? this.syncStatus,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // Check if the image is a base64 string
  bool isBase64Image() {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    return imageUrl!.startsWith('data:image') || 
           (imageUrl!.length > 100 && !imageUrl!.contains('/') && !imageUrl!.contains('\\'));
  }

  // Check if the image is a URL
  bool isImageUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    return imageUrl!.startsWith('http');
  }

  // Check if the image is a file path
  bool isLocalImage() {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    return imageUrl!.startsWith('/') || imageUrl!.contains('\\');
  }
  
  // Get full image URL for API images
  String getFullImageUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return 'https://via.placeholder.com/150';
    }
    
    if (imageUrl!.startsWith('http')) {
      return imageUrl!;
    }
    
    if (imageUrl!.startsWith('data:image')) {
      return imageUrl!;
    }
    
    if (imageUrl!.startsWith('/')) {
      return imageUrl!;
    }
    
    // For API images that are just paths like 'images/image1.jpg'
    if (imageUrl!.startsWith('images/')) {
      return 'https://labs.anontech.info/cse489/t3/${imageUrl!}';
    }
    
    // Assume it's an image name from the API
    return 'https://labs.anontech.info/cse489/t3/images/${imageUrl!}';
  }
}