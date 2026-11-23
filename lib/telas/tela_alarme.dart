import 'package:flutter/material.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/servico_alarme.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/modelo_alarme.dart' as modelo;
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_config_alarme.dart';
import 'package:lembrebem/widgets/skeleton_box.dart';
import 'package:lembrebem/widgets/componentes.dart';

class TelaAlarme extends StatefulWidget {
  const TelaAlarme({super.key});

  @override
  State<TelaAlarme> createState() => _TelaAlarmeState();
}

class _TelaAlarmeState extends State<TelaAlarme> {
  final AlarmesApi _alarmesApi = AlarmesApi();
  List<modelo.Alarme> alarmeList = [];
  final appApi = AppApi();
  bool _carregando = true;
  String? _erro;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    buscarAlarmes();
  }

  Future<void> buscarAlarmes() async {
    final userId = SupabaseBackend.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = 'Usuario nao autenticado.';
        });
      }
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final response = await appApi.listarAlarmesDoUsuario(usuarioId: userId);

      if (!mounted) {
        return;
      }
      setState(() {
        alarmeList =
            response.map((json) => modelo.Alarme.fromJson(json)).toList();
        _carregando = false;
      });
      ServicoAlarme.instancia.definirAlarmesAtivos(alarmeList);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erro = _mensagemErroAlarme(e);
        _carregando = false;
      });
    }
  }

  Future<T> _executarComRetry<T>(
    Future<T> Function() acao, {
    int tentativas = 2,
    Duration intervalo = const Duration(milliseconds: 900),
  }) async {
    Object? ultimoErro;
    for (var i = 0; i < tentativas; i++) {
      try {
        return await acao();
      } catch (e) {
        ultimoErro = e;
        if (i < tentativas - 1) {
          await Future.delayed(intervalo);
        }
      }
    }
    throw ultimoErro ?? StateError('Falha na operacao.');
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: const Color(0xFF1B8F45),
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: const Color(0xFFC0392B),
      ),
    );
  }

  Widget containerAlarme(modelo.Alarme alarme, int index) {
    return GestureDetector(
      onTap: () async {
        final alarmeEditado = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaConfigAlarme(alarme: alarme),
          ),
        );

        if (alarmeEditado != null && mounted) {
          if (alarme.id == null || alarme.id!.isEmpty) {
            return;
          }
          try {
            await _executarComRetry(() {
              return _alarmesApi.atualizarAlarme(
                id: alarme.id!,
                nome: alarmeEditado.nome,
                observacoes: alarmeEditado.observacoes,
                horario: alarmeEditado.horario,
                ativado: alarmeEditado.ativado,
                diasDeUso: alarmeEditado.diasDeUso,
                intervalo: alarmeEditado.intervalo,
                medicamentoId: alarmeEditado.medicamentoId,
                usuarioMedicamentoId: alarmeEditado.usuarioMedicamentoId,
              );
            });
            await buscarAlarmes();
            _mostrarSucesso('Alarme atualizado com sucesso.');
          } catch (_) {
            _mostrarErro(
              'Nao foi possivel atualizar o alarme. Tente novamente.',
            );
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: cardDecoracao(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarme.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: corTextoEscuro,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    alarme.horario.format(context),
                    style: const TextStyle(
                      fontSize: 44,
                      height: 1.1,
                      fontWeight: FontWeight.w300,
                      color: corPrimariaEscura,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    alarme.diasDeUso,
                    style: const TextStyle(fontSize: 14, color: corTextoCinza),
                  ),
                  if (alarme.observacoes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        alarme.observacoes,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AlternadorSwitch(
                  valor: alarme.ativado,
                  aoMudar: (_) async {
                    final userId = SupabaseBackend.client.auth.currentUser?.id;
                    if (userId == null || alarme.id == null) {
                      return;
                    }
                    try {
                      await _executarComRetry(() {
                        return appApi.alternarStatusAlarme(
                          usuarioId: userId,
                          alarmeId: alarme.id!,
                          ativo: !alarme.ativado,
                        );
                      });
                      await buscarAlarmes();
                    } catch (_) {
                      _mostrarErro('Nao foi possivel atualizar o status.');
                    }
                  },
                ),
                const SizedBox(height: 14),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFF87171),
                    size: 26,
                  ),
                  onPressed: () async {
                    final userId = SupabaseBackend.client.auth.currentUser?.id;
                    if (userId == null || alarme.id == null) {
                      return;
                    }
                    try {
                      await _executarComRetry(() {
                        return appApi.deletarAlarme(
                          usuarioId: userId,
                          alarmeId: alarme.id!,
                        );
                      });
                      await buscarAlarmes();
                      _mostrarSucesso('Alarme removido.');
                    } catch (_) {
                      _mostrarErro('Nao foi possivel remover o alarme.');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  SizedBox(height: 15),
                  Text(
                    'Alarmes',
                    style: TextStyle(
                      fontSize: 30,
                      color: corPrimariaEscura,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 32),
                  BotaoPrimario(
                    texto: 'Adicionar novo alarme',
                    carregando: _salvando,
                    icone: Icons.add,
                    onPressed: () async {
                      if (_salvando) {
                        return;
                      }
                      final novoAlarme = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TelaConfigAlarme(),
                        ),
                      );

                      if (novoAlarme != null && mounted) {
                        final user = SupabaseBackend.client.auth.currentUser;
                        if (user == null) {
                          return;
                        }
                        setState(() {
                          _salvando = true;
                        });
                        try {
                          await _executarComRetry(() {
                            return _alarmesApi.salvarNovoAlarme(
                              nome: novoAlarme.nome,
                              observacoes: novoAlarme.observacoes,
                              horario: novoAlarme.horario,
                              diasDeUso: novoAlarme.diasDeUso,
                              ativado: novoAlarme.ativado,
                              intervalo: novoAlarme.intervalo,
                              usuarioId: user.id,
                              medicamentoId: novoAlarme.medicamentoId,
                              usuarioMedicamentoId:
                                  novoAlarme.usuarioMedicamentoId,
                            );
                          });
                          await buscarAlarmes();
                          _mostrarSucesso('Alarme salvo com sucesso.');
                        } catch (_) {
                          _mostrarErro(
                            'Nao foi possivel salvar o alarme. Tente novamente.',
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _salvando = false;
                            });
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _carregando
                      ? _skeletonAlarmes()
                      : _erro != null
                      ? _erroComRetry()
                      : alarmeList.isEmpty
                      ? const Center(
                        child: Text(
                          'Voce ainda nao possui alarmes.',
                          style: TextStyle(color: Color(0xFF646464)),
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        itemCount: alarmeList.length,
                        itemBuilder: (context, index) {
                          return containerAlarme(alarmeList[index], index);
                        },
                      ),
            ),
            const BarraNavegacaoApp(ativa: AbaApp.alarme),
          ],
        ),
      ),
    );
  }

  Widget _skeletonAlarmes() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: cardDecoracao(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 18, width: 180, radius: 8),
              SizedBox(height: 10),
              SkeletonBox(height: 30, width: 120, radius: 8),
              SizedBox(height: 8),
              SkeletonBox(height: 14, width: 160, radius: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _erroComRetry() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(
              onPressed: buscarAlarmes,
              child: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }

  String _mensagemErroAlarme(Object erro) {
    final texto = erro.toString().toLowerCase();
    if (texto.contains('failed host lookup') ||
        texto.contains('socketexception') ||
        texto.contains('network')) {
      return 'Sem internet no momento. Tente novamente em instantes.';
    }
    return 'Falha ao carregar alarmes.';
  }
}
