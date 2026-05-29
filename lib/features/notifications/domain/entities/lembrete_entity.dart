class LembreteEntity {
  final String id;
  final String grupoId;
  final String? missaoId;
  final String criadoPor;
  final String titulo;
  final String mensagem;
  final List<String>? destinatarios; // null = enviado para todos
  final int totalDestinatarios;
  final String status; // 'agendado' | 'enviado' | 'cancelado'
  final DateTime createdAt;
  final DateTime? agendadoPara;
  final DateTime? processadoEm;

  const LembreteEntity({
    required this.id,
    required this.grupoId,
    this.missaoId,
    required this.criadoPor,
    required this.titulo,
    required this.mensagem,
    this.destinatarios,
    required this.totalDestinatarios,
    required this.status,
    required this.createdAt,
    this.agendadoPara,
    this.processadoEm,
  });

  bool get isAgendado => status == 'agendado';
  bool get isEnviado => status == 'enviado';
  bool get isCancelado => status == 'cancelado';
}

