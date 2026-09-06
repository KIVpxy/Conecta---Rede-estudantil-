import '../../models/models.dart';

/// Banco de dados em memória (modo demo).
/// Dados seed fiéis aos exemplos da SPEC §9.
class MockDatabase {
  MockDatabase._() {
    _seed();
  }

  static final MockDatabase instance = MockDatabase._();

  late final List<UserProfile> users;
  late final List<Project> projects;
  late final List<Rating> ratings;
  late final List<XpEvent> xpEvents;
  late final List<MaterialPost> materialPosts;
  late final List<MaterialAnswer> materialAnswers;
  late final List<Conversation> conversations;
  late final List<Message> messages;
  late final List<School> schools;
  late final List<SchoolAnnouncement> schoolAnnouncements;
  late final List<GroupMember> groupMembers;
  late final List<GroupInvite> groupInvites;
  late final List<AppNotification> notifications;
  late final List<SavedProject> savedProjects;
  late final List<ProjectComment> comments;

  /// Denúncias de projetos aguardando/já analisadas pela moderação.
  final List<ProjectReport> reports = [];

  /// Desbloqueios de badges persistidos: userId → badgeId → data.
  final Map<String, Map<BadgeId, DateTime>> badgeUnlocks = {};

  /// Usuário logado no modo demo.
  static const String currentUserId = 'u-kevin';

  UserProfile get currentUser =>
      users.firstWhere((u) => u.id == currentUserId);

  static DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now()
          .subtract(Duration(days: days, hours: hours, minutes: minutes));

  // picsum.photos é CORS-friendly (funciona no Flutter Web).
  static String _avatar(String seed) =>
      'https://picsum.photos/seed/avatar-$seed/150/150';

  void _seed() {
    // ---------------- Escolas (§8) ----------------
    schools = [
      const School(
        id: 'esc-dumont',
        name: 'E.E. Santos Dumont',
        city: 'Maceió',
        state: 'AL',
      ),
      const School(
        id: 'esc-maria',
        name: 'Colégio Maria Montessori',
        city: 'Maceió',
        state: 'AL',
      ),
      const School(
        id: 'esc-lobato',
        name: 'E.E. Monteiro Lobato',
        city: 'Arapiraca',
        state: 'AL',
      ),
      const School(
        id: 'esc-cvc',
        name: 'Colégio Vera Cruz',
        city: 'São Paulo',
        state: 'SP',
      ),
      const School(
        id: 'esc-objetivo',
        name: 'Colégio Objetivo',
        city: 'Recife',
        state: 'PE',
      ),
      const School(
        id: 'esc-militar',
        name: 'Colégio Militar Tiradentes',
        city: 'Belo Horizonte',
        state: 'MG',
      ),
      // Escolas reais de São Luís do Quitunde (AL) — pedido do usuário.
      const School(
        id: 'esc-anchieta',
        name: 'Escola de Educação Básica Padre José de Anchieta',
        city: 'São Luís do Quitunde',
        state: 'AL',
      ),
      const School(
        id: 'esc-messias',
        name: 'Escola Estadual Messias de Gusmão',
        city: 'São Luís do Quitunde',
        state: 'AL',
      ),
      const School(
        id: 'esc-pugliesi',
        name: 'Escola Estadual Professora Maria Margarida Silva Pugliesi',
        city: 'São Luís do Quitunde',
        state: 'AL',
      ),
    ];

    // ---------------- Usuários ----------------
    // O cargo Developer existe aqui como DADO do seed (simula a coluna
    // `role` da tabela profiles no Supabase). NUNCA é derivado de e-mail
    // ou de qualquer comparação no código (§44).
    final named = <UserProfile>[
      UserProfile(
        id: currentUserId,
        name: 'Kevin Oliveira',
        username: 'kevinoliveira',
        avatarUrl: _avatar('kevin'),
        xpTotal: 2500,
        schoolId: 'esc-dumont',
        bio: 'Desenvolvedor do Conecta 🛠️\n'
            'Estudante do 3º ano, apaixonado por tecnologia e educação.\n'
            'Sempre aberto para ajudar em projetos!',
        instagram: 'kevin.dev',
        xHandle: 'kevindev',
        role: UserRole.developer,
        createdAt: _ago(days: 300),
      ),
      UserProfile(
        id: 'u-ana',
        name: 'Ana Beatriz',
        username: 'anabeatriz',
        avatarUrl: _avatar('anabeatriz'),
        xpTotal: 3400,
        schoolId: 'esc-dumont',
        bio: 'Sublime no Conecta ✨\nAmo ciências e projetos ambientais.\n'
            '3º ano do ensino médio.',
        instagram: 'ana.beatriz',
        createdAt: _ago(days: 200),
      ),
      UserProfile(
        id: 'u-pedro',
        name: 'Pedro Henrique',
        username: 'pedrohenrique',
        avatarUrl: _avatar('pedrohenrique'),
        xpTotal: 2800,
        schoolId: 'esc-dumont',
        bio: 'Matemática e engenharia 📐\nCapitão da equipe de olimpíadas.',
        xHandle: 'pedrohenrique',
        createdAt: _ago(days: 200),
      ),
      UserProfile(
        id: 'u-julia',
        name: 'Júlia Santos',
        username: 'juliasantos',
        avatarUrl: _avatar('juliasantos'),
        xpTotal: 2400,
        schoolId: 'esc-dumont',
        bio: 'Estudante de programação 💻\nCriadora do app de estudos.',
        instagram: 'julia.dev',
        xHandle: 'juliasantos',
        createdAt: _ago(days: 200),
      ),
      UserProfile(
        id: 'u-lucas',
        name: 'Lucas Ferreira',
        username: 'lucasferreira',
        avatarUrl: _avatar('lucasferreira'),
        xpTotal: 1800,
        schoolId: 'esc-dumont',
        bio: 'Arduino, robótica e um pouco de caos organizado.',
        createdAt: _ago(days: 200),
      ),
      _user('u-mariana', 'Mariana Costa', 'marianacosta', 1500),
      _user('u-gabriel', 'Gabriel Almeida', 'gabrielalmeida', 1600),
      _user('u-laura', 'Laura Ribeiro', 'lauraribeiro', 1400),
      _user('u-matheus', 'Matheus Souza', 'matheussouza', 1300),
      _user('u-isabela', 'Isabela Rocha', 'isabelarocha', 900),
      _user('u-rafael', 'Rafael Lima', 'rafaellima', 700),
      _user('u-camila', 'Camila Duarte', 'camiladuarte', 600),
      _user('u-enzo', 'Enzo Martins', 'enzomartins', 450),
      _user('u-sofia', 'Sofia Nogueira', 'sofianogueira', 300),
      _user('u-davi', 'Davi Cardoso', 'davicardoso', 200),
      _user('u-helena', 'Helena Pires', 'helenapires', 120),
    ];

    // Usuários gerados para dar volume ao ranking (60 no total).
    const firstNames = [
      'Arthur', 'Alice', 'Miguel', 'Manuela', 'Theo', 'Valentina', 'Gael',
      'Antonella', 'Heitor', 'Cecília', 'Ravi', 'Liz', 'Bernardo', 'Aurora',
      'Noah', 'Clarice', 'Lorenzo', 'Eloá', 'Benício', 'Maria', 'Otávio',
      'Esther', 'Levi', 'Agatha', 'Nicolas', 'Lavínia', 'Henry', 'Malu',
      'Caio', 'Elisa', 'Vicente', 'Allana', 'Bento', 'Sarah', 'Dante',
      'Rebeca', 'Otto', 'Yasmin', 'Noel', 'Melissa', 'Igor', 'Bianca',
    ];
    final generated = <UserProfile>[
      for (var i = 0; i < firstNames.length; i++)
        _user(
          'u-gen-$i',
          '${firstNames[i]} ${['Silva', 'Pereira', 'Barbosa', 'Moura', 'Teixeira'][i % 5]}',
          '${firstNames[i].toLowerCase()}${i + 1}',
          1800 - i * 55 > 0 ? 1800 - i * 55 : 40 + (i * 13) % 100,
        ),
    ];

    users = [...named, ...generated]
      ..sort((a, b) => b.xpTotal.compareTo(a.xpTotal));

    // ---------------- Projetos ----------------
    Project proj(
      String id,
      String authorId,
      String title,
      String subtitle,
      ProjectCategory cat,
      ProjectType type,
      List<String> tags,
      int mediaCount,
      int likes,
      int comments,
      int ratingCount,
      double ratingAvg,
      DateTime createdAt, {
      List<String> collaborators = const [],
    }) {
      return Project(
        id: id,
        authorId: authorId,
        title: title,
        subtitle: subtitle,
        description:
            '## Sobre o projeto\n$subtitle\n\n## Objetivo\nAplicar conhecimentos de ${cat.label} em uma solução real para a escola.\n\n## Processo\nPesquisa, prototipagem, testes e iteração com feedback dos colegas.\n\n## Resultados\nProjeto concluído com apresentação na feira de ciências e ótima aceitação da comunidade escolar.',
        category: cat,
        type: type,
        tags: tags,
        media: [
          for (var i = 0; i < mediaCount; i++)
            ProjectMedia(
              id: '$id-m$i',
              url: 'https://picsum.photos/seed/$id-$i/1200/675',
              kind: ProjectMediaKind.image,
              label: 'Registro ${i + 1}',
            ),
        ],
        collaborators: [
          for (final c in collaborators) users.firstWhere((u) => u.id == c),
        ],
        likeCount: likes,
        commentCount: comments,
        ratingCount: ratingCount,
        ratingAvg: ratingAvg,
        createdAt: createdAt,
      );
    }

    projects = [
      proj(
        'p1',
        'u-lucas',
        'Estação meteorológica de baixo custo',
        'Construção de uma estação utilizando Arduino para monitorar temperatura e umidade da escola.',
        ProjectCategory.tecnologia,
        ProjectType.estudantil,
        ['ProjetoEstudantil', 'Tecnologia', 'Ciência', 'Arduino'],
        6,
        23,
        18,
        127,
        9.1,
        _ago(days: 2),
        collaborators: ['u-pedro', 'u-ana', 'u-mariana', 'u-julia'],
      ),
      proj(
        'p2',
        currentUserId,
        'Filtro de água sustentável',
        'Sistema de filtragem com materiais recicláveis para a cantina da escola.',
        ProjectCategory.ciencias,
        ProjectType.estudantil,
        ['MeioAmbiente', 'Sustentabilidade'],
        4,
        87,
        12,
        94,
        9.4,
        _ago(days: 5),
        collaborators: ['u-ana'],
      ),
      proj(
        'p3',
        currentUserId,
        'História de Alagoas',
        'Documentário curto sobre a formação cultural do estado.',
        ProjectCategory.historia,
        ProjectType.autoral,
        ['História', 'Audiovisual'],
        3,
        45,
        9,
        61,
        7.8,
        _ago(days: 12),
      ),
      proj(
        'p4',
        'u-ana',
        'Monitoramento do Rio Santo Antônio',
        'Coleta e análise de amostras de água do rio ao longo de 3 meses.',
        ProjectCategory.meioAmbiente,
        ProjectType.estudantil,
        ['Biologia', 'Química', 'Rio'],
        5,
        112,
        27,
        143,
        9.6,
        _ago(hours: 8),
        collaborators: ['u-gabriel', 'u-laura'],
      ),
      proj(
        'p5',
        'u-julia',
        'App de organização de estudos',
        'Aplicativo em Flutter para planejar rotinas de estudo para o ENEM.',
        ProjectCategory.programacao,
        ProjectType.autoral,
        ['Flutter', 'Produtividade', 'ENEM'],
        3,
        64,
        21,
        88,
        8.9,
        _ago(days: 1),
      ),
      proj(
        'p6',
        'u-pedro',
        'Ponte de palitos: engenharia aplicada',
        'Estudo estrutural e construção de ponte com carga máxima de 12kg.',
        ProjectCategory.engenharia,
        ProjectType.estudantil,
        ['Física', 'Estruturas'],
        4,
        39,
        7,
        52,
        8.2,
        _ago(days: 3),
      ),
      proj(
        'p7',
        'u-mariana',
        'Quadrinhos da Revolução Francesa',
        'HQ autoral de 24 páginas explicando a queda da Bastilha.',
        ProjectCategory.arte,
        ProjectType.autoral,
        ['HQ', 'História', 'Arte'],
        6,
        156,
        34,
        178,
        9.3,
        _ago(days: 4),
        collaborators: ['u-isabela'],
      ),
      proj(
        'p8',
        'u-gabriel',
        'Criptografia com Python',
        'Implementação didática de cifras clássicas e RSA simplificado.',
        ProjectCategory.programacao,
        ProjectType.estudantil,
        ['Python', 'Matemática', 'Segurança'],
        2,
        51,
        11,
        73,
        8.7,
        _ago(days: 6),
      ),
      proj(
        'p9',
        'u-laura',
        'Poesia marginal: análise e criação',
        'Coletânea de poemas autorais inspirados no movimento da poesia marginal.',
        ProjectCategory.literatura,
        ProjectType.autoral,
        ['Poesia', 'Literatura'],
        3,
        28,
        6,
        41,
        7.4,
        _ago(days: 7),
      ),
      proj(
        'p10',
        'u-matheus',
        'Foguete de água: física na prática',
        'Lançamento controlado com análise de trajetória e alcance.',
        ProjectCategory.ciencias,
        ProjectType.estudantil,
        ['Física', 'Experimento'],
        4,
        73,
        15,
        96,
        8.8,
        _ago(days: 8),
      ),
      proj(
        'p11',
        'u-isabela',
        'Mural da biodiversidade do cerrado',
        'Pintura coletiva com espécies nativas catalogadas pela turma.',
        ProjectCategory.arte,
        ProjectType.estudantil,
        ['Arte', 'Biologia'],
        5,
        92,
        19,
        110,
        9.0,
        _ago(days: 9),
        collaborators: ['u-camila', 'u-helena'],
      ),
      proj(
        'p12',
        'u-rafael',
        'Calculadora de pegada de carbono',
        'Site que estima a pegada de carbono dos estudantes da escola.',
        ProjectCategory.tecnologia,
        ProjectType.estudantil,
        ['Web', 'MeioAmbiente'],
        3,
        47,
        8,
        66,
        8.1,
        _ago(days: 10),
      ),
      proj(
        'p13',
        'u-camila',
        'Guia de funções logarítmicas ilustrado',
        'Material visual com resumos e exercícios resolvidos de logaritmos.',
        ProjectCategory.matematica,
        ProjectType.docente,
        ['Matemática', 'MaterialDidático'],
        2,
        134,
        25,
        201,
        9.5,
        _ago(days: 11),
      ),
      proj(
        'p14',
        'u-enzo',
        'Robô seguidor de linha',
        'Robô com sensores infravermelhos para competição de robótica.',
        ProjectCategory.engenharia,
        ProjectType.estudantil,
        ['Robótica', 'Arduino'],
        4,
        58,
        13,
        79,
        8.4,
        _ago(days: 13),
      ),
      proj(
        'p15',
        'u-sofia',
        'Bioma marinho: maquete interativa',
        'Maquete com QR codes que levam a vídeos explicativos.',
        ProjectCategory.ciencias,
        ProjectType.estudantil,
        ['Biologia', 'Maquete'],
        6,
        66,
        14,
        84,
        8.6,
        _ago(days: 14),
      ),
      proj(
        'p16',
        'u-davi',
        'História em quadrinhos da matemática',
        'Personagens resolvem problemas reais usando equações.',
        ProjectCategory.matematica,
        ProjectType.autoral,
        ['HQ', 'Matemática'],
        5,
        37,
        5,
        48,
        7.2,
        _ago(days: 15),
      ),
      proj(
        'p17',
        'u-helena',
        'Teatro das olimpíadas gregas',
        'Peça sobre a origem dos jogos olímpicos, com figurino produzido pela turma.',
        ProjectCategory.historia,
        ProjectType.estudantil,
        ['Teatro', 'História'],
        4,
        81,
        17,
        93,
        8.9,
        _ago(days: 16),
      ),
      proj(
        'p18',
        'u-ana',
        'Horta vertical com garrafas PET',
        'Horta automatizada com irrigação por gotejamento caseira.',
        ProjectCategory.meioAmbiente,
        ProjectType.estudantil,
        ['Sustentabilidade', 'Biologia'],
        5,
        118,
        29,
        152,
        9.2,
        _ago(days: 17),
        collaborators: ['u-pedro'],
      ),
      proj(
        'p19',
        'u-lucas',
        'Simulador de sistema solar',
        'Simulação em Python das órbitas dos planetas com escala real.',
        ProjectCategory.programacao,
        ProjectType.autoral,
        ['Python', 'Astronomia'],
        3,
        69,
        16,
        90,
        9.0,
        _ago(days: 18),
      ),
      Project(
        id: 'p21',
        authorId: currentUserId,
        title: 'Crônicas do intervalo',
        subtitle: 'Pequenas histórias que acontecem entre uma aula e outra.',
        description: 'Coletânea de crônicas autorais sobre o cotidiano escolar.',
        category: ProjectCategory.literatura,
        type: ProjectType.texto,
        tags: const ['Crônica', 'TextoAutoral'],
        textContent: '''"O sinal tocou e o pátio inteiro respirou alívio. Era sempre assim: quinze minutos em que a escola deixava de ser escola e virava um pequeno universo de filas, risadas e confissões apressadas.

Na cantina, dona Marta já sabia o pedido de cada um. O meu era sempre o mesmo: pão de queijo e um suco de caju que nunca vinha gelado o suficiente. "Um dia eu compro uma geladeira nova", ela dizia. A gente acreditava.

Foi naquele intervalo que o Pedrão me contou, em segredo, que tinha escrito um poema para a feira de literatura. Eu ri. Depois li. Depois não ri mais — era bonito de verdade.

Tem coisa que só acontece no intervalo. Talvez porque seja o único momento do dia em que ninguém está tentando ensinar nada para ninguém. A gente só existe, junto, por quinze minutos.

E quando o sinal toca de novo, a gente volta a ser aluno. Mas alguma coisa fica: o poema decorado, o segredo compartilhado, o gosto do pão de queijo. Pequenas histórias que ninguém avalia, mas que todo mundo lembra.''',
        cardTone: TextCardTone.vinho,
        likeCount: 38,
        commentCount: 9,
        ratingCount: 24,
        ratingAvg: 10.0,
        createdAt: _ago(days: 8),
      ),
      Project(
        id: 'p22',
        authorId: 'u-mariana',
        title: 'Poemas de outono',
        subtitle: 'Versos curtos escritos entre uma estação e outra.',
        description: 'Coletânea de poemas autorais sobre mudanças e recomeços.',
        category: ProjectCategory.literatura,
        type: ProjectType.texto,
        tags: const ['Poesia', 'TextoAutoral'],
        textContent: '''Folha que cai devagar
como quem não quer chegar,
o outono escreve no chão
a primeira lição:

tudo que se vai
deixa cor no lugar.

*
Guardei um verso teu
no bolso do casaco.
Quando o frio veio,
li três vezes —
e fez sol um pouco.''',
        cardTone: TextCardTone.azul,
        likeCount: 52,
        commentCount: 14,
        ratingCount: 31,
        ratingAvg: 9.3,
        createdAt: _ago(days: 4),
      ),
      proj(
        'p20',
        'u-julia',
        'Podcast: vozes da escola',
        'Série de episódios entrevistando estudantes sobre projetos autorais.',
        ProjectCategory.outros,
        ProjectType.autoral,
        ['Podcast', 'Comunicação'],
        2,
        44,
        10,
        57,
        7.9,
        _ago(days: 20),
      ),
    ];

    // ---------------- Avaliações ----------------
    ratings = [
      Rating(
        id: 'r1',
        projectId: 'p1',
        userId: 'u-ana',
        score: 9,
        comment: 'Projeto muito bem documentado, parabéns!',
        createdAt: _ago(days: 1),
      ),
      Rating(
        id: 'r2',
        projectId: 'p1',
        userId: 'u-julia',
        score: 10,
        comment: 'Aplicou eletrônica de verdade. Inspirador.',
        createdAt: _ago(days: 2),
      ),
      Rating(
        id: 'r3',
        projectId: 'p2',
        userId: 'u-pedro',
        score: 10,
        comment: 'Solução simples e com impacto real.',
        createdAt: _ago(days: 4),
      ),
    ];

    // ---------------- Atividade de XP ----------------
    xpEvents = [
      XpEvent(
        id: 'x1',
        userId: currentUserId,
        amount: 200,
        reason: 'Projeto "Filtro de água sustentável" — avaliação média 9,4',
        projectId: 'p2',
        createdAt: _ago(days: 4),
      ),
      XpEvent(
        id: 'x2',
        userId: currentUserId,
        amount: 50,
        reason: 'Projeto "História de Alagoas" — avaliação média 7,8',
        projectId: 'p3',
        createdAt: _ago(days: 11),
      ),
      XpEvent(
        id: 'x3',
        userId: currentUserId,
        amount: 200,
        reason: 'Projeto "Estufa automatizada" — avaliação média 9,1',
        createdAt: _ago(days: 30),
      ),
      XpEvent(
        id: 'x4',
        userId: currentUserId,
        amount: 50,
        reason: 'Projeto "Mapa cultural do bairro" — avaliação média 7,2',
        createdAt: _ago(days: 55),
      ),
      XpEvent(
        id: 'x5',
        userId: currentUserId,
        amount: 15,
        reason: 'Avaliou "Estação meteorológica de baixo custo"',
        projectId: 'p1',
        createdAt: _ago(days: 1, hours: 3),
      ),
    ];

    // ---------------- Materiais ----------------
    UserProfile byId(String id) => users.firstWhere((u) => u.id == id);

    materialPosts = [
      MaterialPost(
        id: 'm1',
        authorId: 'u-davi',
        title: 'Alguém tem material sobre estequiometria?',
        content:
            'Estou travado nos cálculos estequiométricos para a prova de química. '
            'Se alguém tiver uma apostila, lista de exercícios ou vídeo que explicou bem, '
            'agradeço demais!',
        subject: 'Química',
        kind: MaterialPostKind.pedido,
        acceptedAnswerId: 'ma2',
        answerCount: 2,
        author: byId('u-davi'),
        createdAt: _ago(days: 1, hours: 4),
      ),
      MaterialPost(
        id: 'm2',
        authorId: 'u-ana',
        title: 'Resumo de funções do 2º grau (completo)',
        content:
            'Organizei meu resumo de funções quadráticas: vértice, concavidade, '
            'discriminante e aplicações. Usei para o simulado e funcionou muito bem. '
            'Posso digitalizar e mandar o PDF se alguém quiser.',
        subject: 'Matemática',
        kind: MaterialPostKind.compartilhamento,
        answerCount: 3,
        author: byId('u-ana'),
        createdAt: _ago(days: 2),
      ),
      MaterialPost(
        id: 'm3',
        authorId: currentUserId,
        title: 'Onde consigo o PDF do livro de redação?',
        content:
            'A professora indicou "Redação Nota Mil" para o ENEM, mas não achei '
            'em lugar nenhum. Alguém sabe onde encontra ou tem uma apostila parecida?',
        subject: 'Literatura',
        kind: MaterialPostKind.pergunta,
        answerCount: 1,
        author: byId(currentUserId),
        createdAt: _ago(hours: 6),
      ),
      MaterialPost(
        id: 'm4',
        authorId: 'u-mariana',
        title: 'Boa lista de exercícios de logaritmo?',
        content:
            'Preciso treinar logaritmos com exercícios que tenham gabarito comentado. '
            'Recomendações?',
        subject: 'Matemática',
        kind: MaterialPostKind.pergunta,
        answerCount: 0,
        author: byId('u-mariana'),
        createdAt: _ago(hours: 2),
      ),
    ];

    materialAnswers = [
      MaterialAnswer(
        id: 'ma1',
        postId: 'm1',
        authorId: currentUserId,
        content:
            'O resumo da plataforma da escola tem uma seção só de estequiometria, '
            'com exercícios graduais. Está na biblioteca também.',
        author: byId(currentUserId),
        createdAt: _ago(days: 1, hours: 2),
      ),
      MaterialAnswer(
        id: 'ma2',
        postId: 'm1',
        authorId: 'u-ana',
        content:
            'Eu tenho uma apostila digitalizada com 40 exercícios resolvidos passo a '
            'passo. Me chama por mensagem que eu te envio o arquivo!',
        isAccepted: true,
        markedBy: currentUserId,
        markedAt: _ago(hours: 20),
        author: byId('u-ana'),
        createdAt: _ago(days: 1),
      ),
      MaterialAnswer(
        id: 'ma3',
        postId: 'm2',
        authorId: 'u-lucas',
        content: 'Eu quero! Manda no privado por favor.',
        author: byId('u-lucas'),
        createdAt: _ago(days: 1, hours: 22),
      ),
      MaterialAnswer(
        id: 'ma4',
        postId: 'm3',
        authorId: 'u-julia',
        content:
            'A biblioteca da escola tem 2 exemplares para empréstimo. '
            'Chegue cedo porque acaba rápido.',
        author: byId('u-julia'),
        createdAt: _ago(hours: 4),
      ),
    ];

    // ---------------- Mensagens ----------------
    conversations = [
      Conversation(
        id: 'c1',
        participants: [byId(currentUserId), byId('u-ana')],
        lastMessage: 'Combinado! Depois te mando o arquivo.',
        lastMessageAt: _ago(hours: 3),
      ),
      Conversation(
        id: 'c2',
        participants: [byId(currentUserId), byId('u-pedro')],
        lastMessage: 'Vi seu projeto da ponte, ficou muito bom!',
        lastMessageAt: _ago(days: 1, hours: 6),
        unreadCount: 1,
      ),
    ];

    messages = [
      Message(
        id: 'msg1',
        conversationId: 'c1',
        senderId: currentUserId,
        content: 'Ana, você pode me mandar aquela apostila de química?',
        read: true,
        createdAt: _ago(hours: 4),
      ),
      Message(
        id: 'msg2',
        conversationId: 'c1',
        senderId: 'u-ana',
        content: 'Claro! A da estequiometria, né?',
        read: true,
        createdAt: _ago(hours: 3, minutes: 40),
      ),
      Message(
        id: 'msg3',
        conversationId: 'c1',
        senderId: 'u-ana',
        content: 'Combinado! Depois te mando o arquivo.',
        read: true,
        createdAt: _ago(hours: 3),
      ),
      Message(
        id: 'msg4',
        conversationId: 'c2',
        senderId: 'u-pedro',
        content: 'Vi seu projeto da ponte, ficou muito bom!',
        read: false,
        createdAt: _ago(days: 1, hours: 6),
      ),
    ];

    // ---------------- Grupos (§20–§26) ----------------
    // Grupo existente criado pelo Pedro. Kevin NÃO é membro: ele tem um
    // convite PENDENTE (selecionar alguém não o coloca dentro do grupo).
    conversations.add(
      Conversation(
        id: 'g1',
        type: ConversationType.group,
        name: 'Equipe de Matemática',
        createdBy: 'u-pedro',
        participants: [byId('u-pedro'), byId('u-julia'), byId('u-camila')],
        lastMessage: 'Simulado da OBMEP sábado, 9h, na sala 12!',
        lastMessageAt: _ago(hours: 5),
      ),
    );

    groupMembers = [
      GroupMember(
        conversationId: 'g1',
        userId: 'u-pedro',
        role: GroupRole.owner,
        joinedAt: _ago(days: 6),
      ),
      GroupMember(
        conversationId: 'g1',
        userId: 'u-julia',
        joinedAt: _ago(days: 5),
      ),
      GroupMember(
        conversationId: 'g1',
        userId: 'u-camila',
        joinedAt: _ago(days: 5),
      ),
    ];

    groupInvites = [
      GroupInvite(
        id: 'gi1',
        groupId: 'g1',
        inviterId: 'u-pedro',
        invitedUserId: currentUserId,
        token: 'tok-gi1-kevin',
        createdAt: _ago(hours: 7),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    ];

    messages.addAll([
      Message(
        id: 'msg5',
        conversationId: 'g1',
        senderId: 'u-pedro',
        content: 'Pessoal, vamos focar na OBMEP esse mês!',
        read: true,
        createdAt: _ago(hours: 6),
      ),
      Message(
        id: 'msg6',
        conversationId: 'g1',
        senderId: 'u-camila',
        content: 'Simulado da OBMEP sábado, 9h, na sala 12!',
        read: true,
        createdAt: _ago(hours: 5),
      ),
    ]);

    // ---------------- Comunicados escolares (§37–§40) ----------------
    schoolAnnouncements = [
      SchoolAnnouncement(
        id: 'sa1',
        schoolId: 'esc-dumont',
        authorId: currentUserId,
        title: 'Feira de Ciências — inscrições abertas',
        subtitle: 'Até sexta-feira, na coordenação',
        content:
            'As inscrições para a Feira de Ciências 2026 estão abertas. '
            'Projetos de todas as áreas são bem-vindos. Inscreva-se na '
            'coordenação até sexta-feira ou pelo formulário enviado às turmas.',
        category: AnnouncementCategory.evento,
        createdAt: _ago(days: 1, hours: 2),
      ),
      SchoolAnnouncement(
        id: 'sa2',
        schoolId: 'esc-dumont',
        authorId: currentUserId,
        title: 'Simulado ENEM no sábado',
        content:
            'Simulado geral neste sábado, das 8h às 13h. Tragam caneta '
            'preta, documento e garrafa de água. Os gabaritos serão '
            'publicados no mural digital no mesmo dia.',
        category: AnnouncementCategory.prova,
        createdAt: _ago(days: 2, hours: 5),
      ),
      SchoolAnnouncement(
        id: 'sa3',
        schoolId: 'esc-dumont',
        authorId: currentUserId,
        title: 'Olimpíada de Matemática — fase municipal',
        content:
            'A escola vai participar da fase municipal da OBMEP. Interessados '
            'devem procurar o professor de matemática até o dia 15. '
            'Aulas preparatórias às terças e quintas no contra-turno.',
        category: AnnouncementCategory.olimpiada,
        createdAt: _ago(days: 4),
      ),
      SchoolAnnouncement(
        id: 'sa4',
        schoolId: 'esc-maria',
        authorId: currentUserId,
        title: 'Semana da leitura',
        content: 'Troca de livros no pátio central durante toda a semana.',
        category: AnnouncementCategory.evento,
        createdAt: _ago(days: 3),
      ),
    ];

    // ---------------- Notificações (rodada 4, §11–§21) ----------------
    // Massa de demonstração do sino: mensagem direta, grupo agregado,
    // avaliação recebida e convite de grupo — mais uma já lida (sistema).
    notifications = [
      AppNotification(
        id: 'n1',
        recipientUserId: currentUserId,
        type: NotificationType.message,
        actorUserId: 'u-pedro',
        referenceId: 'c2',
        title: 'Nova mensagem',
        message: 'Pedro Henrique enviou uma mensagem para você.',
        createdAt: _ago(days: 1, hours: 6),
      ),
      AppNotification(
        id: 'n2',
        recipientUserId: currentUserId,
        type: NotificationType.groupMessage,
        actorUserId: 'u-camila',
        referenceId: 'g1',
        title: 'Equipe de Matemática',
        message: '3 novas mensagens em Equipe de Matemática',
        count: 3,
        createdAt: _ago(hours: 5),
      ),
      AppNotification(
        id: 'n3',
        recipientUserId: currentUserId,
        type: NotificationType.projectRating,
        actorUserId: 'u-julia',
        referenceId: 'p2',
        title: 'Projeto avaliado',
        message:
            'Júlia Santos avaliou seu projeto "Filtro de água sustentável" com 9,0.',
        createdAt: _ago(hours: 2),
      ),
      AppNotification(
        id: 'n4',
        recipientUserId: currentUserId,
        type: NotificationType.groupInvite,
        actorUserId: 'u-pedro',
        referenceId: 'gi1',
        title: 'Convite de grupo',
        message: 'Pedro Henrique convidou você para Equipe de Matemática.',
        createdAt: _ago(hours: 1),
      ),
      AppNotification(
        id: 'n5',
        recipientUserId: currentUserId,
        type: NotificationType.system,
        title: 'Bem-vindo ao Conecta!',
        message: 'Complete seu perfil para aproveitar a comunidade escolar.',
        createdAt: _ago(days: 6),
        readAt: _ago(days: 6),
      ),
    ];

    // ---------------- Biblioteca (rodada 4, §25–§37) ----------------
    // Kevin já começa com dois projetos salvos (um deles do tipo Texto,
    // para cobrir §30). Apenas a relação userId ↔ projectId (§32).
    savedProjects = [
      SavedProject(
        userId: currentUserId,
        projectId: 'p1',
        savedAt: _ago(days: 1, hours: 2),
      ),
      SavedProject(
        userId: currentUserId,
        projectId: 'p22',
        savedAt: _ago(hours: 7),
      ),
      // Saves de OUTROS usuários: alimentam o contador de saves dos
      // projetos (a contagem é pública; a relação em si é privada).
      SavedProject(
          userId: 'u-ana', projectId: 'p2', savedAt: _ago(days: 2)),
      SavedProject(
          userId: 'u-julia', projectId: 'p1', savedAt: _ago(days: 3)),
      SavedProject(
          userId: 'u-pedro', projectId: 'p1', savedAt: _ago(days: 4)),
      SavedProject(
          userId: 'u-camila', projectId: 'p1', savedAt: _ago(days: 5)),
      SavedProject(
          userId: 'u-davi', projectId: 'p2', savedAt: _ago(days: 1)),
      SavedProject(
          userId: 'u-lucas', projectId: 'p5', savedAt: _ago(hours: 20)),
      SavedProject(
          userId: 'u-mariana', projectId: 'p3', savedAt: _ago(days: 6)),
      SavedProject(
          userId: 'u-helena', projectId: 'p22', savedAt: _ago(days: 2)),
    ];

    // ---------------- Comentários (independentes de avaliação) ----------------
    // Comentário solto NÃO tem nota: qualquer estudante pode comentar.
    // O commentCount exibido nos cards é DERIVADO desta lista.
    comments = [
      ProjectComment(
        id: 'c-1',
        projectId: 'p2',
        authorId: 'u-julia',
        text: 'Apresentei esse filtro na aula de química e a turma adorou. '
            'Parabéns pelo capricho!',
        createdAt: _ago(days: 1, hours: 3),
      ),
      ProjectComment(
        id: 'c-2',
        projectId: 'p2',
        authorId: 'u-pedro',
        text: 'Funciona com água da chuva? Queria adaptar pra minha casa.',
        createdAt: _ago(hours: 22),
      ),
      ProjectComment(
        id: 'c-3',
        projectId: 'p1',
        authorId: 'u-ana',
        text: 'A estação ficou muito bem documentada. Vou usar como '
            'referência no meu TCC do técnico.',
        createdAt: _ago(days: 2),
      ),
      ProjectComment(
        id: 'c-4',
        projectId: 'p22',
        authorId: 'u-lucas',
        text: 'Que poema lindo, Mariana. "O outono escreve no chão" '
            'ficou na minha cabeça o dia todo.',
        createdAt: _ago(hours: 9),
      ),
      ProjectComment(
        id: 'c-5',
        projectId: 'p22',
        authorId: 'u-helena',
        text: 'Escreve mais! Quero ler a continuação no inverno. 🍂',
        createdAt: _ago(hours: 4),
      ),
      ProjectComment(
        id: 'c-6',
        projectId: 'p5',
        authorId: 'u-camila',
        text: 'O cálculo da pegada de carbono bateu com a planilha da '
            'ONG que eu acompanho. Ótimo trabalho!',
        createdAt: _ago(days: 3),
      ),
    ];
  }

  /// Alterna a relação de salvamento (§26–§27) sem nunca duplicar o par
  /// userId + projectId (§32). Retorna o novo estado (true = salvo).
  bool toggleSaved(String userId, String projectId) {
    final existing = savedProjects.indexWhere((s) => s.matches(userId, projectId));
    if (existing >= 0) {
      savedProjects.removeAt(existing);
      return false;
    }
    savedProjects.add(
        SavedProject(userId: userId, projectId: projectId, savedAt: DateTime.now()));
    return true;
  }

  /// Cria uma notificação para um usuário (hooks de mensagem/avaliação).
  void pushNotification(AppNotification n) => notifications.add(n);

  UserProfile _user(String id, String name, String username, int xp) =>
      UserProfile(
        id: id,
        name: name,
        username: username,
        avatarUrl: _avatar(username),
        xpTotal: xp,
        // Distribui entre as escolas do seed para o filtro "Minha escola"
        // ter massa de dados (a escola do Kevin concentra a maioria).
        schoolId: id.hashCode % 3 == 0 ? 'esc-maria' : 'esc-dumont',
        createdAt: _ago(days: 200),
      );
}
