# Como criar Poképastes COM os Pokémon aparecendo (padrão do projeto)

Padrão para **todo Poképaste novo** dos times do app: os mons têm que aparecer
com **sprite** (igual ao card do pokepast.es), não como um bloco de texto único.

## ⚠️ A pegadinha (o motivo de existir este doc)

O pokepast.es só separa os Pokémon em cards com sprite se o corpo do paste for
enviado com quebras de linha **CRLF (`\r\n`)**. Se enviar com **LF puro (`\n`)**,
ele junta os 6 mons num **bloco único** com o sprite `0-0.png` (desconhecido).

- Cada mon = um bloco no formato **Showdown**, blocos separados por **linha em branco**.
- No arquivo você escreve com LF normal; a conversão pra CRLF é automática (script abaixo).

## Jeito rápido (recomendado) — script

```bash
tools/teams/make-pokepaste.sh \
  --paste  tools/teams/<time>/pokepaste.txt \
  --title  "Nome do Time" \
  --author "Autor" \
  --notes  tools/teams/<time>/notas.txt      # opcional
```

O script: converte pra CRLF → faz o POST → imprime a **URL nova** → **verifica**
sozinho (nº de mons esperado × nº de cards renderizados + lista de sprites; avisa
se algum ficou `0-0.png`). Só `--paste` é obrigatório.

## Jeito manual (curl)

```bash
# 1. converter o corpo pra CRLF
python3 -c "d=open('corpo.txt').read().replace('\r\n','\n').rstrip('\n').replace('\n','\r\n');open('corpo_crlf.txt','wb').write(d.encode())"

# 2. POST (retorna 303 com  location: /<id>)
curl -s -D - -o /dev/null -X POST https://pokepast.es/create \
  --data-urlencode "title=Nome do Time" \
  --data-urlencode "author=Autor" \
  --data-urlencode "notes@notas_crlf.txt" \
  --data-urlencode "paste@corpo_crlf.txt" | grep -i location
```

Campos do form: `title`, `author`, `notes`, `paste`. A URL final é
`https://pokepast.es/<id>` (do header `location`).

## Verificar (sempre)

- `curl -s https://pokepast.es/<id>/raw` → confere os sets e que não sobrou mon a mais.
- Na página, `<article>` deve dar **um por mon**, e cada `img-pokemon` deve ser um
  número de Pokédex real (ex.: `113-0.png` Chansey), **nunca `0-0.png`**.

## Plugar no app

Toda a config de time fica em [`data/teams.json`](../../data/teams.json): cada time
tem `pokepaste` (URL) + `pokemon` (chips) + `code`. As **3 plataformas leem esse
manifesto em runtime** → trocar/adicionar a URL num lugar só cobre Mac/Win/Android
(depois re-sync dos Resources do Mac + rebuild). Não há URL de paste hardcoded por
plataforma.

## Notas importantes

- **Imutável:** paste do pokepast.es não dá pra editar/apagar depois de criado —
  pra mudar o conteúdo, cria um novo e troca a URL.
- **"Code:" do PokeMMO nas notas:** se o paste original trouxer um `Code: XXXX`
  (código de importação do jogo), ele é **opaco** e codifica o time inteiro. Ao
  remover/trocar um mon, esse code **não** dá pra regerar por fora — só dentro do
  PokeMMO. Ou mantém verbatim (avisando que aponta pro time antigo) ou tira a linha.

## Exemplo de referência

Ghost Dance sem Excadrill: corpo em
[`ghost_dance/pokepaste_sem_excadrill.txt`](ghost_dance/pokepaste_sem_excadrill.txt)
→ paste **https://pokepast.es/db569c2bb3979a55** (ver item #36 do HUB).
