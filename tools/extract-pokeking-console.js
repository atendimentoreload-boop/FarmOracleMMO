// ============================================================================
//  extract-pokeking-console.js  —  EXTRAÇÃO DA ELITE 4 DO POKEKING (1 clique)
// ============================================================================
//  Baixa o "pokeking_full.json" com TODAS as 5 regiões da Elite 4
//  (Kanto, Hoenn, Unova, Sinnoh, Johto), cada campeão com a árvore completa
//  de soluções de cada lead. Use sempre que TROCAR O CODE do time no site
//  (o time muda → as soluções mudam → é só re-extrair).
//
//  COMO USAR
//  1. Abra  http://pokeking.icu  no navegador, LOGADO, com o CODE do time
//     desejado já aplicado (página "account info" → campo CODE → save).
//  2. Aperte F12 → aba Console.
//  3. Cole ESTE ARQUIVO INTEIRO e Enter.
//        (Se o Chrome bloquear a colagem: digite  allow pasting  + Enter, e cole.)
//  4. Ele baixa "pokeking_full.json" pra sua pasta de Downloads.
//  5. Mova pra tools/ e rode:   python tools/build_elite4.py
//        → regenera data/elite4_<regiao>.json
//
//  Passo a passo completo e como a API foi descoberta: ver tools/README.md
// ============================================================================
(async () => {
  const B = 'http://backend.pokeking.icu/api/';
  const g = async u => (await fetch(B + u, { credentials: 'include' })).json();
  const asArr = j => Array.isArray(j) ? j : (Array.isArray(j?.result) ? j.result : (Array.isArray(j?.data) ? j.data : []));
  const asObj = j => (j && j.result != null) ? j.result : ((j && j.data != null) ? j.data : j);

  // As 5 regiões da Elite 4 (códigos do Pokeking). A área "OTHER" (Red, Rei Abóbora) fica de fora.
  const CODES = ['GUANDU', 'FENGYUAN', 'HEZHONG', 'SHENAO', 'CHENGDU'];
  const regions = [];
  let totalLeads = 0;

  for (const code of CODES) {
    const npcs = asArr(await g('npc/listByArea?area=' + code));         // campeões da região
    const champions = [];
    for (const npc of npcs) {
      const routers = asObj(await g('monsterRouter/listByNpc?npcId=' + npc.id)); // árvore de TODOS os leads
      const n = (routers && routers.children && routers.children.length) || 0;
      totalLeads += n;
      champions.push({ id: npc.id, name: npc.name, routers });
      console.log('  ' + code + ' · ' + npc.id + ' ' + npc.name + ' → ' + n + ' leads');
    }
    regions.push({ code, champions });
    console.log('%c✓ ' + code + ': ' + champions.length + ' campeões', 'color:lime;font-weight:bold');
  }

  const out = { regions };
  window.__pkFull = out; // fica disponível caso o download falhe: copy(JSON.stringify(window.__pkFull))
  const totalChamps = regions.reduce((a, r) => a + r.champions.length, 0);
  console.log('%c=== TOTAL: ' + regions.length + ' regiões · ' + totalChamps + ' campeões · ' + totalLeads + ' leads ===',
    'color:cyan;font-weight:bold;font-size:13px');

  // Sanity check: não baixa um arquivo incompleto (ex.: sessão deslogada).
  if (regions.length !== 5 || totalChamps < 25 || totalLeads < 100) {
    console.warn('[ATENÇÃO] resultado parece incompleto — confira se está LOGADO no site. Download NÃO feito.');
    console.warn('Os dados parciais estão em window.__pkFull, se quiser inspecionar.');
    return;
  }

  // Download direto (mais confiável que clipboard para ~500 KB).
  const s = JSON.stringify(out);
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([s], { type: 'application/json' }));
  a.download = 'pokeking_full.json';
  document.body.appendChild(a); a.click(); a.remove();
  console.log('%c[OK] baixando pokeking_full.json (' + s.length + ' chars).',
    'color:lime;font-weight:bold;font-size:14px');
  console.log('Próximo: mover pra tools/ e rodar  python tools/build_elite4.py');
})();
