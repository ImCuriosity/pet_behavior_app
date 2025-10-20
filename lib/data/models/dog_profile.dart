// lib/data/models/dog_profile.dart

class DogProfile {
  final String id;
  final String name;
  final String? breed;
  final int? age;
  final String? gender;
  final String? notes;

  DogProfile({
    required this.id,
    required this.name,
    this.breed,
    this.age,
    this.gender,
    this.notes,
  });

  factory DogProfile.fromMap(Map<String, dynamic> map) {
    return DogProfile(
      id: map['id'],
      name: map['name'] ?? '',
      breed: map['breed'],
      age: map['age'],
      gender: map['gender'],
      notes: map['notes'],
    );
  }
}