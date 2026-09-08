const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

function extrairProjectRefDaUrl(url) {
  if (!url) {
    return '';
  }

  try {
    const host = new URL(url).host;
    return host.split('.').shift() || '';
  } catch (_) {
    return '';
  }
}

function montarUrlBancoAPartirDoSupabase() {
  const urlSupabase = (process.env.SUPABASE_URL || '').trim();
  const projectRef =
    (process.env.SUPABASE_PROJECT_REF || '').trim() ||
    extrairProjectRefDaUrl(urlSupabase);
  const hostBanco = (process.env.SUPABASE_DB_HOST || '').trim();
  const senhaBanco = (
    process.env.SUPABASE_DB_PASSWORD ||
    process.env.POSTGRES_PASSWORD ||
    ''
  ).trim();
  const usuarioBancoInformado = (
    process.env.SUPABASE_DB_USER || 'postgres'
  ).trim();
  const portaBanco = (process.env.SUPABASE_DB_PORT || '5432').trim();
  const nomeBanco = (process.env.SUPABASE_DB_NAME || 'postgres').trim();

  if (!projectRef || !senhaBanco) {
    return '';
  }

  const hostFinal = hostBanco || `db.${projectRef}.supabase.co`;
  const usandoPooler = hostFinal.includes('.pooler.supabase.com');
  const usuarioBanco =
    usandoPooler && usuarioBancoInformado === 'postgres'
      ? `postgres.${projectRef}`
      : usuarioBancoInformado;

  return `postgresql://${encodeURIComponent(usuarioBanco)}:${encodeURIComponent(senhaBanco)}@${hostFinal}:${portaBanco}/${nomeBanco}`;
}

function obterConfiguracao() {
  const porta = Number(process.env.PORTA || process.env.PORT || 3333);
  const schemaCatalogo = (process.env.CATALOGO_SCHEMA || 'catalogo').trim();
  const urlBanco =
    process.env.DATABASE_URL ||
    process.env.SUPABASE_DB_URL ||
    process.env.POSTGRES_URL ||
    montarUrlBancoAPartirDoSupabase() ||
    '';

  return {
    porta: Number.isFinite(porta) && porta > 0 ? porta : 3333,
    schemaCatalogo,
    urlBanco: urlBanco.trim(),
  };
}

function garantirUrlBanco() {
  const configuracao = obterConfiguracao();
  if (!configuracao.urlBanco) {
    throw new Error(
      'Conexao com o banco nao configurada. Preencha DATABASE_URL ou informe SUPABASE_DB_PASSWORD no arquivo .env.',
    );
  }

  return configuracao.urlBanco;
}

module.exports = {
  garantirUrlBanco,
  obterConfiguracao,
};
