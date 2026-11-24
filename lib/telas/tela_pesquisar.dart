import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/catalogo_api.dart';
import 'package:lembrebem/backend/favoritos_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/modelo_alarme.dart' as modelo;
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_alarme.dart';
import 'package:lembrebem/telas/tela_config_alarme.dart';
import 'package:lembrebem/widgets/medicamento_detalhes.dart';
import 'package:lembrebem/widgets/skeleton_box.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TelaPesquisar extends StatefulWidget {
  const TelaPesquisar({super.key});

  @override
  State<TelaPesquisar> createState() => _TelaPesquisarState();
}

class _TelaPesquisarState extends State<TelaPesquisar> {
  final AlarmesApi _alarmesApi = AlarmesApi();
  final TextEditingController _buscaController = TextEditingController();
  final CatalogoApi _catalogoApi = CatalogoApi();
  final FavoritosApi _favoritosApi = FavoritosApi();

  Timer? _debounceBusca;
  String _textoBusca = '';
  bool _carregando = false;
  bool _jaBuscou = false;
  String? _erroBusca;
  List<Map<String, dynamic>> _resultados = [];
  Set<int> _idsFavoritos = {};
  bool _favoritosDisponiveis = true;
  Position? _posicaoAtual;

  String? get _usuarioId => SupabaseBackend.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _carregarFavoritos();
    _obterLocalizacao();
  }

  @override
  void dispose() {
    _debounceBusca?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarFavoritos() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) {
      return;
    }
    try {
      final ids = await _favoritosApi.listarIdsFavoritos(usuarioId: usuarioId);
      if (mounted) {
        setState(() {
          _idsFavoritos = ids;
          _favoritosDisponiveis = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _favoritosDisponiveis = false);
      }
    }
  }

  void _onChangeBusca(String valor) {
    _debounceBusca?.cancel();
    setState(() => _textoBusca = valor);

    final termo = valor.trim();
    if (termo.length < 2) {
      setState(() {
        _resultados = [];
        _jaBuscou = false;
        _carregando = false;
        _erroBusca = null;
      });
      return;
    }

    _debounceBusca = Timer(const Duration(milliseconds: 260), () {
      _buscar(termo);
    });
  }

  Future<void> _obterLocalizacao() async {
    try {
      final posicao = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _posicaoAtual = posicao;
        });
      }
    } catch (_) {}
  }

  Future<void> _buscar(String termo) async {
    setState(() {
      _carregando = true;
      _erroBusca = null;
    });

    try {
      final resultados = await _catalogoApi.buscarMedicamentosPorTermo(
        termo,
        limite: 24,
      );
      if (!mounted || _buscaController.text.trim() != termo) {
        return;
      }
      setState(() {
        _resultados = resultados;
        _carregando = false;
        _jaBuscou = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _carregando = false;
        _jaBuscou = true;
        _erroBusca = _mensagemErroBusca(e);
      });
    }
  }

  String _mensagemErroBusca(Object erro) {
    final texto = erro.toString().toLowerCase();
    if (texto.contains('failed host lookup') ||
        texto.contains('socketexception') ||
        texto.contains('network')) {
      return 'Sem internet no momento. Verifique sua conexão.';
    }
    return 'Falha ao buscar medicamentos.';
  }

  int? _idMedicamento(Map<String, dynamic> item) {
    final id = item['id'];
    if (id is int) {
      return id;
    }
    if (id is num) {
      return id.toInt();
    }
    return int.tryParse(id?.toString() ?? '');
  }

  Future<void> _alternarFavorito(Map<String, dynamic> item) async {
    final usuarioId = _usuarioId;
    final medicamentoId = _idMedicamento(item);
    if (usuarioId == null || medicamentoId == null) {
      return;
    }
    if (!_favoritosDisponiveis) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Favoritos indisponíveis. Rode o SQL no Supabase para ativar.',
          ),
        ),
      );
      return;
    }

    final favoritado = _idsFavoritos.contains(medicamentoId);
    setState(() {
      if (favoritado) {
        _idsFavoritos.remove(medicamentoId);
      } else {
        _idsFavoritos.add(medicamentoId);
      }
    });

    try {
      await _favoritosApi.alternarFavorito(
        usuarioId: usuarioId,
        medicamentoId: medicamentoId,
        favoritadoAtual: favoritado,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          if (favoritado) {
            _idsFavoritos.add(medicamentoId);
          } else {
            _idsFavoritos.remove(medicamentoId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar favorito.')),
        );
      }
    }
  }

  Future<void> _criarAlarmeComMedicamento(Map<String, dynamic> item) async {
    final nome = item['nome_produto']?.toString() ?? '';
    final novoAlarme = await Navigator.push<modelo.Alarme?>(
      context,
      MaterialPageRoute(
        builder:
            (_) => TelaConfigAlarme(
              medicamentoInicial: nome,
              medicamentoIdInicial: _idMedicamento(item),
            ),
      ),
    );

    if (novoAlarme == null || !mounted) {
      return;
    }

    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _alarmesApi.salvarNovoAlarme(
        nome: novoAlarme.nome,
        observacoes: novoAlarme.observacoes,
        horario: novoAlarme.horario,
        diasDeUso: novoAlarme.diasDeUso,
        ativado: novoAlarme.ativado,
        intervalo: novoAlarme.intervalo,
        usuarioId: user.id,
        medicamentoId: novoAlarme.medicamentoId,
        usuarioMedicamentoId: novoAlarme.usuarioMedicamentoId,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TelaAlarme()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o alarme.')),
        );
      }
    }
  }

  Future<void> _abrirDetalhes(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    Map<String, dynamic> completo = item;
    if (id != null) {
      try {
        final detalhes = await _catalogoApi.buscarMedicamentoPorId(id);
        if (detalhes != null) {
          completo = detalhes;
        }
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    MedicamentoDetalhesSheet.mostrar(context, medicamento: completo);
  }

  Future<void> _abrirGoogleMapsFarmacias() async {
    try {
      bool servicoLigado = await Geolocator.isLocationServiceEnabled();

      if (!servicoLigado) {
        throw Exception('Localização desligada');
      }

      LocationPermission permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        throw Exception('Permissão negada');
      }

      final posicao = await Geolocator.getCurrentPosition();

      final uri = Uri.parse(
        'https://www.google.com/maps/search/pharmacy/@'
        '${posicao.latitude},'
        '${posicao.longitude},15z',
      );

      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!abriu && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o mapa.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter sua localização.'),
          ),
        );
      }
    }
  }

  void _abrirModalMapaFarmacias() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Farmácias Próximas',
                style: TextStyle(
                  color: corPrimariaEscura,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Farmácias encontradas próximas à sua localização',
                style: TextStyle(color: corTextoCinza, fontSize: 13),
              ),

              const SizedBox(height: 16),

              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child:
                      _posicaoAtual == null
                          ? const Center(child: CircularProgressIndicator())
                          : FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                _posicaoAtual!.latitude,
                                _posicaoAtual!.longitude,
                              ),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      _posicaoAtual!.latitude,
                                      _posicaoAtual!.longitude,
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                ),
              ),

              const SizedBox(height: 10),

              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: corEmergencia, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Usando sua localização atual',
                    style: TextStyle(
                      color: Color(0xFF5A5A5A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              BotaoPrimario(
                texto: 'Abrir no Google Maps',
                cor: corPrimariaEscura,
                icone: Icons.open_in_new,
                onPressed: _abrirGoogleMapsFarmacias,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mostrandoResultados = _textoBusca.trim().length >= 2;

    return Scaffold(
      backgroundColor: corFundo,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ConteudoCentralizado(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        'Pesquisar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: corPrimariaEscura,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CampoComIcone(
                        controller: _buscaController,
                        dica: 'Digite o nome do medicamento...',
                        icone: Icons.search,
                        aoMudar: _onChangeBusca,
                      ),
                      const SizedBox(height: 18),
                      if (!mostrandoResultados) ...[
                        const Text(
                          'Digite o nome do medicamento desejado para '
                          'consultar dosagens ou localize farmácias próximas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: corTextoCinza,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _cardMapaFarmacias(),
                      ] else ...[
                        if (_carregando)
                          ..._skeletonResultados()
                        else if (_erroBusca != null)
                          CartaoBranco(
                            child: Column(
                              children: [
                                Text(
                                  _erroBusca!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: corTextoCinza,
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      () =>
                                          _buscar(_buscaController.text.trim()),
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          RotuloSecao(
                            'Resultados do catálogo (${_resultados.length})',
                            cor: corPrimariaEscura,
                          ),
                          const SizedBox(height: 10),
                          if (_jaBuscou && _resultados.isEmpty)
                            const CartaoBranco(
                              child: Text(
                                'Nenhum medicamento encontrado com esse nome.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: corTextoCinza,
                                ),
                              ),
                            )
                          else
                            ..._resultados.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _cardResultado(item),
                              ),
                            ),
                        ],
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            const BarraNavegacaoApp(ativa: AbaApp.pesquisar),
          ],
        ),
      ),
    );
  }

  List<Widget> _skeletonResultados() {
    return List.generate(
      4,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SkeletonBox(height: 84, radius: 14),
      ),
    );
  }

  Widget _cardMapaFarmacias() {
    return CartaoBranco(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child:
                  _posicaoAtual == null
                      ? const Center(child: CircularProgressIndicator())
                      : FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            _posicaoAtual!.latitude,
                            _posicaoAtual!.longitude,
                          ),
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _posicaoAtual!.latitude,
                                  _posicaoAtual!.longitude,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: corEmergencia,
                                  size: 35,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'MAPA DE FARMÁCIAS ATIVO',
            style: TextStyle(
              color: corPrimariaEscura,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Visualize farmácias próximas da sua localização',
            textAlign: TextAlign.center,
            style: TextStyle(color: corTextoCinza, fontSize: 12),
          ),
          const SizedBox(height: 14),
          BotaoPrimario(
            texto: 'Ver Farmácias Próximas',
            icone: Icons.location_on_outlined,
            onPressed: _abrirModalMapaFarmacias,
          ),
        ],
      ),
    );
  }

  Widget _cardResultado(Map<String, dynamic> item) {
    final nome = item['nome_produto']?.toString() ?? '';
    final dosagem = item['concentracao_dosagem']?.toString() ?? '';
    final apresentacao = item['apresentacao']?.toString() ?? '';
    final fabricante =
        item['fabricante']?.toString() ??
        item['empresa_detentora_registro']?.toString() ??
        '';
    final medicamentoId = _idMedicamento(item);
    final favoritado =
        medicamentoId != null && _idsFavoritos.contains(medicamentoId);

    final linhaDosagem = [
      if (dosagem.trim().isNotEmpty) dosagem.trim(),
      if (apresentacao.trim().isNotEmpty) apresentacao.trim(),
    ].join(' • ');

    return CartaoBranco(
      radius: 14,
      padding: const EdgeInsets.all(14),
      onTap: () => _abrirDetalhes(item),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: corFundo,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: corPrimariaEscura,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (linhaDosagem.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    linhaDosagem,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: corPrimariaEscura,
                    ),
                  ),
                ],
                if (fabricante.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fabricante,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: corTextoCinzaClaro,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _alternarFavorito(item),
            icon: Icon(
              favoritado ? Icons.favorite : Icons.favorite_border,
              color: favoritado ? corEmergencia : corTextoCinzaClaro,
              size: 24,
            ),
          ),
          GestureDetector(
            onTap: () => _criarAlarmeComMedicamento(item),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: corPrimaria,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
