class GuiaEventoStatus {
  final String id;
  final String eventoId;
  final String guiaId;

  /// 'pendente' | 'checkin_feito' | 'checkout_feito'
  final String status;

  /// Timestamp exato capturado no momento em que o guia tocou em "Fazer Check-in".
  final DateTime? checkinAt;

  /// Timestamp exato capturado no momento em que o guia tocou em "Fazer Check-out".
  final DateTime? checkoutAt;

  const GuiaEventoStatus({
    required this.id,
    required this.eventoId,
    required this.guiaId,
    required this.status,
    this.checkinAt,
    this.checkoutAt,
  });

  bool get isPendente => status == 'pendente';
  bool get isCheckinFeito => status == 'checkin_feito';
  bool get isCheckoutFeito => status == 'checkout_feito';

  factory GuiaEventoStatus.fromJson(Map<String, dynamic> json) {
    return GuiaEventoStatus(
      id: json['id'] as String,
      eventoId: json['evento_id'] as String,
      guiaId: json['guia_id'] as String,
      status: json['status'] as String? ?? 'pendente',
      checkinAt: json['checkin_at'] != null
          ? DateTime.parse(json['checkin_at'] as String)
          : null,
      checkoutAt: json['checkout_at'] != null
          ? DateTime.parse(json['checkout_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'evento_id': eventoId,
        'guia_id': guiaId,
        'status': status,
        'checkin_at': checkinAt?.toIso8601String(),
        'checkout_at': checkoutAt?.toIso8601String(),
      };
}
