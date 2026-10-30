import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilUsuario {
  PerfilUsuario({
    required this.nome,
    required this.cpf,
    required this.email,
    required this.dataNascimento,
    required this.telefone,
    this.fotoDataUrl,
    this.cep = '',
    this.logradouro = '',
    this.numero = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    this.tipoSanguineo = '',
    this.cartaoSus = '',
    this.convenio = '',
    this.alergias = '',
    this.codigoVinculacao = '',
  });

  String nome;
  String cpf;
  String email;
  String dataNascimento;
  String telefone;
  String? fotoDataUrl;
  String cep;
  String logradouro;
  String numero;
  String bairro;
  String cidade;
  String estado;
  String tipoSanguineo;
  String cartaoSus;
  String convenio;
  String alergias;
  String codigoVinculacao;

  int? get idade {
    final iso = PerfilUsuarioApi._dataBrasileiraParaIso(dataNascimento);
    if (iso == null) {
      return null;
    }
    final nascimento = DateTime.tryParse(iso);
    if (nascimento == null) {
      return null;
    }
    final hoje = DateTime.now();
    var anos = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      anos--;
    }
    return anos < 0 ? null : anos;
  }
}

class PerfilUsuarioApi {
  PerfilUsuarioApi({AppApi? appApi}) : _appApi = appApi ?? AppApi();

  final AppApi _appApi;

  Future<void> limparSenhasLegadas() async {
  final prefs = await SharedPreferences.getInstance();

  final chavesLegadas = prefs
      .getKeys()
      .where(
        (chave) =>
            chave.startsWith('perfil_') &&
            chave.endsWith('_senha'),
      )
      .toList();

  for (final chave in chavesLegadas) {
    final removida = await prefs.remove(chave);

    if (!removida) {
      throw StateError('Falha ao remover senha legada.');
    }
  }
}

  Future<PerfilUsuario> carregarPerfil() async {
    
    await limparSenhasLegadas();

    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Usuario nao autenticado.');
    }

    final perfilDb = await _appApi.buscarUsuarioAtual();
    final prefs = await SharedPreferences.getInstance();
    final chaveBase = 'perfil_${user.id}_';

    final dataNascimentoDb = perfilDb['data_nascimento']?.toString();
    final dataFormatada = _dataIsoParaBrasileira(dataNascimentoDb);

    final fotoLocal = prefs.getString('${chaveBase}foto_data_url');
    final telefoneLocal =
        prefs.getString('${chaveBase}telefone') ??
        user.userMetadata?['telefone']?.toString() ??
        '';

    final telefoneDb = perfilDb['telefone']?.toString() ?? '';

    String texto(String chave) {
      final valor = perfilDb[chave];
      if (valor == null || valor.toString() == 'null') {
        return '';
      }
      return valor.toString();
    }

    return PerfilUsuario(
      nome: perfilDb['nome']?.toString() ?? user.email ?? 'Anonimo',
      cpf: _formatarCpfVisual(perfilDb['cpf']?.toString() ?? ''),
      email: perfilDb['email']?.toString() ?? user.email ?? '',
      dataNascimento: dataFormatada,
      telefone: _formatarTelefoneVisual(
        telefoneDb.isNotEmpty ? telefoneDb : telefoneLocal,
      ),
      fotoDataUrl:
          texto('foto_data_url').isNotEmpty
              ? texto('foto_data_url')
              : (fotoLocal ??
                  user.userMetadata?['avatar_data_url']?.toString()),
      cep: texto('cep'),
      logradouro: texto('logradouro'),
      numero: texto('numero'),
      bairro: texto('bairro'),
      cidade: texto('cidade'),
      estado: texto('estado'),
      tipoSanguineo: texto('tipo_sanguineo'),
      cartaoSus: texto('cartao_sus'),
      convenio: texto('convenio'),
      alergias: texto('alergias'),
      codigoVinculacao: texto('codigo_vinculacao'),
    );
  }

  Future<PerfilUsuario> salvarPerfil(PerfilUsuario perfil) async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Usuario nao autenticado.');
    }

    final dataIso = _dataBrasileiraParaIso(perfil.dataNascimento);

    final payloadBasico = <String, dynamic>{
      'nome': perfil.nome.trim(),
      'cpf': perfil.cpf.trim().replaceAll(RegExp(r'[^0-9]'), ''),
      'email': perfil.email.trim(),
      'data_nascimento': dataIso,
    };

    final payloadCompleto = <String, dynamic>{
      ...payloadBasico,
      'telefone': perfil.telefone.trim(),
      'cep': perfil.cep.trim(),
      'logradouro': perfil.logradouro.trim(),
      'numero': perfil.numero.trim(),
      'bairro': perfil.bairro.trim(),
      'cidade': perfil.cidade.trim(),
      'estado': perfil.estado.trim(),
      'tipo_sanguineo': perfil.tipoSanguineo.trim(),
      'cartao_sus': perfil.cartaoSus.trim(),
      'convenio': perfil.convenio.trim(),
      'alergias': perfil.alergias.trim(),
      'foto_data_url': perfil.fotoDataUrl,
    };

    Map<String, dynamic> salvoDb;
    try {
      salvoDb = await _appApi.salvarUsuarioAtual(payload: payloadCompleto);
    } catch (_) {
      salvoDb = await _appApi.salvarUsuarioAtual(payload: payloadBasico);
    }

    final prefs = await SharedPreferences.getInstance();
    final chaveBase = 'perfil_${user.id}_';
    await prefs.setString('${chaveBase}telefone', perfil.telefone);
    if (perfil.fotoDataUrl != null && perfil.fotoDataUrl!.isNotEmpty) {
      await prefs.setString('${chaveBase}foto_data_url', perfil.fotoDataUrl!);
    }

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? {});
    metadata['telefone'] = perfil.telefone;
    if (perfil.fotoDataUrl != null && perfil.fotoDataUrl!.isNotEmpty) {
      metadata['avatar_data_url'] = perfil.fotoDataUrl!;
    }

    try { //linha 181 começo
      await SupabaseBackend.client.auth.updateUser(
        UserAttributes(data: metadata),
      ); //linha 184 fim
    } catch (_) {}

    return PerfilUsuario(
      nome: salvoDb['nome']?.toString() ?? perfil.nome,
      cpf: _formatarCpfVisual(salvoDb['cpf']?.toString() ?? perfil.cpf),
      email: salvoDb['email']?.toString() ?? perfil.email,
      dataNascimento: _dataIsoParaBrasileira(
        salvoDb['data_nascimento']?.toString(),
      ),
      telefone: _formatarTelefoneVisual(perfil.telefone),
      fotoDataUrl: perfil.fotoDataUrl,
      cep: perfil.cep,
      logradouro: perfil.logradouro,
      numero: perfil.numero,
      bairro: perfil.bairro,
      cidade: perfil.cidade,
      estado: perfil.estado,
      tipoSanguineo: perfil.tipoSanguineo,
      cartaoSus: perfil.cartaoSus,
      convenio: perfil.convenio,
      alergias: perfil.alergias,
      codigoVinculacao: perfil.codigoVinculacao,
    );
  }

  static String _dataIsoParaBrasileira(String? dataIso) {
    if (dataIso == null || dataIso.trim().isEmpty || dataIso == 'null') {
      return '';
    }

    final somenteData = dataIso.split('T').first;
    final partes = somenteData.split('-');
    if (partes.length != 3) {
      return '';
    }

    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  static String? _dataBrasileiraParaIso(String? dataBr) {
    if (dataBr == null || dataBr.trim().isEmpty) {
      return null;
    }

    final partes = dataBr.split('/');
    if (partes.length != 3) {
      return null;
    }

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);
    if (dia == null || mes == null || ano == null) {
      return null;
    }

    try {
      final data = DateTime(ano, mes, dia);
      if (data.year != ano || data.month != mes || data.day != dia) {
        return null;
      }
    } catch (_) {
      return null;
    }

    return '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}';
  }

  static String _formatarCpfVisual(String valor) {
    final digitos = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) {
      return '';
    }

    final cpf = digitos.length > 11 ? digitos.substring(0, 11) : digitos;
    final b = StringBuffer();
    for (var i = 0; i < cpf.length; i++) {
      if (i == 3 || i == 6) {
        b.write('.');
      }
      if (i == 9) {
        b.write('-');
      }
      b.write(cpf[i]);
    }
    return b.toString();
  }

  static String _formatarTelefoneVisual(String valor) {
    final digitos = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) {
      return '';
    }

    final tel = digitos.substring(0, digitos.length > 11 ? 11 : digitos.length);
    final b = StringBuffer();
    if (tel.isNotEmpty) {
      b.write('(');
      b.write(tel.substring(0, tel.length >= 2 ? 2 : tel.length));
    }
    if (tel.length >= 2) {
      b.write(')');
    }
    if (tel.length > 2) {
      final parteMeioFim = tel.substring(2);
      if (parteMeioFim.length > 5) {
        b.write(parteMeioFim.substring(0, 5));
        b.write('-');
        b.write(parteMeioFim.substring(5));
      } else {
        b.write(parteMeioFim);
      }
    }
    return b.toString();
  }
}
