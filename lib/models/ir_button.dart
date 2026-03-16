class IRButton {
  final String name;
  final List<int>? rawData;

  IRButton({
    required this.name,
    this.rawData,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'rawData': rawData,
  };

  factory IRButton.fromJson(Map<String, dynamic> json) {
    return IRButton(
      name: json['name'],
      rawData: json['rawData'] != null ? List<int>.from(json['rawData']) : null,
    );
  }
}
