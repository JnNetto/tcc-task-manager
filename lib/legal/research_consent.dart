/// Texto e versão do termo de consentimento para participação e tratamento de dados
/// no âmbito do estudo (telemetria, questionário, tarefas). Ajuste datas, instituição
/// e contacto após aprovação do comité de ética, se aplicável.
class ResearchConsent {
  ResearchConsent._();

  /// Incrementar quando alterar o texto (rastreio de aceitações no RTDB).
  static const String version = '1.0';

  static const String title = 'Termo de consentimento e informação (LGPD)';

  /// Corpo completo exibido no diálogo do app.
  static String get fullText => '''
Este aplicativo faz parte de um estudo académico que compara o uso de um gestor de tarefas em dois modos técnicos (sincronização com servidor prioritária face a uso local prioritário). Ao participar, declara que foi informado(a) sobre o seguinte.

1. Finalidade
Os dados são tratados exclusivamente para fins de investigação científica e académica (relatório, dissertação ou publicações derivadas), incluindo análise de desempenho, padrões de uso e comparação entre modos, sem fins comerciais diretos sobre os seus dados pessoais.

2. Dados que podem ser recolhidos
• Identificação atribuída pelo estudo (código de participante) e, se indicar, nome ou pseudónimo, idade, género e escolaridade no questionário inicial.
• Dados das tarefas que criar ou alterar na aplicação (conteúdo das tarefas conforme o que introduzir), armazenados na infraestrutura do estudo (ex.: Firebase).
• Telemetria técnica: eventos como início e fim de operações, erros de rede ou de servidor, tipo de arquitetura ativa, carimbos de data/hora e metadados necessários à análise do experimento. A telemetria pode ser desativada remotamente pelo investigador conforme o protocolo.

3. Onde os dados ficam
Os dados são processados em serviços na nuvem (por exemplo Google Firebase), sujeitos às políticas do fornecedor e às medidas de segurança configuradas para o projeto.

4. Base legal e direitos (Lei n.º 13.709/2018 — LGPD)
A participação é voluntária. O tratamento de dados pessoais para esta investigação fundamenta-se no consentimento que manifesta ao aceitar este termo e concluir o questionário, sem prejuízo de outras bases legais que o protocolo institucional possa prever.
Tem direito a solicitar esclarecimentos, acesso a dados, retificação de dados inexatos e, quando aplicável, eliminação ou anonimização, limitação ou oposição ao tratamento, nos termos da lei e do protocolo aprovado pela instituição. Para exercer estes direitos ou retirar a participação, deve contactar a equipa do estudo pelos meios indicados pelo investigador responsável (por exemplo e-mail ou contacto institucional fornecido no convite ao estudo).

5. Confidencialidade e divulgação
Os resultados serão divulgados de forma agregada ou anonimizada sempre que possível, de modo a não o(a) identificar individualmente em trabalhos académicos, salvo obrigação legal em contrário.

6. Aceitação
Ao marcar a opção de concordância e continuar, confirma que leu (ou teve oportunidade de ler) esta informação, que participa de forma voluntária e que concorda com a recolha e o tratamento dos dados descritos para as finalidades do estudo.

Versão do texto: $version
''';
}

