class IRButton {
  final String name;
  final List<String>? encodedData; // ["0x90E428", "0x98010100"]

  IRButton({
    required this.name,
    this.encodedData,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'encodedData': encodedData,
  };

  factory IRButton.fromJson(Map<String, dynamic> json) {
    return IRButton(
      name: json['name'],
      encodedData: json['encodedData'] != null ? List<String>.from(json['encodedData']) : null,
    );
  }
}
