import 'package:ac_automation/models/ir_button.dart';

class ACProfile {
  final String id;
  final String name;
  final String brand;
  final String? model;
  final String? year;
  final Map<String, IRButton> buttons;
  final DateTime createdAt;

  ACProfile({
    required this.id,
    required this.name,
    required this.brand,
    this.model,
    this.year,
    required this.buttons,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'model': model,
    'year': year,
    'buttons': buttons.map((key, value) => MapEntry(key, value.toJson())),
    'created_at': createdAt.toIso8601String(),
  };

  factory ACProfile.fromJson(Map<String, dynamic> json) {
    return ACProfile(
      id: json['id'],
      name: json['name'],
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      buttons: (json['buttons'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, IRButton.fromJson(value)),
      ),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
