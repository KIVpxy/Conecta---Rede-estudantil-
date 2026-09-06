import '../../data/models/models.dart';

/// Definições centralizadas de todos os badges do Conecta.
///
/// Regras (SPEC §20–28):
/// - AUTOR: publicar o primeiro projeto.
/// - Mente Brilhante I/II/III: 1/2/3 projetos diferentes com média ≥ 7.
/// - The Thinker I/II/III: 1/2/3 projetos diferentes com média ≥ 8.
/// - Aluno Aplicado I: primeira postagem em Materiais.
/// - Aluno Aplicado II: 5 respostas selecionadas pela moderação.
/// - The Mastermind: 20 respostas selecionadas pela moderação.
/// - Eu tenho e você?: 1 projeto com média final exatamente 10,0.
class BadgeService {
  BadgeService._();

  static const definitions = <BadgeDefinition>[
    BadgeDefinition(
      id: BadgeId.autor,
      name: 'Autor',
      description: 'Publicou o primeiro projeto no Conecta.',
      target: 1,
    ),
    BadgeDefinition(
      id: BadgeId.menteBrilhante1,
      name: 'Mente Brilhante I',
      description: '1 projeto com avaliação média ≥ 7.',
      target: 1,
    ),
    BadgeDefinition(
      id: BadgeId.menteBrilhante2,
      name: 'Mente Brilhante II',
      description: '2 projetos diferentes com avaliação média ≥ 7.',
      target: 2,
    ),
    BadgeDefinition(
      id: BadgeId.menteBrilhante3,
      name: 'Mente Brilhante III',
      description: '3 projetos diferentes com avaliação média ≥ 7.',
      target: 3,
    ),
    BadgeDefinition(
      id: BadgeId.thinker1,
      name: 'The Thinker I',
      description: '1 projeto com avaliação média ≥ 8.',
      target: 1,
    ),
    BadgeDefinition(
      id: BadgeId.thinker2,
      name: 'The Thinker II',
      description: '2 projetos diferentes com avaliação média ≥ 8.',
      target: 2,
    ),
    BadgeDefinition(
      id: BadgeId.thinker3,
      name: 'The Thinker III',
      description: '3 projetos diferentes com avaliação média ≥ 8.',
      target: 3,
    ),
    BadgeDefinition(
      id: BadgeId.alunoAplicado1,
      name: 'Aluno Aplicado I',
      description: 'Criou a primeira postagem na aba Materiais.',
      target: 1,
    ),
    BadgeDefinition(
      id: BadgeId.alunoAplicado2,
      name: 'Aluno Aplicado II',
      description:
          '5 respostas selecionadas pela moderação em Materiais.',
      target: 5,
    ),
    BadgeDefinition(
      id: BadgeId.mastermind,
      name: 'The Mastermind',
      description:
          '20 respostas selecionadas pela moderação em Materiais.',
      target: 20,
    ),
    BadgeDefinition(
      id: BadgeId.euTenhoEVoce,
      name: 'Eu tenho e você?',
      description:
          'Possui um projeto com média final exatamente 10,0.',
      target: 1,
    ),
  ];

  static BadgeDefinition definitionOf(BadgeId id) =>
      definitions.firstWhere((d) => d.id == id);

  /// Entrada de dados para avaliação das condições (calculada pela
  /// camada de dados — mock local ou RPC no backend).
  ///
  /// - [projectAverages]: médias dos projetos de que o usuário é AUTOR
  ///   (projetos colaborados não contam para badges de autoria).
  /// - [materialPosts]: quantidade de postagens do usuário em Materiais.
  /// - [acceptedAnswers]: respostas do usuário selecionadas pela moderação
  ///   (nunca conta votos, likes ou seleção pelo próprio autor).
  static int progressOf(
    BadgeId id, {
    required List<double> projectAverages,
    required int materialPosts,
    required int acceptedAnswers,
  }) {
    switch (id) {
      case BadgeId.autor:
        return projectAverages.isNotEmpty ? 1 : 0;
      case BadgeId.menteBrilhante1:
      case BadgeId.menteBrilhante2:
      case BadgeId.menteBrilhante3:
        return projectAverages.where((a) => a >= 7).length;
      case BadgeId.thinker1:
      case BadgeId.thinker2:
      case BadgeId.thinker3:
        return projectAverages.where((a) => a >= 8).length;
      case BadgeId.alunoAplicado1:
        return materialPosts > 0 ? 1 : 0;
      case BadgeId.alunoAplicado2:
      case BadgeId.mastermind:
        return acceptedAnswers;
      case BadgeId.euTenhoEVoce:
        return projectAverages.any((a) => a == 10.0) ? 1 : 0;
    }
  }
}
