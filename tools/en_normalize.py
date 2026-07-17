#!/usr/bin/env python3
"""Normaliza para INGLÊS a prosa/gíria PT que o clear_translate.py emite (hardcoded em PT).

O build_elite4.py com POKEKING_LANG=en já põe a ESTRUTURA (lead/prompt/"team X"…) em inglês,
mas o clear_translate gera a gíria sempre em PT (troque para→switch to, → sai→→ sends out,
fica no campo→stays, etc.). Este passo vira essa prosa pro inglês, mantendo nomes de
Pokémon/golpe/item. Roda no caminho EN do rebuild_team.py (NUNCA no PT).

Uso: python3 tools/en_normalize.py <arquivo_ou_dir>
"""
import json, os, re, sys, glob

# Ordem IMPORTA: frases longas primeiro. Tudo o que o clear_translate produz em PT.
RULES = [
    # frases "veja …"
    ("veja o ITEM do oponente", "see the opponent's ITEM"),
    ("veja a HABILIDADE do oponente", "see the opponent's ABILITY"),
    ("veja o GOLPE do oponente", "see the opponent's MOVE"),
    ("veja a situação", "see the situation"),
    ("veja o HP", "see the HP"),
    ("veja abaixo", "see below"),
    # trocas / forçar
    ("force o oponente a trocar", "force the opponent to switch"),
    ("force a troca de novo", "force the switch again"),
    ("force a troca", "force the switch"),
    ("troca dupla", "double switch"),
    ("troque para", "switch to"),
    # ficar / fugir / sair
    ("fica no campo (não troca)", "stays on the field (no switch)"),
    ("deixe fugir", "let it flee:"),
    ("→ sai", "→ sends out"),
    ("sacrifique", "sacrifice"),
    ("nocauteie", "KO"),
    ("Chansey usa Soft-Boiled", "Chansey uses Soft-Boiled"),
    # empurrar / varrer
    ("varra o time do oponente", "sweep the opponent's team"),
    ("empurre até", "push until"),
    ("empurre", "push"),
    # encore / golpe
    ("(sem precisar de Encore)", "(no Encore needed)"),
    ("sem precisar de Encore", "no Encore needed"),
    ("não precisa buffar Velocidade", "no need to boost Speed"),
    ("tome o golpe de", "take the hit at"),
    ("use repetidamente", "use repeatedly"),
    # avisos / estados (SUPP)
    ("sem reduzir a defesa", "without lowering Defense"),
    ("com defesa reduzida", "with Defense lowered"),
    ("pode ignorar", "can ignore"),
    ("confirma 2HKO em", "confirms 2HKO on"),
    ("confirma 1HKO em", "confirms 1HKO on"),
    ("(ainda a testar)", "(to be tested)"),
    ("morre de surpresa", "dies unexpectedly"),
    ("priorizar Velocidade", "prioritize Speed"),
    ("vantagem de tipo", "type advantage"),
    ("passo anterior", "previous step"),
    ("HP saudável", "healthy HP"),
    ("HP cheio", "full HP"),
    ("escolha com cuidado", "choose carefully"),
    ("não precisa", "no need"),
    ("ainda assim", "still"),
    ("o penúltimo", "the second-to-last"),
    ("os ramos abaixo", "the branches below"),
    ("sem domínio suficiente", "not enough mastery"),
    ("por conta própria", "on its own"),
    ("sem ameaça", "no threat"),
    ("do mesmo jeito", "same way"),
    ("se aparecer", "if it appears"),
    ("se tem ou não", "whether it has"),
    ("foi bloqueado", "got blocked"),
    ("volte a", "go back to"),
    ("quanto mais", "the more"),
    ("quebre o", "break the"),
    ("se adapte", "adapt"),
    ("de novo", "again"),
    ("já era", "done for"),
    # palavras
    ("travar o Mewtwo", "lock the Mewtwo"),
    ("atenção:", "note:"),
    ("saudável", "healthy"),
    ("ignora", "ignores"),
    ("travado", "locked"),
    ("travar", "lock"),
    ("ameaça", "threat"),
    ("usa", "uses"),
    ("veja", "see"),
    ("fica", "stays"),
    ("Velocidade", "Speed"),
    ("Defesa", "Defense"),
    ("Ataque", "Attack"),
    ("desmaiou", "fainted"),
    ("sobreviveu", "survived"),
    ("inesperado", "unexpected"),
    ("seguro", "safe"),
    ("economia", "save PP"),
    ("reponha", "restore"),
    ("continue", "continue"),
    ("escolha", "choose"),
    ("pressão", "pressure"),
    ("obstáculo", "obstacle"),
    ("finalizar", "finish"),
    ("fórmula", "formula"),
    ("vezes", "times"),
    ("básico", "basic"),
    ("enrolar", "stall"),
    ("evitar", "avoid"),
    ("pedaço", "chunk"),
    ("contra", "vs"),
    ("flinch", "flinch"),
    ("chance", "chance"),
    ("depois", "after"),
    ("então", "then"),
    ("força", "power"),
    ("fácil", "easy"),
    ("basta", "is enough"),
    ("seguido", "in a row"),
    ("abaixo", "below"),
    ("a tabela", "the table"),
    ("o set", "the set"),
    ("dois", "two"),
    ("cure", "heal"),
    ("alta", "high"),
    ("igual", "same"),
    ("mesmo", "same"),
    ("total", "total"),
    ("ainda", "still"),
]

# palavras curtas isoladas (com fronteira) — depois das frases
WORD_RULES = [
    (r"\bSiga conforme a situação\b", "Follow the situation"),
    (r"\bSiga os passos\b", "Follow the steps"),
    (r"\btroque para\b", "switch to"),
    (r"\btroque\b", "switch"),
    (r"\bgolpes\b", "moves"),
    (r"\bgolpe\b", "move"),
    (r"\bnão\b", "no"),
    (r"\bsem\b", "no"),
    (r"\bsó\b", "only"),
    (r"\bjá\b", "already"),
    (r"\bse\b", "if"),
]


def _cap(rep, matched):
    """Capitaliza o EN se o trecho PT casado começava com maiúscula."""
    return rep[0].upper() + rep[1:] if matched[:1].isupper() else rep


def norm(text):
    if not text:
        return text
    for a, b in RULES:
        # case-insensitive: o titleize do build capitaliza palavras à vontade (Fica/Usa/Não)
        # Guarda de fronteira: NÃO casar dentro de um nome próprio — ex.: "alta" em "Altaria",
        # "usa" em "Venusaur". Só bloqueia quando o termo está colado a OUTRA letra (lookaround
        # de letra, não \b), então frases com pontuação (ex.: "atenção:") seguem casando. (bug #38)
        pat = r'(?<![A-Za-zÀ-ÿ])' + re.escape(a) + r'(?![A-Za-zÀ-ÿ])'
        text = re.sub(pat, lambda m: _cap(b, m.group(0)), text, flags=re.I)
    for rx, rep in WORD_RULES:
        text = re.sub(rx, rep, text, flags=re.I)
    return re.sub(r"  +", " ", text).strip()


def process(path):
    d = json.load(open(path, encoding="utf-8"))
    for g in d.get("groups", []):           # labels dos leads (entries)
        for e in g.get("entries", []):
            if e.get("label"):
                e["label"] = norm(e["label"])
    for n in d.get("nodes", {}).values():
        if n.get("title"):
            n["title"] = norm(n["title"])
        for s in n.get("steps", []):
            if s.get("text"):
                s["text"] = norm(s["text"])
        b = n.get("branch")
        if b:
            if b.get("prompt"):
                b["prompt"] = norm(b["prompt"])
            for o in b.get("options", []):
                if o.get("label"):
                    o["label"] = norm(o["label"])
    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "."
    files = [target] if target.endswith(".json") else sorted(glob.glob(os.path.join(target, "elite4_*.json")))
    for f in files:
        process(f)
    print(f"en_normalize: {len(files)} arquivo(s)")
