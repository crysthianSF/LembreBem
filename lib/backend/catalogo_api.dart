import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lembrebem/backend/catalogo_api_local_config.dart';
import 'package:lembrebem/backend/local_cache.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/utils/normalizacao.dart';

class CatalogoApi {
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const String _catalogoApiUrlFromEnv = String.fromEnvironment(
    'CATALOGO_API_URL',
  );
  static const String _camposResumoMedicamento =
      'id,medicamento_id,codigo_ggrem,registro,nome_produto,'
      'nome_produto_normalizado,principio_ativo,principio_ativo_normalizado,'
      'principios_ativos,fabricante,empresa_detentora_registro,'
      'fabricante_normalizado,apresentacao,apresentacao_normalizada,'
      'concentracao_dosagem,unidade,classe_terapeutica,tipo_produto,'
      'tipo_medicamento,regime_preco,ean,ean_1,ean_2,ean_3,pf,pmc,preco,'
      'tarja';
  static const int _maxBuscasEmMemoria = 40;
  static const int _maxDetalhesEmMemoria = 180;
  static final Map<String, List<Map<String, dynamic>>> _cacheBuscasMemoria = {};
  static final Map<String, Map<String, dynamic>> _cacheDetalhesMemoria = {};

  final LocalCache _localCache = LocalCache();
  final http.Client _clienteHttp = http.Client();

  String get _baseUrlApiLocal {
    final urlBase =
        _catalogoApiUrlFromEnv.trim().isNotEmpty
            ? _catalogoApiUrlFromEnv.trim()
            : localCatalogoApiUrl.trim();

    return urlBase.replaceAll(RegExp(r'/$'), '');
  }

  bool get _apiLocalDisponivel => _baseUrlApiLocal.isNotEmpty;

  Future<List<Map<String, dynamic>>> listarMedicamentos({
    int limite = 100,
  }) async {
    try {
      final itens = await _listarMedicamentosViaSupabase(limite: limite);
      await _localCache.salvarCatalogoMedicamentos(itens);
      return itens;
    } catch (_) {
      try {
        final itens = await _listarMedicamentosViaApiLocal(limite: limite);
        await _localCache.salvarCatalogoMedicamentos(itens);
        return itens;
      } catch (_) {
        return _localCache.carregarCatalogoMedicamentos();
      }
    }
  }

  Future<List<Map<String, dynamic>>> buscarMedicamentosPorTermo(
    String termo, {
    int limite = 10,
  }) async {
    final termoLimpo = termo.trim();
    if (termoLimpo.length < 2) {
      return const [];
    }

    final chaveBusca = _chaveBusca(termoLimpo, limite);
    final buscaEmMemoria = _buscarBuscaEmMemoria(chaveBusca);
    if (buscaEmMemoria != null) {
      return buscaEmMemoria;
    }

    try {
      final resultados = await _buscarMedicamentosViaSupabase(
        termoLimpo,
        limite: limite,
      );
      await _localCache.salvarCatalogoMedicamentos(resultados);
      _salvarBuscaEmMemoria(chaveBusca, resultados);
      return resultados;
    } catch (_) {
      try {
        final resultados = await _buscarMedicamentosViaApiLocal(
          termoLimpo,
          limite: limite,
        );
        await _localCache.salvarCatalogoMedicamentos(resultados);
        _salvarBuscaEmMemoria(chaveBusca, resultados);
        return resultados;
      } catch (_) {
        final resultadosCache = await _localCache.buscarMedicamentosNoCache(
          termoLimpo,
          limite: limite,
        );
        if (resultadosCache.isEmpty) {
          rethrow;
        }
        _salvarBuscaEmMemoria(chaveBusca, resultadosCache);
        return resultadosCache;
      }
    }
  }

  Future<Map<String, dynamic>?> buscarMedicamentoPorId(String id) async {
    final idLimpo = id.trim();
    if (idLimpo.isEmpty) {
      return null;
    }

    final detalheEmMemoria = _buscarDetalheEmMemoria(idLimpo);
    if (detalheEmMemoria != null) {
      return detalheEmMemoria;
    }

    try {
      final medicamento = await _buscarMedicamentoPorIdViaSupabase(idLimpo);
      if (medicamento != null) {
        await _localCache.salvarCatalogoMedicamentos([medicamento]);
        _salvarDetalheEmMemoria(medicamento);
      }
      return medicamento;
    } catch (_) {
      try {
        final medicamento = await _buscarMedicamentoPorIdViaApiLocal(idLimpo);
        if (medicamento != null) {
          await _localCache.salvarCatalogoMedicamentos([medicamento]);
          _salvarDetalheEmMemoria(medicamento);
        }
        return medicamento;
      } catch (_) {
        final medicamentoCache = await _localCache.buscarMedicamentoPorId(
          idLimpo,
        );
        if (medicamentoCache != null) {
          _salvarDetalheEmMemoria(medicamentoCache);
        }
        return medicamentoCache;
      }
    }
  }

  Future<Map<String, Map<String, dynamic>>> buscarMedicamentosPorIds(
    List<String> ids,
  ) async {
    final idsLimpos =
        ids
            .map((id) => _somenteDigitos(id))
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    if (idsLimpos.isEmpty) {
      return const {};
    }

    final encontrados = <String, Map<String, dynamic>>{};
    final faltantes = <String>[];

    for (final id in idsLimpos) {
      final detalhe = _buscarDetalheEmMemoria(id);
      if (detalhe != null) {
        encontrados[id] = detalhe;
      } else {
        faltantes.add(id);
      }
    }

    if (faltantes.isEmpty) {
      return encontrados;
    }

    try {
      final itens = await _buscarMedicamentosPorIdsViaSupabase(faltantes);
      for (final item in itens) {
        final id = item['id']?.toString();
        if (id == null || id.isEmpty) {
          continue;
        }
        encontrados[id] = item;
      }
      if (itens.isNotEmpty) {
        await _localCache.salvarCatalogoMedicamentos(itens);
        _salvarDetalhesEmMemoria(itens);
      }
      return encontrados;
    } catch (_) {
      try {
        final itens = await _buscarMedicamentosPorIdsViaApiLocal(faltantes);
        for (final item in itens) {
          final id = item['id']?.toString();
          if (id == null || id.isEmpty) {
            continue;
          }
          encontrados[id] = item;
        }
        if (itens.isNotEmpty) {
          await _localCache.salvarCatalogoMedicamentos(itens);
          _salvarDetalhesEmMemoria(itens);
        }
        return encontrados;
      } catch (_) {
        final cache = await _localCache.carregarCatalogoMedicamentos();
        for (final item in cache) {
          final id = item['id']?.toString();
          if (id == null || id.isEmpty || !faltantes.contains(id)) {
            continue;
          }
          final normalizado = _normalizarMedicamento(item);
          encontrados[id] = normalizado;
          _salvarDetalheEmMemoria(normalizado);
        }
      }
    }

    final faltantesFinais =
        idsLimpos.where((id) => !encontrados.containsKey(id)).toList();
    if (faltantesFinais.isNotEmpty) {
      final itens = await Future.wait(
        faltantesFinais.map(buscarMedicamentoPorId),
      );
      for (final item in itens) {
        if (item == null) {
          continue;
        }
        final id = item['id']?.toString();
        if (id == null || id.isEmpty) {
          continue;
        }
        encontrados[id] = item;
      }
    }

    return encontrados;
  }

  Future<List<Map<String, dynamic>>> _listarMedicamentosViaSupabase({
    required int limite,
  }) async {
    final response = await SupabaseBackend.catalogoSchema
        .from('medicamentos')
        .select(_camposResumoMedicamento)
        .order('nome_produto', ascending: true)
        .order('apresentacao', ascending: true)
        .limit(limite)
        .timeout(_requestTimeout);

    final lista = response as List;
    return lista
        .whereType<Map>()
        .map((item) => _normalizarMedicamento(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _buscarMedicamentosViaSupabase(
    String termo, {
    required int limite,
  }) async {
    final termoSanitizado = _sanitizarTermo(termo);
    final termoNormalizado = normalizarTexto(termoSanitizado);
    final termoDigitos = _somenteDigitos(termoSanitizado);
    final limiteExpandido = limite <= 10 ? 20 : limite * 4;

    final condicoes = <String>[
      'nome_produto_normalizado.ilike.*$termoNormalizado*',
      'principio_ativo_normalizado.ilike.*$termoNormalizado*',
      'apresentacao_normalizada.ilike.*$termoNormalizado*',
      'fabricante_normalizado.ilike.*$termoNormalizado*',
      'concentracao_dosagem.ilike.*$termoNormalizado*',
      'classe_terapeutica.ilike.*$termoNormalizado*',
      'tipo_medicamento.ilike.*$termoNormalizado*',
    ];

    if (termoDigitos.isNotEmpty) {
      condicoes.addAll([
        'registro.ilike.*$termoDigitos*',
        'codigo_ggrem.ilike.*$termoDigitos*',
        'ean.eq.$termoDigitos',
        'ean_1.eq.$termoDigitos',
        'ean_2.eq.$termoDigitos',
        'ean_3.eq.$termoDigitos',
      ]);
    }

    final response = await SupabaseBackend.catalogoSchema
        .from('medicamentos')
        .select(_camposResumoMedicamento)
        .or(condicoes.join(','))
        .limit(limiteExpandido)
        .timeout(_requestTimeout);

    final lista =
        (response as List)
            .whereType<Map>()
            .map((item) => _normalizarMedicamento(item))
            .toList();

    lista.sort((a, b) {
      final scoreA = _pontuarMedicamento(a, termoSanitizado);
      final scoreB = _pontuarMedicamento(b, termoSanitizado);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      final nomeA = _texto(a['nome_produto']);
      final nomeB = _texto(b['nome_produto']);
      return nomeA.compareTo(nomeB);
    });

    return lista.take(limite).toList();
  }

  Future<Map<String, dynamic>?> _buscarMedicamentoPorIdViaSupabase(
    String id,
  ) async {
    final response = await SupabaseBackend.catalogoSchema
        .from('medicamentos')
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(_requestTimeout);

    if (response == null) {
      return null;
    }

    return _normalizarMedicamento(response as Map);
  }

  Future<List<Map<String, dynamic>>> _buscarMedicamentosPorIdsViaSupabase(
    List<String> ids,
  ) async {
    final idsLimpos =
        ids.map(_somenteDigitos).where((id) => id.isNotEmpty).toSet().toList();
    if (idsLimpos.isEmpty) {
      return const [];
    }

    final response = await SupabaseBackend.catalogoSchema
        .from('medicamentos')
        .select(_camposResumoMedicamento)
        .inFilter('id', idsLimpos)
        .timeout(_requestTimeout);

    return (response as List)
        .whereType<Map>()
        .map((item) => _normalizarMedicamento(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _listarMedicamentosViaApiLocal({
    required int limite,
  }) async {
    if (!_apiLocalDisponivel) {
      throw StateError('API local do catalogo nao configurada.');
    }

    final response = await _getJsonApiLocal(
      '/api/medicamentos',
      queryParameters: {'limite': '$limite'},
    );
    return _extrairListaApi(response);
  }

  Future<List<Map<String, dynamic>>> _buscarMedicamentosViaApiLocal(
    String termo, {
    required int limite,
  }) async {
    if (!_apiLocalDisponivel) {
      throw StateError('API local do catalogo nao configurada.');
    }

    final response = await _getJsonApiLocal(
      '/api/medicamentos/busca',
      queryParameters: {'termo': _sanitizarTermo(termo), 'limite': '$limite'},
    );
    return _extrairListaApi(response);
  }

  Future<Map<String, dynamic>?> _buscarMedicamentoPorIdViaApiLocal(
    String id,
  ) async {
    if (!_apiLocalDisponivel) {
      throw StateError('API local do catalogo nao configurada.');
    }

    final response = await _getJsonApiLocal('/api/medicamentos/$id');
    return _extrairObjetoApi(response);
  }

  Future<List<Map<String, dynamic>>> _buscarMedicamentosPorIdsViaApiLocal(
    List<String> ids,
  ) async {
    if (!_apiLocalDisponivel) {
      throw StateError('API local do catalogo nao configurada.');
    }

    final idsLimpos =
        ids.map(_somenteDigitos).where((id) => id.isNotEmpty).toSet().toList();
    if (idsLimpos.isEmpty) {
      return const [];
    }

    final response = await _getJsonApiLocal(
      '/api/medicamentos/ids',
      queryParameters: {'ids': idsLimpos.join(',')},
    );
    return _extrairListaApi(response);
  }

  Future<dynamic> _getJsonApiLocal(
    String caminho, {
    Map<String, String?> queryParameters = const {},
  }) async {
    final query = <String, String>{};
    for (final entry in queryParameters.entries) {
      final valor = entry.value;
      if (valor == null || valor.trim().isEmpty) {
        continue;
      }
      query[entry.key] = valor;
    }

    final uri = Uri.parse(
      '$_baseUrlApiLocal$caminho',
    ).replace(queryParameters: query);
    final response = await _clienteHttp.get(uri).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Falha ao consultar catalogo. HTTP ${response.statusCode}: ${response.body}',
      );
    }

    if (response.body.trim().isEmpty) {
      return const {};
    }

    return jsonDecode(response.body);
  }

  List<Map<String, dynamic>> _extrairListaApi(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => _normalizarMedicamento(item))
          .toList();
    }

    if (response is Map && response['dados'] is List) {
      final lista = response['dados'] as List;
      return lista
          .whereType<Map>()
          .map((item) => _normalizarMedicamento(item))
          .toList();
    }

    return const [];
  }

  Map<String, dynamic>? _extrairObjetoApi(dynamic response) {
    if (response is Map && response['dado'] is Map) {
      return _normalizarMedicamento(response['dado'] as Map);
    }

    if (response is Map && response.isNotEmpty) {
      return _normalizarMedicamento(response);
    }

    return null;
  }

  String _chaveBusca(String termo, int limite) {
    return '${normalizarTexto(termo)}|$limite';
  }

  List<Map<String, dynamic>>? _buscarBuscaEmMemoria(String chave) {
    final busca = _cacheBuscasMemoria[chave];
    if (busca == null || busca.isEmpty) {
      return null;
    }

    return busca.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  void _salvarBuscaEmMemoria(
    String chave,
    List<Map<String, dynamic>> resultados,
  ) {
    _cacheBuscasMemoria.remove(chave);
    _cacheBuscasMemoria[chave] =
        resultados.map((item) => Map<String, dynamic>.from(item)).toList();

    while (_cacheBuscasMemoria.length > _maxBuscasEmMemoria) {
      _cacheBuscasMemoria.remove(_cacheBuscasMemoria.keys.first);
    }

    _salvarDetalhesEmMemoria(resultados);
  }

  Map<String, dynamic>? _buscarDetalheEmMemoria(String id) {
    final detalhe = _cacheDetalhesMemoria[id];
    if (detalhe == null) {
      return null;
    }
    return Map<String, dynamic>.from(detalhe);
  }

  void _salvarDetalhesEmMemoria(Iterable<Map<String, dynamic>> itens) {
    for (final item in itens) {
      _salvarDetalheEmMemoria(item);
    }
  }

  void _salvarDetalheEmMemoria(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }

    _cacheDetalhesMemoria.remove(id);
    _cacheDetalhesMemoria[id] = Map<String, dynamic>.from(item);

    while (_cacheDetalhesMemoria.length > _maxDetalhesEmMemoria) {
      _cacheDetalhesMemoria.remove(_cacheDetalhesMemoria.keys.first);
    }
  }

  int _pontuarMedicamento(Map<String, dynamic> item, String termo) {
    final termoNormalizado = normalizarTexto(termo);
    final termoDigitos = _somenteDigitos(termo);
    final nome = normalizarTexto(_texto(item['nome_produto']));
    final principio = normalizarTexto(_texto(item['principio_ativo']));
    final apresentacao = normalizarTexto(_texto(item['apresentacao']));
    final dosagem = normalizarTexto(_texto(item['concentracao_dosagem']));
    final classe = normalizarTexto(_texto(item['classe_terapeutica']));
    final tipoMedicamento = normalizarTexto(_texto(item['tipo_medicamento']));
    final fabricante = normalizarTexto(_texto(item['fabricante']));
    final registro = _texto(item['registro']);
    final ean = _texto(item['ean']);
    final pmcDigitos = _somenteDigitos(_texto(item['pmc']));

    var score = 0;

    if (nome == termoNormalizado) {
      score += 1200;
    }
    if (nome.startsWith(termoNormalizado)) {
      score += 900;
    }
    if (nome.contains(termoNormalizado)) {
      score += 600;
    }
    if (principio.startsWith(termoNormalizado)) {
      score += 400;
    } else if (principio.contains(termoNormalizado)) {
      score += 260;
    }
    if (apresentacao.contains(termoNormalizado)) {
      score += 220;
    }
    if (dosagem.contains(termoNormalizado)) {
      score += 240;
    }
    if (classe.contains(termoNormalizado)) {
      score += 210;
    }
    if (tipoMedicamento.contains(termoNormalizado)) {
      score += 180;
    }
    if (fabricante.contains(termoNormalizado)) {
      score += 180;
    }
    if (termoDigitos.isNotEmpty && registro.contains(termoDigitos)) {
      score += 540;
    }
    if (termoDigitos.isNotEmpty && ean == termoDigitos) {
      score += 800;
    }
    if (termoDigitos.isNotEmpty && pmcDigitos.contains(termoDigitos)) {
      score += 120;
    }
    if (item['pmc'] != null) {
      score += 20;
    }

    return score;
  }

  String _sanitizarTermo(String termo) {
    return termo
        .replaceAll(',', ' ')
        .replaceAll('%', '')
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll("'", ' ')
        .replaceAll('"', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _somenteDigitos(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _texto(dynamic valor) {
    if (valor == null) {
      return '';
    }
    return valor.toString().trim();
  }

  Map<String, dynamic> _normalizarMedicamento(Map item) {
    final medicamento = Map<String, dynamic>.from(item);
    final registro =
        medicamento['registro']?.toString() ??
        medicamento['numero_registro']?.toString() ??
        '';
    final fabricante =
        medicamento['fabricante']?.toString() ??
        medicamento['empresa_detentora_registro']?.toString() ??
        '';
    final tipoProduto =
        medicamento['tipo_produto']?.toString() ??
        medicamento['categoria_regulatoria']?.toString() ??
        '';
    final principio =
        medicamento['principio_ativo']?.toString() ??
        medicamento['principios_ativos']?.toString() ??
        '';

    return {
      ...medicamento,
      'numero_registro': registro,
      'registro': registro,
      'fabricante': fabricante,
      'empresa_detentora_registro': fabricante,
      'tipo_produto': tipoProduto,
      'categoria_regulatoria':
          medicamento['categoria_regulatoria'] ?? tipoProduto,
      'principio_ativo': principio,
      'nome_produto_normalizado':
          medicamento['nome_produto_normalizado'] ??
          medicamento['nome_produto']?.toString().toLowerCase(),
      'ean':
          medicamento['ean'] ??
          medicamento['ean_1'] ??
          medicamento['ean_2'] ??
          medicamento['ean_3'],
      'preco': medicamento['preco'] ?? medicamento['pmc'] ?? medicamento['pf'],
      'situacao_registro': medicamento['situacao_registro']?.toString() ?? '',
    };
  }
}
