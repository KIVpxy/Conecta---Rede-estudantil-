# Conecta

Plataforma educacional e social que transforma estudantes de consumidores
passivos em criadores, autores, pesquisadores e colaboradores.

MVP em **Flutter** (Android, iOS, Web, Linux, Windows, macOS) com backend
**Supabase** e modo demo embutido (dados de exemplo, sem configurar nada).

## Rodar em modo demo (recomendado para começar)

O app já roda com dados de exemplo:

```bash
flutter pub get
flutter run            # escolha o dispositivo
# ou na web com qualquer navegador (Firefox incluso):
flutter run -d web-server --web-port 8080
# depois abra http://localhost:8080
```

No modo demo, qualquer e-mail/senha entra como o usuário de exemplo
(Kevin Oliveira, **Developer**, Rank Diamante) — com um convite de
grupo pendente e comunicados da escola para experimentar.

## Instalar o Flutter no Arch Linux

Opção A — AUR (recomendado):

```bash
yay -S flutter          # ou: paru -S flutter
flutter --version
```

Opção B — tarball oficial:

```bash
cd ~
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz
tar xf flutter_linux_3.47.2-stable.tar.xz
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter doctor
```

Para rodar no Chrome (web): basta ter o Chromium/Chrome instalado.
Para rodar no Linux desktop: `sudo pacman -S clang cmake ninja gtk3`.
Para Android: instale o Android Studio/SDK e rode `flutter doctor`.

## Backend real (Supabase) — já conectado

O projeto **já está conectado** a um projeto Supabase: a URL e a chave
`anon public` estão nos valores padrão de `lib/app/config.dart` (a chave
anon é pública por design — a segurança é garantida pelas políticas RLS
no banco). Para usar o backend real basta:

```bash
flutter run --dart-define=USE_MOCK=false
```

(Sem o flag, o app roda em modo mock — padrão — sem precisar de internet.)

Para apontar para **outro** projeto Supabase:

1. No painel do novo projeto: **SQL Editor** → cole todo o conteúdo de
   `supabase/schema.sql` → Run.
2. Rode com as credenciais novas:

```bash
flutter run \
  --dart-define=USE_MOCK=false \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=SUA-ANON-KEY
```

> **Cadastro de usuários:** por padrão o Supabase exige confirmação de
> e-mail — nesse caso o app avisa "Conta criada! Confirme seu e-mail para
> entrar." após o cadastro. Para desenvolvimento, desative em
> **Authentication → Sign In / Providers → Email → Confirm email** e o
> usuário já entra direto.

O schema cria: perfis (com cargo user/developer, bio, redes sociais,
contato e escola por ID), escolas, projetos (incl. tipo Texto), mídias,
colaboradores, curtidas, salvos, avaliações (1–10), eventos de XP,
postagens e respostas de Materiais, desbloqueio de badges, conversas
diretas **e em grupo** (com convites `group_invites` e papéis de membro),
comunicados escolares — com RLS (permissões: só Developers escrevem
comunicados; só o convidado aceita o próprio convite), triggers de
recálculo de média/XP e RPCs usadas pelo app (`select_best_answer`,
`check_badges`, `get_or_create_conversation`, `create_group`,
`accept_group_invite`...), comentários independentes de projetos (com
trigger de `comment_count`), contadores de salvos (`save_count`) e de
curtidas, e campos de conclusão/edição de projeto (`completed_at`,
`updated_at`). Crie também o bucket `project-media` (o SQL já cria,
público para leitura).

> Os mocks continuam claramente separados em
> `lib/data/repositories/mock/` e seguem sendo o padrão para
> desenvolvimento offline.

## Estrutura

```
lib/
  app/          # tema, tokens, router, shell de navegação, config
  core/widgets/ # design system (AppButton, ProjectCard, RankEmblem,
                # RankAvatar/RankConfig, cards com hover...)
  core/utils/   # regras de nível/XP e formatadores pt-BR
  core/services/# regras centralizadas (badges)
  data/         # modelos, repositórios (mock + supabase), providers
  features/     # auth, status, projects, school, materials, messages,
                # ranking, profile, search, notifications, library
supabase/
  schema.sql    # banco completo (DDL + RLS + triggers + RPCs)
```

## Áreas do app

- **Status** — dashboard do usuário (nível, XP total, progresso no rank,
  atividade, estatísticas incl. respostas corretas em Materiais).
  O card **"Continue seu projeto"** aponta para a **edição** do último
  projeto em andamento e mostra 100% apenas quando ele é concluído.
- **Projetos** — feed anti-scroll, criação, **edição** e detalhe de
  projetos, incluindo o tipo **Texto** (card editorial colorido + página
  de leitura). Cada projeto tem contadores públicos de **curtidas**,
  **comentários** e **saves** — curtir e comentar são independentes de
  avaliação (comentário não tem nota).
- **Editar projeto** (`/projetos/:id/editar`) — autor e colaboradores
  editam título, subtítulo, descrição/texto e o **repositório de
  arquivos** (adicionar imagens/links ou remover itens); aqui também fica
  o botão **"Marcar como 100% concluído"** (com opção de reabrir) e, só
  para o **autor principal**, a **exclusão do projeto** (zona de perigo,
  com confirmação obrigatória — remove junto avaliações, comentários,
  salvamentos e denúncias, sem deixar referências quebradas).
- **Denúncias** — o menu ⋮ dos cards e a página do projeto permitem
  **"Reportar projeto"** (motivos como conteúdo inadequado, assédio,
  spam etc., com descrição opcional em "Outro"). Reportar nunca remove o
  projeto: envia para análise da moderação (Developers), sem expor a
  identidade de quem denunciou. O mesmo usuário não acumula denúncias
  pendentes no mesmo projeto.
- **Comentários** — cada usuário apaga o **próprio** comentário e o
  **autor principal do projeto** pode apagar qualquer comentário dentro
  dele (regras centralizadas em `PermissionService`); a lista e o
  contador atualizam sem reload.
- **Biblioteca** — projetos salvos (relação privada usuário ↔ projeto),
  com filtros por tipo e estado vazio com atalho para Descobrir. Se o
  autor excluir o projeto, ele some da Biblioteca de todos (a relação
  nunca vira uma cópia independente do conteúdo).
- **Escola** — comunidade da escola por `schoolId`: **estatísticas
  reais** (alunos únicos no Conecta, projetos publicados pelos autores
  da escola e a média de todas as avaliações — somatório ÷ quantidade,
  nunca média de médias), ranking interno (só membros da escola, por XP)
  e **comunicados oficiais** (só Developers publicam/editam/removem).
  Selecionar ou trocar a escola no perfil atualiza tudo automaticamente.
- **Materiais** — postagens da comunidade (materiais, perguntas e pedidos)
  com respostas; a moderação seleciona a melhor resposta.
- **Mensagens** — conversas diretas **e grupos**: criar grupo envia
  **convites** (aceitar/ignorar) — selecionar alguém nunca o coloca
  dentro do grupo automaticamente.
- **Notificações** — sino na topbar com contador de não lidas (9+/99+),
  painel com tipos (mensagem, mensagem de grupo agregada, avaliação de
  projeto, convite de grupo, sistema, comunicado escolar), estados
  lida/não lida, "marcar todas como lidas" e navegação ao tocar.
- **Pesquisa** — busca global (usuários, projetos, materiais) com
  debounce, preview agrupado na topbar e página completa com filtros.
- **Ranking** — pódio e tabela global/escola por rank; no mobile a lista
  mostra posição, nome (colorido nos ranks altos), rank, nível e XP.
- **Perfil** — avatar + moldura de rank, bio multilinha, badges
  conquistados (linha horizontal), escola, Instagram, X e contato;
  **Editar perfil** com foto, bio e seletor de escola por busca
  (inclui as escolas de São Luís do Quitunde/AL: E.E.B. Padre José de
  Anchieta, E.E. Messias de Gusmão e E.E. Profª Maria Margarida Silva
  Pugliesi).

## Cargos e permissões (rank ≠ cargo)

Cargos: **USER** (usuário normal) e **DEVELOPER** (desenvolvedor oficial +
moderação). Não existe cargo "Moderator" separado. Toda decisão de
permissão passa pelo `PermissionService` (core/services) — nunca por
`if (role == ...)` espalhado nas telas. O cargo é definido exclusivamente
no backend (Supabase Auth + RLS quando conectado): nenhum e-mail é
comparado no código e o usuário nunca pode promover a própria conta
(a tela de edição de perfil não oferece escolha de cargo).

## Identidade visual

- **Montserrat** global com hierarquia de pesos (títulos Bold/ExtraBold,
  nomes SemiBold, texto Regular/Medium).
- **Paleta pastel** centralizada em `AppColors` (bege, creme, azul claro,
  verde pastel, roxo claro, lavanda, grafite) — sem neon/glow.
- **Nomes com cor de Elo alto**: Esmeralda (verde suave), Diamante
  (azul-gelo) e Sublime (lavanda); Bronze/Ouro usam a cor normal. A regra
  vive no componente `UserDisplayName` — único lugar onde ela existe.
- **Selo [DEV]**: pequeno e pastel, junto ao nome de Developers.

## Molduras de rank

Cada usuário tem uma moldura de avatar que corresponde ao rank dele
(Bronze, Ouro, Esmeralda, Diamante, Sublime). A lógica é centralizada:

```
RankTier → rankConfigs (core/widgets/rank_frame.dart) → RankAvatar
```

O componente `RankAvatar` recebe avatar + rank e escolhe a moldura
automaticamente — usado no Status, Ranking, Projetos, Perfil, detalhes e
na topbar. Para adicionar um rank novo, basta incluir uma entrada em
`rankConfigs` e um caso no painter da moldura.

## Animação de hover

Cards e painéis expandem levemente (escala 1,02) com sombra suave ao
passar o mouse — 200ms, curva easeOutCubic, sem empurrar o layout
(Transform não altera o fluxo). Em telas touch nada muda.

## Regras de gamificação

- **XP**: projetos publicados geram XP pela avaliação média:
  1–5 → +30 · 6–8 → +50 · 9–10 → +200. Quem **realiza** uma avaliação
  ganha +15 XP (somente na primeira avaliação por projeto — editar a nota
  nunca concede XP de novo). XP é acumulativo e nunca é removido.
- **Nível**: 200 XP por nível.
- **Rank** (limiares de XP total, centralizados em `rankConfigs`):
  Bronze 0–499 · Ouro 500 (+500) · Esmeralda 1.300 (+800) ·
  Diamante 2.200 (+900) · Sublime 3.200 (+1.000).
  A barra de progresso do rank mostra o XP dentro do rank atual e
  zera a cada promoção; o XP total continua acumulando para sempre.
- **Avaliações**: uma por usuário por projeto (editar atualiza a mesma).
  Autor e colaboradores não podem avaliar o próprio projeto — a regra é
  validada na camada de dados, não apenas escondida na interface.

## Materiais e melhor resposta

Postagens de Materiais aceitam várias respostas, mas só a moderação
(moderador/admin) pode selecionar **a** melhor resposta — no máximo uma
por postagem, sempre recomputada do estado real (anti-exploit). A resposta
escolhida exibe ✅ "A moderação considera essa a melhor resposta ou correta."
e o selo "Resposta correta".

## Badges

Conquistas com progresso e estados bloqueado/desbloqueado, avaliadas pela
camada de dados (mock local ou RPC no Supabase) — nunca pela UI:
Autor · Mente Brilhante I–III (médias ≥ 7) · The Thinker I–III (≥ 8) ·
Aluno Aplicado I (1ª postagem em Materiais) · Aluno Aplicado II
(5 respostas selecionadas) · The Mastermind (20) · Eu tenho e você?
(média final exatamente 10,0). Desbloqueio é único e permanente.

## Projetos do tipo Texto

Título obrigatório, subtítulo opcional, campo de texto longo
(limite centralizado em `AppLimits.textProjectMaxLength`) e cor do card
editorial (Marrom/Azul/Vinho/Amarelo — paleta centralizada em
`TextCardPalette`) com preview ao vivo. No feed, o card mostra um trecho
com "Continuar lendo →"; a página de detalhe usa uma coluna de leitura
confortável.

## Princípio anti-scroll

O feed é dividido em sessões finitas ("12 projetos para descobrir hoje").
Ao concluir a sessão, o app sugere ações produtivas (criar, continuar
projeto, ranking) em vez de scroll infinito.
