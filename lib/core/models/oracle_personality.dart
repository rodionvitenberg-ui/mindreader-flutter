class OraclePersonality {
  const OraclePersonality({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory OraclePersonality.fromJson(Map<String, dynamic> json) =>
      OraclePersonality(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
      );
}

/// Server identity is separate from the local history and workspace identity.
class RemoteOracleReading {
  const RemoteOracleReading({
    required this.sessionId,
    required this.personalityId,
    required this.personalityName,
  });

  final String sessionId;
  final String personalityId;
  final String personalityName;

  factory RemoteOracleReading.fromJson(Map<String, dynamic> json) =>
      RemoteOracleReading(
        sessionId: json['sessionId'] as String,
        personalityId: json['personalityId'] as String,
        personalityName: json['personalityName'] as String,
      );

  Map<String, String> toJson() => {
    'sessionId': sessionId,
    'personalityId': personalityId,
    'personalityName': personalityName,
  };
}
