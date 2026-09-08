import 'dart:convert';

import 'package:lembrebem/utils/normalizacao.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const String _catalogoMedicamentosKey =
      'cache_catalogo_medicamentos_v1';

  Future<void> salvarCatalogoMedicamentos(
    List<Map<String, dynamic>> medicamentos, {
    int limite = 600,
  }) async {
    if (medicamentos.isEmpty) {
      return;
    }

    final atual = await carregarCatalogoMedicamentos();
    final mesclado = _mesclarPorId(atual, medicamentos, limite: limite);

    await _salvarLista(_catalogoMedicamentosKey, mesclado);
  }

  Future<List<Map<String, dynamic>>> carregarCatalogoMedicamentos() async {
    return _carregarLista(_catalogoMedicamentosKey);
  }

  Future<Map<String, dynamic>?> buscarMedicamentoPorId(String id) async {
    final cache = await carregarCatalogoMedicamentos();
    for (final item in cache) {
      if (item['id']?.toString() == id) {
        return item;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> buscarMedicamentosNoCache(
    String termo, {
    int limite = 24,
  }) async {
    final termoNormalizado = normalizarTexto(termo.trim());
    if (termoNormalizado.isEmpty) {
      return const [];
    }

    final cache = await carregarCatalogoMedicamentos();
    final encontrados =
        cache.where((item) {
          final nome = normalizarTexto(item['nome_produto']?.toString() ?? '');
          final nomeNorm = normalizarTexto(
            item['nome_produto_normalizado']?.toString() ?? '',
          );
          final principio = normalizarTexto(
            item['principio_ativo']?.toString() ?? '',
          );
          final fabricante = normalizarTexto(
            item['fabricante']?.toString() ??
                item['empresa_detentora_registro']?.toString() ??
                '',
          );
          final registro = normalizarTexto(
            item['registro']?.toString() ??
                item['numero_registro']?.toString() ??
                '',
          );
          final apresentacao = normalizarTexto(
            item['apresentacao']?.toString() ?? '',
          );
          final dosagem = normalizarTexto(
            item['concentracao_dosagem']?.toString() ?? '',
          );
          final classe = normalizarTexto(
            item['classe_terapeutica']?.toString() ?? '',
          );
          final tipoMedicamento = normalizarTexto(
            item['tipo_medicamento']?.toString() ??
                item['tipo_produto']?.toString() ??
                '',
          );
          final ean = normalizarTexto(item['ean']?.toString() ?? '');
          final pmc = normalizarTexto(item['pmc']?.toString() ?? '');

          return nome.contains(termoNormalizado) ||
              nomeNorm.contains(termoNormalizado) ||
              principio.contains(termoNormalizado) ||
              fabricante.contains(termoNormalizado) ||
              registro.contains(termoNormalizado) ||
              apresentacao.contains(termoNormalizado) ||
              dosagem.contains(termoNormalizado) ||
              classe.contains(termoNormalizado) ||
              tipoMedicamento.contains(termoNormalizado) ||
              ean.contains(termoNormalizado) ||
              pmc.contains(termoNormalizado);
        }).toList();

    encontrados.sort((a, b) {
      final scoreA = _pontuarMedicamentoCache(a, termoNormalizado);
      final scoreB = _pontuarMedicamentoCache(b, termoNormalizado);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      final nomeA = (a['nome_produto'] ?? '').toString();
      final nomeB = (b['nome_produto'] ?? '').toString();
      return nomeA.compareTo(nomeB);
    });

    return encontrados.take(limite).toList();
  }

  Future<void> salvarAlarmesUsuario(
    String usuarioId,
    List<Map<String, dynamic>> alarmes,
  ) async {
    final key = _alarmesKey(usuarioId);
    await _salvarLista(key, alarmes);
  }

  Future<List<Map<String, dynamic>>> carregarAlarmesUsuario(
    String usuarioId,
  ) async {
    return _carregarLista(_alarmesKey(usuarioId));
  }

  Future<void> upsertAlarmeUsuario(
    String usuarioId,
    Map<String, dynamic> alarme,
  ) async {
    final atual = await carregarAlarmesUsuario(usuarioId);
    final mesclado = _mesclarPorId(atual, [alarme], limite: 400);
    await _salvarLista(_alarmesKey(usuarioId), mesclado);
  }

  Future<void> removerAlarmeUsuario(String usuarioId, String alarmeId) async {
    final atual = await carregarAlarmesUsuario(usuarioId);
    atual.removeWhere((item) => item['id']?.toString() == alarmeId);
    await _salvarLista(_alarmesKey(usuarioId), atual);
  }

  Future<void> alternarStatusAlarmeUsuario(
    String usuarioId,
    String alarmeId,
    bool ativo,
  ) async {
    final atual = await carregarAlarmesUsuario(usuarioId);
    for (final item in atual) {
      if (item['id']?.toString() == alarmeId) {
        item['ativo'] = ativo;
      }
    }
    await _salvarLista(_alarmesKey(usuarioId), atual);
  }

  Future<void> salvarUsuarioMedicamentos(
    String usuarioId,
    List<Map<String, dynamic>> itens,
  ) async {
    final key = _usuarioMedicamentosKey(usuarioId);
    await _salvarLista(key, itens);
  }

  Future<List<Map<String, dynamic>>> carregarUsuarioMedicamentos(
    String usuarioId,
  ) async {
    return _carregarLista(_usuarioMedicamentosKey(usuarioId));
  }

  Future<void> upsertUsuarioMedicamento(
    String usuarioId,
    Map<String, dynamic> item,
  ) async {
    final atual = await carregarUsuarioMedicamentos(usuarioId);
    final mesclado = _mesclarPorId(atual, [item], limite: 500);
    await _salvarLista(_usuarioMedicamentosKey(usuarioId), mesclado);
  }

  Future<void> removerUsuarioMedicamento(
    String usuarioId,
    String usuarioMedicamentoId,
  ) async {
    final atual = await carregarUsuarioMedicamentos(usuarioId);
    atual.removeWhere((item) => item['id']?.toString() == usuarioMedicamentoId);
    await _salvarLista(_usuarioMedicamentosKey(usuarioId), atual);
  }

  Future<void> removerUsuarioMedicamentoPorMedicamentoId(
    String usuarioId,
    int medicamentoId,
  ) async {
    final atual = await carregarUsuarioMedicamentos(usuarioId);
    atual.removeWhere((item) {
      final valor = item['medicamento_id'];
      if (valor is num) {
        return valor.toInt() == medicamentoId;
      }
      return valor?.toString() == medicamentoId.toString();
    });
    await _salvarLista(_usuarioMedicamentosKey(usuarioId), atual);
  }

  Future<void> _salvarLista(
    String key,
    List<Map<String, dynamic>> itens,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(itens));
  }

  Future<List<Map<String, dynamic>>> _carregarLista(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final data = jsonDecode(raw);
      if (data is! List) {
        return [];
      }
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _mesclarPorId(
    List<Map<String, dynamic>> atual,
    List<Map<String, dynamic>> novos, {
    required int limite,
  }) {
    final mesclado = <Map<String, dynamic>>[];
    final vistos = <String>{};

    for (final item in [...novos, ...atual]) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }
      if (vistos.add(id)) {
        mesclado.add(Map<String, dynamic>.from(item));
      }
      if (mesclado.length >= limite) {
        break;
      }
    }

    return mesclado;
  }

  int _pontuarMedicamentoCache(
    Map<String, dynamic> item,
    String termoNormalizado,
  ) {
    final nome = normalizarTexto(item['nome_produto']?.toString() ?? '');
    final principio = normalizarTexto(
      item['principio_ativo']?.toString() ?? '',
    );
    final fabricante = normalizarTexto(
      item['fabricante']?.toString() ??
          item['empresa_detentora_registro']?.toString() ??
          '',
    );
    final registro = normalizarTexto(
      item['registro']?.toString() ?? item['numero_registro']?.toString() ?? '',
    );
    final apresentacao = normalizarTexto(
      item['apresentacao']?.toString() ?? '',
    );
    final dosagem = normalizarTexto(
      item['concentracao_dosagem']?.toString() ?? '',
    );
    final classe = normalizarTexto(
      item['classe_terapeutica']?.toString() ?? '',
    );
    final tipoMedicamento = normalizarTexto(
      item['tipo_medicamento']?.toString() ??
          item['tipo_produto']?.toString() ??
          '',
    );
    final ean = normalizarTexto(item['ean']?.toString() ?? '');
    final pmc = normalizarTexto(item['pmc']?.toString() ?? '');

    var score = 0;
    if (nome == termoNormalizado) {
      score += 1000;
    }
    if (nome.startsWith(termoNormalizado)) {
      score += 700;
    }
    if (nome.contains(termoNormalizado)) {
      score += 450;
    }
    if (principio.startsWith(termoNormalizado)) {
      score += 260;
    } else if (principio.contains(termoNormalizado)) {
      score += 160;
    }
    if (fabricante.contains(termoNormalizado)) {
      score += 120;
    }
    if (registro.contains(termoNormalizado)) {
      score += 200;
    }
    if (apresentacao.contains(termoNormalizado)) {
      score += 110;
    }
    if (dosagem.contains(termoNormalizado)) {
      score += 160;
    }
    if (classe.contains(termoNormalizado)) {
      score += 150;
    }
    if (tipoMedicamento.contains(termoNormalizado)) {
      score += 120;
    }
    if (ean == termoNormalizado) {
      score += 250;
    }
    if (pmc.contains(termoNormalizado)) {
      score += 90;
    }
    return score;
  }

  String _alarmesKey(String usuarioId) => 'cache_alarmes_$usuarioId';

  String _usuarioMedicamentosKey(String usuarioId) =>
      'cache_usuario_medicamentos_$usuarioId';
}
