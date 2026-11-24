import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lembrebem/backend/catalogo_api.dart';
import 'package:lembrebem/backend/local_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requisicoes = <http.Request>[];
  final cache = LocalCache();
  late http.Response resposta;

  http.Response respostaJson(Object dados, {int status = 200}) {
    return http.Response(
      jsonEncode(dados),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://catalogo.example.invalid',
      anonKey: 'chave-publica-ficticia-para-testes',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      debug: false,
      httpClient: MockClient((requisicao) async {
        requisicoes.add(requisicao);
        return http.Response(
          resposta.body,
          resposta.statusCode,
          headers: resposta.headers,
          request: requisicao,
        );
      }),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requisicoes.clear();
    resposta = respostaJson({
      'code': 'CATALOGO_INDISPONIVEL',
      'message': 'Falha simulada na consulta ao catalogo.',
    }, status: 400);
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  test('Lista pelo Supabase e guarda o resultado para uso offline', () async {
    resposta = respostaJson([
      {'id': 101, 'nome_produto': 'Medicamento online', 'pmc': 10},
    ]);

    final itens = await CatalogoApi().listarMedicamentos(limite: 5);

    expect(itens.single['id'], 101);
    expect(requisicoes, hasLength(1));
    expect(requisicoes.single.url.host, 'catalogo.example.invalid');
    expect(requisicoes.single.url.path, '/rest/v1/medicamentos');
    expect(requisicoes.single.headers['Accept-Profile'], 'catalogo');
    expect(requisicoes.single.url.queryParameters['limit'], '5');
    expect((await cache.carregarCatalogoMedicamentos()).single['id'], 101);
  });

  test('Falha na listagem retorna os medicamentos do cache local', () async {
    final salvo = {'id': 201, 'nome_produto': 'Medicamento salvo'};
    await cache.salvarCatalogoMedicamentos([salvo]);

    expect(await CatalogoApi().listarMedicamentos(), [salvo]);
    expect(requisicoes, hasLength(1));
  });

  test('Busca por termo continua funcionando com dados offline', () async {
    await cache.salvarCatalogoMedicamentos([
      {'id': 301, 'nome_produto': 'Medicamento busca local'},
      {'id': 302, 'nome_produto': 'Outro medicamento'},
    ]);

    final itens = await CatalogoApi().buscarMedicamentosPorTermo('busca local');

    expect(itens.map((item) => item['id']), [301]);
    expect(requisicoes, hasLength(1));
  });

  test('Busca sem cache preserva o erro original do Supabase', () async {
    await expectLater(
      CatalogoApi().buscarMedicamentosPorTermo('termo inexistente'),
      throwsA(
        isA<PostgrestException>().having(
          (erro) => erro.code,
          'code',
          'CATALOGO_INDISPONIVEL',
        ),
      ),
    );
    expect(requisicoes, hasLength(1));
  });

  test('Detalhe por ID continua disponivel pelo cache offline', () async {
    final salvo = {'id': 401, 'nome_produto': 'Detalhe salvo'};
    await cache.salvarCatalogoMedicamentos([salvo]);

    expect(await CatalogoApi().buscarMedicamentoPorId('401'), salvo);
    expect(requisicoes, hasLength(1));
  });

  test('Busca por varios IDs recupera e normaliza os dados offline', () async {
    await cache.salvarCatalogoMedicamentos([
      {
        'id': 501,
        'nome_produto': 'Primeiro',
        'principios_ativos': 'Composto A',
      },
      {'id': 502, 'nome_produto': 'Segundo'},
      {'id': 503, 'nome_produto': 'Nao solicitado'},
    ]);

    final itens = await CatalogoApi().buscarMedicamentosPorIds(['501', '502']);

    expect(itens.keys, unorderedEquals(['501', '502']));
    expect(itens['501']!['principio_ativo'], 'Composto A');
    expect(requisicoes, hasLength(1));
  });

  test('Entradas vazias nao fazem consultas de rede', () async {
    final api = CatalogoApi();

    expect(await api.buscarMedicamentosPorTermo('a'), isEmpty);
    expect(await api.buscarMedicamentoPorId(''), isNull);
    expect(await api.buscarMedicamentosPorIds([]), isEmpty);
    expect(requisicoes, isEmpty);
  });
}
