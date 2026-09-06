# SPEC — Projeto Autoral (MVP)

Plataforma educacional/social que transforma estudantes (13–18 anos) em criadores.
Estética: "GitHub para estudantes + comunidade acadêmica + progressão de videogame".
Tudo em **português do Brasil**. Dark mode como tema principal (único tema do MVP).

## 1. Stack técnica

- Flutter 3.47.x stable / Dart ^3.9.0
- `go_router` (navegação), `flutter_riverpod` (estado/DI), `google_fonts` (Inter),
  `supabase_flutter` (backend), `cached_network_image`, `file_picker`,
  `image_picker`, `intl`, `url_launcher`, `uuid`
- Backend: **Supabase** (Postgres + Auth + Storage). SQL em `supabase/schema.sql`.
- **Modo demo**: flag `USE_MOCK` (String.fromEnvironment, default `true`).
  Com `true`, os repositórios retornam dados mock em memória (app roda sem backend).
  Repositórios Supabase prontos, ativados com:
  `flutter run --dart-define=USE_MOCK=false --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## 2. Arquitetura (feature-first)

```
lib/
  main.dart                 # bootstrap, ProviderScope, AppConfig (dart-defines)
  app/
    app.dart                # MaterialApp.router, tema
    router.dart             # go_router: rotas + ShellRoute (AppShell)
    theme.dart              # AppTheme.dark() usando tokens
    tokens.dart             # AppColors, AppSpacing, AppRadii, AppTextStyles
  core/
    widgets/                # design system (contratos na seção 6)
    utils/                  # formatters (xp, tempo relativo "há 2 horas"), level math
  data/
    models/                 # UserProfile, Project, ProjectMedia, Rating, XpEvent, RankInfo
    repositories/           # interfaces: AuthRepository, ProfileRepository,
                            # ProjectRepository, RankingRepository
    repositories/mock/      # implementações in-memory com seed data
    repositories/supabase/  # implementações Supabase
    providers.dart          # Providers Riverpod escolhendo mock vs supabase via AppConfig
  features/
    auth/                   # LoginPage, SignUpPage
    status/                 # StatusPage (dashboard)
    projects/               # DiscoverPage, ProjectDetailPage, CreateProjectPage
    ranking/                # RankingPage
    profile/                # ProfilePage
supabase/
  schema.sql                # DDL + policies + seed mínimo
```

Regra de ouro: **features nunca falam com Supabase diretamente** — só com as
interfaces de repositório via Riverpod. Mock e Supabase implementam os mesmos contratos.

## 3. Design tokens (fiéis ao brief)

```dart
// AppColors
bg        = #0D1117   // background principal
bgAlt     = #101418
surface1  = #151A20
surface2  = #191F26
surface3  = #202730
border    = #2B343D
textPrimary   = #F5F7FA
textSecondary = #8B97A5
accent      = violeta profundo (#7C3AED como base)
accentSoft  = magenta suave (#C084FC)
// ranks
rankBronze    = #B08D57 (bronze/cobre)
rankOuro      = #E3B341 (dourado)
rankEsmeralda = #2FBF8F (verde-esmeralda)
rankDiamante  = #3FC1D8 (azul/ciano)
rankSublime   = gradiente dourado-claro→branco c/ detalhe violeta (#F5D98B/#FAFAFA/#8B5CF6)
```

- Raios: cards 16, inputs/botões 12, chips 999 (pill).
- Bordas finas (1px `border`) em cards; sombras quase nulas.
- Tipografia: Inter (google_fonts). Hierarquia: título 24/700, seção 18/600,
  corpo 14/400, label 12/500, dados grandes 28/700.
- Gradiente roxo→magenta **apenas** em: botão "+ Criar", emblema Sublime, destaques especiais.
- Spacing scale: 4, 8, 12, 16, 20, 24, 32.

## 4. Gamificação — regras de negócio

### XP
- XP é acumulativo e **nunca** é removido.
- XP por projeto publicado, baseado na avaliação média (1–10):
  - média 1–5 → +30 XP
  - média 6–8 → +50 XP
  - média 9–10 → +200 XP
- Modal "Como ganhar XP?" exibe essas regras.
- Timeline "Atividade de XP": `+200 XP • Projeto "..." • Avaliação média: 9.4`.

### Nível (Level)
- Fórmula determinística: cada nível custa **200 XP**.
  `level(xp) = xp ~/ 200 + 1`; progresso no nível = `xp % 200` / 200.
- Ex.: 3.450 XP → Nível 18, 50/200, "150 XP para o Nível 19".

### Rank (competitivo)
- Ordem: Bronze → Ouro → Esmeralda → Diamante → Sublime.
- Rank derivado da posição percentual do usuário no ranking global de XP:
  top 1% Sublime, top 5% Diamante, top 20% Esmeralda, top 50% Ouro, resto Bronze.
- Cada rank: cor própria + emblema (formas geométricas evolutivas, mesma família
  gráfica; Sublime = estrela/sol estilizado simétrico; sem coroas genéricas).
- Emblemas em CustomPainter ou composição de widgets (sem assets externos), tamanhos 64/40/24.

## 5. Modelos de dados

```dart
enum ProjectType { estudantil, autoral, docente }
enum ProjectCategory { ciencias, matematica, tecnologia, historia, arte,
                       literatura, meioAmbiente, engenharia, programacao, outros }
enum RankTier { bronze, ouro, esmeralda, diamante, sublime }

class UserProfile {
  final String id;            // uuid (auth.users.id no Supabase)
  final String name;
  final String username;      // @unique, sem espaços
  final String? avatarUrl;
  final int xpTotal;
  final String? school;
  final DateTime createdAt;
  // derivados (utils/level_math.dart): level, xpInLevel, xpToNext
}

class Project {
  final String id;
  final String authorId;
  final String title;
  final String subtitle;
  final String description;   // markdown-lite ou texto
  final ProjectCategory category;
  final ProjectType type;
  final List<String> tags;
  final List<ProjectMedia> media;
  final List<UserProfile> collaborators;
  final int likeCount;
  final int commentCount;
  final int ratingCount;
  final double ratingAvg;     // 0..10
  final DateTime createdAt;
}

class ProjectMedia {
  final String id;
  final String url;           // storage ou mock asset/network
  final ProjectMediaKind kind; // image, video, pdf, file, link, github
  final String? label;
}

class Rating {
  final String id;
  final String projectId;
  final String userId;
  final int score;            // 1..10
  final String? comment;
  final DateTime createdAt;
}

class XpEvent {
  final String id;
  final String userId;
  final int amount;
  final String reason;        // ex.: 'Projeto "X" — avaliação média 9.4'
  final String? projectId;
  final DateTime createdAt;
}

class LeaderboardEntry {
  final int position;
  final UserProfile user;
  final RankTier rank;
  final int projectCount;
  final double ratingAvg;
  final int xpTotal;
  final bool isCurrentUser;
}
```

## 6. Contratos do design system (lib/core/widgets/)

Todos com tema do `tokens.dart`, estados default/hover/pressed/selected/disabled/loading
onde fizer sentido (hover só desktop/web).

- `AppButton({label, onPressed, variant: primary|secondary|ghost, icon, loading})`
  - primary = gradiente roxo→magenta, texto branco. Usado em "+ Criar" e CTAs principais.
- `AppCard({child, padding, onTap})` — surface1, border 1px, radius 16.
- `AppTextField({controller, hint, label, maxLines, prefixIcon})`
- `AppSearchField({controller, hint, onChanged})`
- `AppTag({label})` — pill surface3, texto 12 `#8B97A5→textPrimary` no hover.
- `AppFilterChip({label, selected, onTap})`
- `AppAvatar({url, size, name})` — fallback com iniciais.
- `RankBadge({tier, size})` — chip com cor do rank + label ("DIAMANTE").
- `RankEmblem({tier, size})` — emblema geométrico (CustomPainter), 24/40/64.
- `XpBar({current, max, label})` — barra de progresso com gradiente sutil.
- `StatCard({icon, label, value})`
- `ProjectCard({project, author, onTap, onLike, onSave})` — ver seção 7.
- `CollaboratorAvatarGroup({users, maxVisible})` — avatares sobrepostos "+2".
- `RatingStars({avg, count})` — representação 9.1/10 com barras/estrelas discretas.
- `RankingRow({entry, highlight})`
- `UserRow({user, trailing})`
- `AppModal.show(context, {title, child})`, `AppToast.show(context, message)`
- `AppTabs({tabs, index, onChanged})`, `EmptyState({icon, title, subtitle, action})`
- `AppShell` — desktop: sidebar recolhível + topbar (busca global, notificações,
  "+ Criar", avatar/username/menu); mobile: bottom nav com botão central Criar destacado.
  Breakpoints: mobile <768, tablet 768–1199, desktop ≥1200.

## 7. Telas do MVP (rotas go_router)

| Rota | Tela | Notas |
|---|---|---|
| `/login` | LoginPage | email+senha; em mock, qualquer email entra como Kevin |
| `/signup` | SignUpPage | nome, username, email, senha |
| `/status` | StatusPage | home pós-login |
| `/projetos` | DiscoverPage | feed anti-scroll |
| `/projetos/novo` | CreateProjectPage | wizard 4 etapas |
| `/projetos/:id` | ProjectDetailPage | + modal avaliação |
| `/ranking` | RankingPage | pódio + tabela |
| `/perfil/:username` | ProfilePage | público |
| redirect `/` → `/status` (logado) ou `/login` | | |

### 7.1 StatusPage (ordem visual obrigatória)
1. Header "Olá, {nome} 👋" / "Veja sua evolução como criador."
2. Hero card: avatar, nome, @username, Nível, RankBadge, XP total, posição no rank
   + `XpBar` grande ("NÍVEL 18 — 50/200 XP — 150 XP para o Nível 19")
   + botão "Como ganhar XP?" (modal com regras).
3. Card "Continue seu projeto" (projeto em andamento, progresso 72%, última edição)
   ao lado de "+ Começar novo projeto" (desktop: lado a lado; mobile: empilhados).
4. Grid de `StatCard`: Projetos publicados / Avaliações recebidas / Curtidas /
   Avaliação média / XP total (mobile: grid 2 colunas).
5. "Atividade de XP" (timeline dos últimos XpEvents).
6. "Ranking" resumido (top 5 + linha do usuário destacada) com link "Ver ranking completo".

### 7.2 DiscoverPage ("Descobrir Projetos")
- Header: "Veja o que outros estudantes estão criando."
- Chips: Para você / Pódio / Estudantis / Autorais / Docentes / Recentes.
- Filtros de categoria (chips) + `AppSearchField` ("Buscar projetos, criadores ou temas...").
- **Anti-scroll**: sessão finita de 12 projetos ("12 projetos para descobrir hoje").
  Fim da lista → card "Você concluiu sua sessão de descoberta." com ações:
  + Criar um projeto / Continuar meu projeto / Explorar ranking;
  botão secundário "Ver mais projetos" (paginação explícita).
- Grid: desktop 3 col, tablet 2, mobile 1. Sem scroll horizontal.
- `ProjectCard`: header (avatar, nome, @user, RankBadge, tempo relativo, "…"),
  título, subtítulo, tags, mídia com indicador "1/6", `RatingStars`,
  curtir/comentários/salvar, `CollaboratorAvatarGroup`, botão "Ver projeto".

### 7.3 CreateProjectPage — wizard "Novo Projeto" (4 etapas com stepper)
1. **Informações**: título, subtítulo, descrição, categoria (dropdown), tags,
   tipo (Estudantil/Autoral/Docente).
2. **Repositório**: área drag-and-drop (web/desktop) + seletor de arquivos;
   fotos, vídeos, PDF, arquivos, links externos, link GitHub.
   Lista de arquivos em estrutura de repositório (/media, /documentos, README, github).
3. **Colaboradores**: busca de usuários, `UserRow` com botão Adicionar (estilo GitHub).
4. **Publicação**: preview do `ProjectCard` + botão "Publicar projeto".
- Ao publicar (mock): insere no repositório e navega para o detalhe.

### 7.4 ProjectDetailPage
- Header: título, autor (UserRow), RankBadge, colaboradores, tags.
- Hero de mídia (carrossel com indicador).
- Seções: Sobre / Objetivo / Processo / Resultados (texto), Repositório (arquivos/links).
- Avaliações: média destacada, lista de ratings.
- CTA "Avaliar projeto" → modal com seletor 1–10 (botões numerados) + comentário
  opcional → ao avaliar, recalcula média e gera XpEvent conforme regras.

### 7.5 RankingPage
- Filtros: Global / Minha Escola / Amigos + filtro por rank (todos os tiers).
- Pódio 2º/1º/3º (RankEmblem 64, nome, XP) depois tabela:
  Posição | Criador | Nível | Projetos | Avaliação | XP | Rank
- Linha do usuário atual destacada discretamente (surface2 + borda accent).
- Copy: competição é secundária à evolução pessoal.

### 7.6 ProfilePage
- Header com avatar grande, nome, @username, RankEmblem + RankBadge, XP, nível.
- Stats, lista de projetos do usuário (ProjectCard), timeline de XP.

### 7.7 Auth
- Login/signup simples, validação básica, dark theme. Mock: login instantâneo.
- Supabase: `supabase.auth.signInWithPassword` / `signUp`; cria row em `profiles`.

## 8. Supabase schema (supabase/schema.sql)

Tabelas: `profiles`, `projects`, `project_media`, `project_collaborators`,
`ratings`, `xp_events`. RLS habilitado:
- leitura pública de projetos/public; escrita apenas dono/colaborador;
- ratings: 1 por usuário por projeto (unique project_id+user_id), autor não se auto-avalia;
- xp_events: inseridos via trigger/function quando rating muda a média (ou RPC
  `recalc_project_xp(project_id)`).
Storage bucket `project-media` (público para leitura).

## 9. Dados mock (seed)

- Usuário atual: Kevin Oliveira, @kevinoliveira, 3.450 XP, Nível 18, Diamante #2.
- 15+ usuários variados cobrindo todos os ranks; 20+ projetos variados
  (inclui "Estação meteorológica de baixo custo" e "Filtro de água sustentável");
  imagens via picsum.photos com seed estável.
- XpEvents de exemplo, ratings suficientes para médias realistas.

## 10. Qualidade e entrega

- `flutter analyze` sem erros; `flutter build web --release` deve compilar.
- Sem pacotes além dos listados sem aprovação. Sem `print` soltos (usar `debugPrint`).
- Microcopy 100% pt-BR, motivacional e ligada à produção (ver brief):
  "Continue criando", "Transforme uma ideia em projeto", "Construa junto".
  Proibido: streaks, autoplay, infinite scroll, "Fique conectado".
- README.md com instruções de execução (inclui Arch Linux) e de configuração do Supabase.

## 11. Plano de branches (worktrees)

1. `main`: scaffold (main agent): pubspec, tokens, theme, router, app shell, main.
2. `feat/design-system` (agente A): todos os widgets de `core/widgets` + gallery page
   temporária para validação.
3. `feat/data` (agente B): models, repos mock+supabase, providers, schema.sql, utils.
4. `feat/auth-status` (agente C): login, signup, StatusPage, ProfilePage.
5. `feat-projects-ranking` (agente D): Discover, Create, Detail, Ranking.
Merge order: design-system → data → features. Main agent integra e roda analyze/build.
