/// Параметры одного колеса (шина или хаб) для отрисовки на карте.
class WheelParams {
  final double axleForwardM;
  final double sideOffsetM;
  final double lengthM;
  final double widthM;

  const WheelParams({
    required this.axleForwardM,
    required this.sideOffsetM,
    required this.lengthM,
    required this.widthM,
  });

  Map<String, dynamic> toMap() => {
        'axle_forward_m': axleForwardM,
        'side_offset_m': sideOffsetM,
        'length_m': lengthM,
        'width_m': widthM,
      };

  static WheelParams fromMap(Map<String, dynamic> map) {
    double d(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;
    return WheelParams(
      axleForwardM: d(map['axle_forward_m'], 0),
      sideOffsetM: d(map['side_offset_m'], 0),
      lengthM: d(map['length_m'], 1),
      widthM: d(map['width_m'], 0.5),
    );
  }
}

/// Профиль техники (трактор/агрегат): геометрия силуэта и цвета для карты.
class EquipmentProfile {
  final String id;
  final String name;

  final double bodyLengthM;
  final double bodyWidthM;
  final double bodyForwardOffsetM;

  final double cabLengthM;
  final double cabWidthM;
  final double cabForwardOffsetM;

  final double hoodLengthM;
  final double hoodWidthM;
  final double hoodForwardOffsetM;

  final WheelParams rearLeftWheel;
  final WheelParams rearRightWheel;
  final WheelParams frontLeftWheel;
  final WheelParams frontRightWheel;

  final WheelParams rearLeftHub;
  final WheelParams rearRightHub;
  final WheelParams frontLeftHub;
  final WheelParams frontRightHub;

  final String bodyColor;
  final String hoodColor;
  final String cabColor;
  final String borderColor;
  final String cabBorderColor;
  final String tireColor;
  final String hubColor;

  const EquipmentProfile({
    required this.id,
    required this.name,
    required this.bodyLengthM,
    required this.bodyWidthM,
    required this.bodyForwardOffsetM,
    required this.cabLengthM,
    required this.cabWidthM,
    required this.cabForwardOffsetM,
    required this.hoodLengthM,
    required this.hoodWidthM,
    required this.hoodForwardOffsetM,
    required this.rearLeftWheel,
    required this.rearRightWheel,
    required this.frontLeftWheel,
    required this.frontRightWheel,
    required this.rearLeftHub,
    required this.rearRightHub,
    required this.frontLeftHub,
    required this.frontRightHub,
    required this.bodyColor,
    required this.hoodColor,
    required this.cabColor,
    required this.borderColor,
    required this.cabBorderColor,
    required this.tireColor,
    required this.hubColor,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'body_length_m': bodyLengthM,
        'body_width_m': bodyWidthM,
        'body_forward_offset_m': bodyForwardOffsetM,
        'cab_length_m': cabLengthM,
        'cab_width_m': cabWidthM,
        'cab_forward_offset_m': cabForwardOffsetM,
        'hood_length_m': hoodLengthM,
        'hood_width_m': hoodWidthM,
        'hood_forward_offset_m': hoodForwardOffsetM,
        'rear_left_wheel': rearLeftWheel.toMap(),
        'rear_right_wheel': rearRightWheel.toMap(),
        'front_left_wheel': frontLeftWheel.toMap(),
        'front_right_wheel': frontRightWheel.toMap(),
        'rear_left_hub': rearLeftHub.toMap(),
        'rear_right_hub': rearRightHub.toMap(),
        'front_left_hub': frontLeftHub.toMap(),
        'front_right_hub': frontRightHub.toMap(),
        'body_color': bodyColor,
        'hood_color': hoodColor,
        'cab_color': cabColor,
        'border_color': borderColor,
        'cab_border_color': cabBorderColor,
        'tire_color': tireColor,
        'hub_color': hubColor,
      };

  static EquipmentProfile fromMap(Map<String, dynamic> map) {
    double d(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;
    String s(dynamic v, String fallback) => v is String ? v : fallback;
    return EquipmentProfile(
      id: s(map['id'], 'default'),
      name: s(map['name'], 'Трактор'),
      bodyLengthM: d(map['body_length_m'], 6.8),
      bodyWidthM: d(map['body_width_m'], 4.2),
      bodyForwardOffsetM: d(map['body_forward_offset_m'], -0.3),
      cabLengthM: d(map['cab_length_m'], 2.3),
      cabWidthM: d(map['cab_width_m'], 3.0),
      cabForwardOffsetM: d(map['cab_forward_offset_m'], 1.5),
      hoodLengthM: d(map['hood_length_m'], 2.8),
      hoodWidthM: d(map['hood_width_m'], 2.4),
      hoodForwardOffsetM: d(map['hood_forward_offset_m'], 3.8),
      rearLeftWheel: WheelParams.fromMap(Map<String, dynamic>.from((map['rear_left_wheel'] as Map?) ?? {})),
      rearRightWheel: WheelParams.fromMap(Map<String, dynamic>.from((map['rear_right_wheel'] as Map?) ?? {})),
      frontLeftWheel: WheelParams.fromMap(Map<String, dynamic>.from((map['front_left_wheel'] as Map?) ?? {})),
      frontRightWheel: WheelParams.fromMap(Map<String, dynamic>.from((map['front_right_wheel'] as Map?) ?? {})),
      rearLeftHub: WheelParams.fromMap(Map<String, dynamic>.from((map['rear_left_hub'] as Map?) ?? {})),
      rearRightHub: WheelParams.fromMap(Map<String, dynamic>.from((map['rear_right_hub'] as Map?) ?? {})),
      frontLeftHub: WheelParams.fromMap(Map<String, dynamic>.from((map['front_left_hub'] as Map?) ?? {})),
      frontRightHub: WheelParams.fromMap(Map<String, dynamic>.from((map['front_right_hub'] as Map?) ?? {})),
      bodyColor: s(map['body_color'], '#2E7D32'),
      hoodColor: s(map['hood_color'], '#388E3C'),
      cabColor: s(map['cab_color'], '#1565C0'),
      borderColor: s(map['border_color'], '#212121'),
      cabBorderColor: s(map['cab_border_color'], '#FFFFFF'),
      tireColor: s(map['tire_color'], '#FFFFFF'),
      hubColor: s(map['hub_color'], '#C62828'),
    );
  }

  /// Встроенный профиль «Фермерский» (зелёный корпус, синяя кабина, белые шины, красные диски).
  static EquipmentProfile farmer() => const EquipmentProfile(
        id: 'farmer',
        name: 'Фермерский',
        bodyLengthM: 6.8,
        bodyWidthM: 4.2,
        bodyForwardOffsetM: -0.3,
        cabLengthM: 2.3,
        cabWidthM: 3.0,
        cabForwardOffsetM: 1.5,
        hoodLengthM: 2.8,
        hoodWidthM: 2.4,
        hoodForwardOffsetM: 3.8,
        rearLeftWheel: WheelParams(axleForwardM: -1.6, sideOffsetM: 2.3, lengthM: 2.3, widthM: 0.95),
        rearRightWheel: WheelParams(axleForwardM: -1.6, sideOffsetM: -2.3, lengthM: 2.3, widthM: 0.95),
        frontLeftWheel: WheelParams(axleForwardM: 3.0, sideOffsetM: 1.8, lengthM: 1.4, widthM: 0.7),
        frontRightWheel: WheelParams(axleForwardM: 3.0, sideOffsetM: -1.8, lengthM: 1.4, widthM: 0.7),
        rearLeftHub: WheelParams(axleForwardM: -1.6, sideOffsetM: 2.3, lengthM: 1.0, widthM: 0.45),
        rearRightHub: WheelParams(axleForwardM: -1.6, sideOffsetM: -2.3, lengthM: 1.0, widthM: 0.45),
        frontLeftHub: WheelParams(axleForwardM: 3.0, sideOffsetM: 1.8, lengthM: 0.6, widthM: 0.33),
        frontRightHub: WheelParams(axleForwardM: 3.0, sideOffsetM: -1.8, lengthM: 0.6, widthM: 0.33),
        bodyColor: '#2E7D32',
        hoodColor: '#388E3C',
        cabColor: '#1565C0',
        borderColor: '#212121',
        cabBorderColor: '#FFFFFF',
        tireColor: '#FFFFFF',
        hubColor: '#C62828',
      );

  /// Встроенный профиль «Классика» (светлый корпус, серая кабина).
  static EquipmentProfile classic() => const EquipmentProfile(
        id: 'classic',
        name: 'Классика',
        bodyLengthM: 6.8,
        bodyWidthM: 4.2,
        bodyForwardOffsetM: -0.3,
        cabLengthM: 2.3,
        cabWidthM: 3.0,
        cabForwardOffsetM: 1.5,
        hoodLengthM: 2.8,
        hoodWidthM: 2.4,
        hoodForwardOffsetM: 3.8,
        rearLeftWheel: WheelParams(axleForwardM: -1.6, sideOffsetM: 2.3, lengthM: 2.3, widthM: 0.95),
        rearRightWheel: WheelParams(axleForwardM: -1.6, sideOffsetM: -2.3, lengthM: 2.3, widthM: 0.95),
        frontLeftWheel: WheelParams(axleForwardM: 3.0, sideOffsetM: 1.8, lengthM: 1.4, widthM: 0.7),
        frontRightWheel: WheelParams(axleForwardM: 3.0, sideOffsetM: -1.8, lengthM: 1.4, widthM: 0.7),
        rearLeftHub: WheelParams(axleForwardM: -1.6, sideOffsetM: 2.3, lengthM: 1.0, widthM: 0.45),
        rearRightHub: WheelParams(axleForwardM: -1.6, sideOffsetM: -2.3, lengthM: 1.0, widthM: 0.45),
        frontLeftHub: WheelParams(axleForwardM: 3.0, sideOffsetM: 1.8, lengthM: 0.6, widthM: 0.33),
        frontRightHub: WheelParams(axleForwardM: 3.0, sideOffsetM: -1.8, lengthM: 0.6, widthM: 0.33),
        bodyColor: '#F5F5F5',
        hoodColor: '#BDBDBD',
        cabColor: '#78909C',
        borderColor: '#212121',
        cabBorderColor: '#FFFFFF',
        tireColor: '#37474F',
        hubColor: '#455A64',
      );

  /// Встроенный профиль «Мини» (компактный силуэт).
  static EquipmentProfile mini() => const EquipmentProfile(
        id: 'mini',
        name: 'Мини',
        bodyLengthM: 4.8,
        bodyWidthM: 2.8,
        bodyForwardOffsetM: -0.2,
        cabLengthM: 1.6,
        cabWidthM: 2.2,
        cabForwardOffsetM: 1.0,
        hoodLengthM: 1.8,
        hoodWidthM: 1.6,
        hoodForwardOffsetM: 2.6,
        rearLeftWheel: WheelParams(axleForwardM: -1.2, sideOffsetM: 1.5, lengthM: 1.5, widthM: 0.65),
        rearRightWheel: WheelParams(axleForwardM: -1.2, sideOffsetM: -1.5, lengthM: 1.5, widthM: 0.65),
        frontLeftWheel: WheelParams(axleForwardM: 2.0, sideOffsetM: 1.2, lengthM: 1.0, widthM: 0.5),
        frontRightWheel: WheelParams(axleForwardM: 2.0, sideOffsetM: -1.2, lengthM: 1.0, widthM: 0.5),
        rearLeftHub: WheelParams(axleForwardM: -1.2, sideOffsetM: 1.5, lengthM: 0.7, widthM: 0.32),
        rearRightHub: WheelParams(axleForwardM: -1.2, sideOffsetM: -1.5, lengthM: 0.7, widthM: 0.32),
        frontLeftHub: WheelParams(axleForwardM: 2.0, sideOffsetM: 1.2, lengthM: 0.45, widthM: 0.25),
        frontRightHub: WheelParams(axleForwardM: 2.0, sideOffsetM: -1.2, lengthM: 0.45, widthM: 0.25),
        bodyColor: '#FF8F00',
        hoodColor: '#FFB74D',
        cabColor: '#1565C0',
        borderColor: '#212121',
        cabBorderColor: '#FFFFFF',
        tireColor: '#212121',
        hubColor: '#757575',
      );

  /// Список встроенных профилей для выбора в UI.
  static List<EquipmentProfile> builtInList() => [
        farmer(),
        classic(),
        mini(),
      ];

  /// Найти встроенный профиль по id.
  static EquipmentProfile? findById(String id) {
    for (final p in builtInList()) {
      if (p.id == id) return p;
    }
    return null;
  }
}
