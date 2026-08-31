class ServiceModel {
  final String id;
  final String barberId;
  final String name;
  final double price;
  final int duration;
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.barberId,
    required this.name,
    required this.price,
    required this.duration,
    required this.isActive,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: map['id']?.toString() ?? '',
      barberId: map['barber_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: double.tryParse(
            map['price']?.toString() ?? '0',
          ) ??
          0,
      duration: int.tryParse(
            map['duration']?.toString() ?? '30',
          ) ??
          30,
      isActive: map['is_active'] == true,
    );
  }
}