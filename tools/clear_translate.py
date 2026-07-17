#!/usr/bin/env python3
"""Traduz instruções abreviadas do pokeking p/ português claro.
Números = buffs: 1 dígito=+N (stat primário do membro); 2 dígitos XY=+X primário +Y Velocidade.
ORDEM CRÍTICA: traduzir NOMES (oponente) primeiro, depois a gíria do nosso time.
Nomes de Pokémon/golpes/itens ficam em inglês.

PARAMETRIZADO POR TIME: o apelido chinês de cada membro depende do CODE/time ativo
(CODEs em data/teams.json). Selecione com a env var POKEKING_TEAM (default: shadow_scale).
  Shadow Scale: Scrafty(混混) Dragonite(龙) Gengar(鬼) Heatran(火钢) Toxicroak(蛙) Chansey(蛋).
  Dingxianyou:  Poliwrath(蛙) Gengar(鬼) Volcarona(蛾) Slowbro(呆) Chansey(蛋) Politoed(皇)."""
import json, re, os
BASE = os.path.dirname(__file__)
DICT = json.load(open(os.path.join(BASE, "pokeking-dictionary.json"), encoding="utf-8"))

# --- config por time (apelido CN -> Pokémon). Mude o CODE => muda o time => mude aqui. ---
TEAMS = {
    'shadow_scale': {
        'member': {'混混':'Scrafty','龙':'Dragonite','鬼':'Gengar','火钢':'Heatran','蛙':'Toxicroak','蛋':'Chansey'},
        'boost_stat': {},                       # default do stat primário = Ataque
        'aliases': {},                          # apelidos multi-char extras (fase nomes)
        'moves': {},                            # gíria de golpe extra do time
    },
    # Starlight: Chansey/Jirachi/Gengar/Chandelure/Gallade/Dragonite (CODE 2E98DB4D…).
    # 鬼/蛋/龙 confirmados (iguais aos outros times); 星(Jirachi?)/灯(Chandelure?)/勇(Gallade?) A CONFERIR
    # na extração — rode o build e troque os apelidos que saírem em chinês.
    'starlight': {
        'member': {'蛋':'Chansey','鬼':'Gengar','龙':'Dragonite','星':'Jirachi','灯':'Chandelure','勇':'Gallade'},
        'boost_stat': {'鬼':'Sp.Atk', '灯':'Sp.Atk'},
        'aliases': {},
        'moves': {},
    },
    # Ghost Dance: Chansey/Gengar/Jellicent/Volcarona/Scrafty/Gliscor (+Excadrill sem set) (CODE 8A0799DA…).
    # 鬼/蛋/蛾/混混/天蝎(Gliscor) confirmados; Jellicent = 嘟 (de 胖嘟嘟), confirmado na extração.
    'ghost_dance': {
        'member': {'蛋':'Chansey','鬼':'Gengar','蛾':'Volcarona','混混':'Scrafty','嘟':'Jellicent','天蝎':'Gliscor'},
        'boost_stat': {'鬼':'Sp.Atk', '蛾':'Sp.Atk'},
        'aliases': {},
        'moves': {},
    },
    'dingxianyou': {
        'member': {'蛙':'Poliwrath','鬼':'Gengar','蛾':'Volcarona','呆':'Slowbro','蛋':'Chansey','皇':'Politoed'},
        # Poliwrath 蛙6 = Belly Drum (+6 Atk, primário Ataque). Gengar/Volcarona buffam Sp.Atk.
        'boost_stat': {'鬼':'Sp.Atk', '蛾':'Sp.Atk'},
        # dois sapos: 皇/雨蛙/蛙皇 = Politoed (Final Gambit/Drizzle); 青蛙/格斗青蛙 = Poliwrath (o lutador)
        'aliases': {'格斗青蛙':'Poliwrath', '青蛙':'Poliwrath', '蛙皇':'Politoed', '雨蛙':'Politoed',
                    # apelidos genéricos resolvidos pelo CONTEXTO da rota deste time (líder entrega o mon)
                    '鸟':'staraptor', '狗':'houndoom', '暴飞':'honchkrow', '猴子':'primeape',
                    '鳄鱼':'krookodile',    # croc só aparece sob a Agatha (que tem Krookodile, não Feraligatr)
                    '蓝':'latios',          # Alder: o "azul" é o Latios
                    '超头':'zen headbutt',  # Bronzong/Metagross: 超(psíquico)+头(cabeçada); par com Earthquake. NÃO é 超梦/Mewtwo
                    '爆裂':'dynamic punch',# 爆裂拳 do Machamp (rota Shauntal>jellicent>machamp)
                    '鸭':'golduck'},        # pato solto sob a Agatha (que tem Golduck)
        'moves': {'哈欠':'Yawn', '哈':'Yawn'},   # 呆哈 = troque para Slowbro · use Yawn
    },
    # Sacred Inferno: Chansey/Slowbro/Gengar/Volcarona/Gallade/Gliscor (CODE DACC146C…).
    # Apelidos confirmados na extração (05/07): 蛋/呆/鬼/蛾 iguais aos outros; Gallade = 雷朵
    # (艾路雷朵, NÃO 勇 aqui); Gliscor = 蝎/天蝎. 剑=大剑鬼(Samurott,opp) e 路卡=Lucario(opp) NÃO são membros.
    'sacred_inferno': {
        'member': {'蛋':'Chansey','呆':'Slowbro','鬼':'Gengar','蛾':'Volcarona','雷朵':'Gallade',
                   '天蝎':'Gliscor','蝎':'Gliscor'},
        'boost_stat': {'鬼':'Sp.Atk', '蛾':'Sp.Atk'},   # Gengar/Volcarona buffam Sp.Atk; resto Ataque
        # Apelidos multi-char do time PRECISAM ir aqui (FASE 1 names_tr, prioridade sobre o dict
        # compartilhado): 蛾子=Volcarona (senão vira "moth"), 雷朵=Gallade (senão "gallade/rose"),
        # 天蝎=Gliscor (senão "gliscor" minúsculo).
        'aliases': {'蛾子':'Volcarona', '雷朵':'Gallade', '天蝎':'Gliscor'},
        'moves': {'哈欠':'Yawn', '哈':'Yawn'},           # 呆哈 = troque para Slowbro · use Yawn
        # #49: o Gengar DESTE time não tem Nasty Plot (pokepaste 6d6ea278…: Encore/HP Fighting/
        # Thunderbolt/Shadow Ball) → o 诡计 do guia é na verdade o item X. Special. E a Volcarona
        # 蛾子N/蛾N/舞N = Quiver Dance ×N (o número = nº de danças); ＋特 colado = + X. Special.
        # (regra por-time: em outro time cujo Gengar TENHA Nasty Plot, 诡计 continua "Nasty Plot".)
        'gengar_x_special': True,
        'volcarona_quiver': True,
    },
}
TEAM = os.environ.get('POKEKING_TEAM', 'shadow_scale')
_CFG = TEAMS[TEAM]
MEMBER = _CFG['member']
BOOST_STAT = _CFG['boost_stat']
TEAM_ALIASES = _CFG['aliases']
TEAM_MOVES = _CFG['moves']
MEMBER_PAT = '|'.join(re.escape(k) for k in sorted(MEMBER, key=len, reverse=True))
SEP = '¦'

# prosa/avisos (multi-char primeiro; rodam DEPOIS dos nomes)
SUPP = [('没减防','sem reduzir a defesa'),('减防','com defesa reduzida'),('不用管','pode ignorar'),
        ('无视','ignora'),  # antes do '无'->'sem' lá embaixo (senão vira "sem" + 视 solto)
        ('注意','atenção:'),('确二','confirma 2HKO em'),('确一','confirma 1HKO em'),
        ('待测','(ainda a testar)'),('健康','saudável'),('血量','HP'),('速度','Velocidade'),
        ('近战','Close Combat'),('力度','força'),('畏缩','flinch'),('对位','contra'),
        ('死亡','desmaiou'),('存活','sobreviveu'),('稳健','seguro'),('追速','priorizar Velocidade'),
        ('意外','inesperado'),('满血','HP cheio'),('上一步','passo anterior'),('重回','volte a'),
        ('再来一次','de novo'),('一样','igual'),('暴毙','morre de surpresa'),('概率','chance'),
        ('较大','alta'),('避免','evitar'),('克制','vantagem de tipo'),('破','quebre o'),
        ('则','então'),('若','se'),('共','total'),('再','depois'),('补','reponha'),
        ('已','já'),('选','escolha'),('无','sem'),('非','sem '),('省','economia'),
        ('御','Defesa'),('防','Defesa'),('速','Velocidade'),('疗','cure'),('爪','Dragon Claw'),
        ('推至','empurre até'),('推队','varra o time do oponente'),('推','empurre'),
        # golpes/itens/prosa adicionais (inferidos com confiança)
        ('龙舞','Dragon Dance'),('十万','Thunderbolt'),('咬碎','Crunch'),('直冲钻','Drill Run'),
        ('力量宝石','Power Gem'),('复活草','Revival Herb'),('活力碎片','Vitality Fragment'),
        ('免速','não precisa buffar Velocidade'),('免拍','(sem precisar de Encore)'),
        ('依旧','ainda assim'),('倒数第二','o penúltimo'),('慎选','escolha com cuidado'),
        ('变通','se adapte'),('即可','basta'),('连点','use repetidamente'),('连','seguido'),
        ('被封','foi bloqueado'),('绿血','HP saudável'),('容易','fácil'),
        ('越','quanto mais'),('倆','dois'),('四次','4 vezes'),('四','4'),
        ('配置','o set'),('表格','a tabela'),('分支','os ramos abaixo'),('下面','abaixo'),
        ('身上','em cima'),('继续','continue'),('见','se aparecer'),('有无','se tem ou não'),
        ('压迫感','pressão'),('理解不够','sem domínio suficiente'),('自','por conta própria'),
        ('免','não precisa'),
        # nomes/itens ambíguos confirmados pelo usuário
        ('宝顿甲','Donphan'),('宝天蝎','Gliscor'),('没斗宝','sem Fighting Gem'),('斗宝','Fighting Gem'),
        ('拉普拉斯','Lapras'),('玫瑰','Roserade'),('拿波','Ludicolo'),('蛤蟆','Seismitoad'),
        ('电疗','golpe elétrico'),('锁超','travar o Mewtwo'),('超','Mewtwo'),('锁','travar'),
        ('机关枪','Machine Gun'),('活力碎片','Vitality Fragment'),('班','Tyranitar'),
        ('均','em todos'),('斯',''),('宝','')]

# tokens da NOSSA gíria — EXCLUÍDOS do dicionário de nomes (senão a Fase 1 os pega antes)
SHORTHAND_EXCL = {'混混','火钢','鬼面','鬼球','生蛋','撒娇','点杀','双拉','赖场','免拍','逼退','重引',
                  '看道具','看特性','看技能','看战况','看血量',
                  '道具','特性','技能','战况'} | {k for k, _ in SUPP}

# --- Fase 1: dicionário só de NOMES (chaves multi-char, exceto nossa gíria) ---
NAME_DICT = {k: v for k, v in DICT.items() if len(k) >= 2 and k not in SHORTHAND_EXCL}
NAME_DICT.update(TEAM_ALIASES)   # apelidos multi-char do time (ex.: 青蛙->Poliwrath) têm prioridade
NAME_KEYS = sorted(NAME_DICT, key=len, reverse=True)
NAME_PAT = re.compile("|".join(re.escape(k) for k in NAME_KEYS))
def names_tr(s): return NAME_PAT.sub(lambda m: NAME_DICT[m.group(0)], s) if s else s

# --- dicionário completo (inclui 1-char) p/ fragmentos que sobrarem ---
ALL_KEYS = sorted(DICT, key=len, reverse=True)
ALL_PAT = re.compile("|".join(re.escape(k) for k in ALL_KEYS))
def full_tr(s): return ALL_PAT.sub(lambda m: DICT[m.group(0)], s) if s else s

def translate_clause(c):
    s = c or ''
    # normaliza colchetes chineses 【】 -> [ ]
    s = s.replace('【', ' [').replace('】', ']')
    # PRÉ-PASSE por time (#49): roda ANTES de tudo, senão o alias 蛾子->Volcarona come o número
    # (vira "Volcarona2") e o boost 蛾N vira "+N Sp.Atk" em vez do move real.
    if _CFG.get('volcarona_quiver'):
        # 蛾子NN% = limiar de HP (NÃO é contagem de dança). Trata ANTES pra "51%" não virar QD×5.
        s = re.sub(r'蛾子?(\d+%)', lambda m: SEP + 'Volcarona ' + m.group(1) + SEP, s)
        # 蛾N / 蛾子N (dígito único; ＋特 opcional) = Volcarona Quiver Dance ×N (+ X. Special).
        # (?!\d) evita comer só metade de um boost de 2 dígitos tipo 蛾22.
        s = re.sub(r'蛾子?(\d)(?!\d)(＋特|\+特)?',
                   lambda m: SEP + 'Volcarona Quiver Dance x' + m.group(1)
                             + (' + X. Special' if m.group(2) else '') + SEP, s)
        # 舞N solto = Quiver Dance ×N — MAS não quando faz parte de outra "dança" composta
        # (剑舞=Swords Dance do Gliscor, 龙舞=Dragon Dance, etc. têm que ficar como estão).
        s = re.sub(r'(?<![剑龙战戰晃月旋之乱毛瓣蝶羽])舞(\d)',
                   lambda m: SEP + 'Quiver Dance x' + m.group(1) + SEP, s)
        # 蛾子对X = "Volcarona vs X" (senão o alias cola tudo: "VolcaronatoX")
        s = s.replace('蛾子对', SEP + 'Volcarona vs ')
    if _CFG.get('gengar_x_special'):
        # 诡计 = "Nasty Plot" no guia, mas o Gengar deste time não tem o move → é o item X. Special.
        s = s.replace('诡计', SEP + 'X. Special' + SEP).replace('诡', SEP + 'X. Special' + SEP)
    # FASE 1: nomes do oponente -> inglês
    s = names_tr(s)
    # FASE 2: prosa/avisos
    for a, b in SUPP:
        s = s.replace(a, ' ' + b + ' ')
    s = s.replace('特防','Sp.Def').replace('特攻','Sp.Atk')
    # "＋特" / "+特" solto = anotação redundante de "+特攻" (Sp.Atk) que segue um setup
    # (ex.: 蛾1＋特 = Volcarona 1 Quiver Dance, +Sp.Atk); o boost já mostra o stat, então remove.
    # Só aqui (após 特攻/特防), o 特 restante nunca é 特攻/特防/特性 (esses são 2-char).
    s = s.replace('＋特', '').replace('+特', '')
    # FASE 3: golpes da nossa gíria
    for a, b in sorted(TEAM_MOVES.items(), key=lambda kv: -len(kv[0])):  # gíria de golpe do time (ex.: 哈->Yawn)
        s = s.replace(a, SEP+'use '+b+SEP)
    for a, b in [('鬼球','Shadow Ball'),('鬼面','Scary Face'),('撒娇','Charm')]:
        s = s.replace(a, SEP+b+SEP)
    s = s.replace('生蛋', SEP+'Chansey usa Soft-Boiled'+SEP)
    s = s.replace('点杀', SEP+'nocauteie'+SEP)
    s = s.replace('双拉', SEP+'troca dupla'+SEP)
    s = s.replace('赖场', SEP+'fica no campo (não troca)'+SEP)
    s = s.replace('免拍', SEP+'(sem precisar de Encore)'+SEP)
    s = s.replace('逼退', SEP+'force o oponente a trocar'+SEP)
    s = s.replace('重引', SEP+'force a troca de novo'+SEP)
    # ver X
    for a,b in [('看道具','veja o ITEM do oponente'),('看特性','veja a HABILIDADE do oponente'),
                ('看技能','veja o GOLPE do oponente'),('看战况','veja a situação'),
                ('看血量','veja o HP'),('看','veja')]:
        s = s.replace(a, SEP+b+SEP)
    # FASE 4: buffs (membro + números). Stat primário por membro (default Ataque).
    def boost(m):
        mem = MEMBER[m.group(1)]; dg = m.group(2)
        stat = BOOST_STAT.get(m.group(1), 'Ataque')
        body = f"{mem} +{dg} {stat}" if len(dg)==1 else f"{mem} +{dg[0]} {stat} +{dg[1]} Velocidade"
        return SEP+body+SEP
    s = re.sub(r'(' + MEMBER_PAT + r')(\d{1,2})', boost, s)
    # FASE 5: trocar para membro
    s = re.sub(r'切(' + MEMBER_PAT + r')', lambda m: SEP+'troque para '+MEMBER[m.group(1)]+SEP, s)
    s = s.replace('切', SEP+'troque para '+SEP)
    # FASE 6: verbos
    s = s.replace('钉', SEP+'use Stealth Rock'+SEP)
    s = s.replace('拍', SEP+'use Encore'+SEP)
    s = s.replace('出', SEP+'→ sai ')
    s = s.replace('送', SEP+'sacrifique ')
    s = s.replace('跑', SEP+'deixe fugir ')
    s = s.replace('引', SEP+'force a troca'+SEP)
    s = s.replace('吃', SEP+'tome o golpe de ')
    s = s.replace('点', SEP+'use ')
    # FASE 7: membros isolados
    for cn, en in MEMBER.items():
        s = s.replace(cn, SEP+en+SEP)
    # FASE 8: fragmentos de nome restantes (dict completo)
    s = full_tr(s)
    # fallback: 瞬 solto (de 瞬移 quebrado na fonte) = Teleport, nesse contexto sempre.
    s = s.replace('瞬', SEP+'Teleport'+SEP)
    parts = [re.sub(r'\s+',' ',p).strip(' ，,') for p in s.split(SEP)]
    return [p for p in parts if p]

def translate_field(op):
    res = []
    for part in re.split(r'[，,]', op or ''):
        if part.strip(): res.extend(translate_clause(part))
    return res

if __name__ == '__main__':
    import sys
    for line in sys.stdin:
        print(' | '.join(translate_field(line.strip())))
