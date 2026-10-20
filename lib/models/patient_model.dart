class PatientModel {
  final String id;
  final String patientId;
  final String fullName;
  final String gender;
  final int age;
  final String phoneNumber;
  final String bloodGroup;
  final List<double> palmEmbedding; // Primary / Left Palm
  final List<double>? leftPalmEmbedding;
  final List<double>? rightPalmEmbedding;
  final DateTime registeredAt;
  DateTime? lastVerifiedAt;

  PatientModel({
    required this.id,
    required this.patientId,
    required this.fullName,
    required this.gender,
    required this.age,
    required this.phoneNumber,
    required this.bloodGroup,
    required this.palmEmbedding,
    this.leftPalmEmbedding,
    this.rightPalmEmbedding,
    required this.registeredAt,
    this.lastVerifiedAt,
  });

  List<double> get activeLeftPalm => leftPalmEmbedding ?? palmEmbedding;
  List<double> get activeRightPalm => rightPalmEmbedding ?? palmEmbedding;

  bool get hasBiometrics =>
      (leftPalmEmbedding != null && leftPalmEmbedding!.isNotEmpty) ||
      (rightPalmEmbedding != null && rightPalmEmbedding!.isNotEmpty) ||
      palmEmbedding.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'fullName': fullName,
      'gender': gender,
      'age': age,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'palmEmbedding': palmEmbedding,
      'leftPalmEmbedding': leftPalmEmbedding,
      'rightPalmEmbedding': rightPalmEmbedding,
      'registeredAt': registeredAt.toIso8601String(),
      'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
    };
  }

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    List<double> parseVector(dynamic list) {
      if (list == null) return [];
      return (list as List).map((e) => (e as num).toDouble()).toList();
    }

    final primaryVec = parseVector(json['palmEmbedding']);

    return PatientModel(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      fullName: json['fullName'] as String,
      gender: json['gender'] as String,
      age: json['age'] as int,
      phoneNumber: json['phoneNumber'] as String,
      bloodGroup: json['bloodGroup'] as String,
      palmEmbedding: primaryVec,
      leftPalmEmbedding: json['leftPalmEmbedding'] != null ? parseVector(json['leftPalmEmbedding']) : primaryVec,
      rightPalmEmbedding: json['rightPalmEmbedding'] != null ? parseVector(json['rightPalmEmbedding']) : null,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      lastVerifiedAt: json['lastVerifiedAt'] != null
          ? DateTime.parse(json['lastVerifiedAt'] as String)
          : null,
    );
  }

  PatientModel copyWith({
    String? id,
    String? patientId,
    String? fullName,
    String? gender,
    int? age,
    String? phoneNumber,
    String? bloodGroup,
    List<double>? palmEmbedding,
    List<double>? leftPalmEmbedding,
    List<double>? rightPalmEmbedding,
    DateTime? registeredAt,
    DateTime? lastVerifiedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      palmEmbedding: palmEmbedding ?? this.palmEmbedding,
      leftPalmEmbedding: leftPalmEmbedding ?? this.leftPalmEmbedding,
      rightPalmEmbedding: rightPalmEmbedding ?? this.rightPalmEmbedding,
      registeredAt: registeredAt ?? this.registeredAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}
