import 'package:flutter/material.dart';

class Alarme {
  String? id;
  String nome;
  String observacoes;
  TimeOfDay horario;
  String diasDeUso;
  bool ativado;
  String intervalo;
  int? medicamentoId;
  String? usuarioMedicamentoId;

  Alarme({
    this.id,
    required this.nome,
    required this.observacoes,
    required this.horario,
    required this.diasDeUso,
    required this.ativado,
    required this.intervalo,
    this.medicamentoId,
    this.usuarioMedicamentoId,
  });

  factory Alarme.fromJson(Map<String, dynamic> json) {
    final horaStr = json['hora_alarme'] ?? '00:00:00';
    final partes = horaStr.split(':');
    final hora = TimeOfDay(
      hour: int.parse(partes[0]),
      minute: int.parse(partes[1]),
    );
    return Alarme(
      id: json['id']?.toString() ?? '',
      nome: json['titulo'] ?? '',
      observacoes: json['descricao'] ?? '',
      horario: hora,
      diasDeUso: json['dias_uso'] ?? '',
      ativado: json['ativo'] ?? false,
      intervalo: json['intervalo'] ?? '',
      medicamentoId: json['medicamento_id'],
      usuarioMedicamentoId: json['usuario_medicamento_id']?.toString(),
    );
  }
}
