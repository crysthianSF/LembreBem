// Banco descartavel: npm install --prefix <diretorio-temporario> @electric-sql/pglite
// PGLITE_MODULE=<caminho-absoluto-do-modulo> node api/test/sec03.integration.cjs
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const fs = require('node:fs');
const assert = require('node:assert/strict');

(async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create schema app;
      create table app.alarmes (id uuid primary key, usuario_id uuid not null);
      create table app.registro_doses (
        id integer primary key, usuario_id uuid not null,
        alarme_id uuid references app.alarmes(id) on delete set null);
      insert into app.alarmes values
        ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a'),
        ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-00000000000b');
      insert into app.registro_doses values
        (1,'00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000002');
    `);
    const sql = fs.readFileSync('supabase/migrations/20261030224241_sec03_doses_mesmo_dono.sql', 'utf8');
    await db.exec(sql);
    await db.exec(sql); // reexecucao
    assert.equal((await db.query('select alarme_id from app.registro_doses where id=1')).rows[0].alarme_id, null);
    await assert.rejects(db.exec(`insert into app.registro_doses values
      (2,'00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000002')`), { code: '23503' });
    await db.exec(`update app.registro_doses set alarme_id='00000000-0000-0000-0000-000000000001' where id=1`);
    await assert.rejects(db.exec(`update app.registro_doses set alarme_id='00000000-0000-0000-0000-000000000002' where id=1`), { code: '23503' });
    await assert.rejects(db.exec(`update app.registro_doses set usuario_id='00000000-0000-0000-0000-00000000000b' where id=1`), { code: '23503' });
    // Reproduz a politica existente com uma identidade ficticia, sem BYPASSRLS.
    await db.exec(`create role sec03_usuario;
      grant usage on schema app to sec03_usuario;
      grant select, insert, update on app.registro_doses to sec03_usuario;
      alter table app.registro_doses enable row level security;
      create policy proprio on app.registro_doses for all to sec03_usuario
        using (usuario_id = '00000000-0000-0000-0000-00000000000a'::uuid)
        with check (usuario_id = '00000000-0000-0000-0000-00000000000a'::uuid);
      set role sec03_usuario;`);
    await assert.rejects(db.exec(`update app.registro_doses set usuario_id='00000000-0000-0000-0000-00000000000b', alarme_id=null where id=1`), { code: '42501' });
    await db.exec(`reset role;
      delete from app.alarmes where id='00000000-0000-0000-0000-000000000001';`);
    assert.deepEqual((await db.query('select usuario_id, alarme_id from app.registro_doses where id=1')).rows,
      [{ usuario_id: '00000000-0000-0000-0000-00000000000a', alarme_id: null }]);
    console.log('SEC-03: historico, reexecucao, INSERT/UPDATE, RLS e exclusao aprovados.');
  } finally {
    await db.close();
  }
})().catch((erro) => { console.error(erro); process.exitCode = 1; });
