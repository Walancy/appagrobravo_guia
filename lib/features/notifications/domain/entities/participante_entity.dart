class ParticipanteEntity {
  final String id;
  final String nome;
  final String? foto;
  final bool isGuia;

  const ParticipanteEntity({
    required this.id,
    required this.nome,
    this.foto,
    this.isGuia = false,
  });
}
