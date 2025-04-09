class LocationNote {
  final int? id;
  final int userId;
  final String name;
  final String? description;
  final String? imagePath;

  LocationNote({
    this.id,
    required this.userId,
    required this.name,
    this.description,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'imagePath': imagePath,
    };
  }

  static LocationNote fromMap(Map<String, dynamic> map) {
    return LocationNote(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      description: map['description'],
      imagePath: map['imagePath'],
    );
  }

  LocationNote copyWith({
    int? id,
    int? userId,
    String? name,
    String? description,
    String? imagePath,
  }) {
    return LocationNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
