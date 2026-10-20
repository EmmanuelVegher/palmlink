class HospitalModel {
  final String id;
  final String state;
  final String lga;
  final String name;
  final String datimCode;
  final bool isCustom;

  HospitalModel({
    required this.id,
    required this.state,
    required this.lga,
    required this.name,
    required this.datimCode,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state,
        'lga': lga,
        'name': name,
        'datimCode': datimCode,
        'isCustom': isCustom,
      };

  factory HospitalModel.fromJson(Map<String, dynamic> json) => HospitalModel(
        id: json['id'] as String? ?? "${json['state']}-${json['lga']}-${json['datimCode']}",
        state: json['state'] as String? ?? "",
        lga: json['lga'] as String? ?? "",
        name: json['name'] as String? ?? "",
        datimCode: json['datimCode'] as String? ?? "",
        isCustom: json['isCustom'] as bool? ?? false,
      );

  HospitalModel copyWith({
    String? id,
    String? state,
    String? lga,
    String? name,
    String? datimCode,
    bool? isCustom,
  }) {
    return HospitalModel(
      id: id ?? this.id,
      state: state ?? this.state,
      lga: lga ?? this.lga,
      name: name ?? this.name,
      datimCode: datimCode ?? this.datimCode,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
