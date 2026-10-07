# Instrumentos de coleta — transcrição literal

Fontes: `questionario_T1.html`, `questionario_T2.html` (páginas HTML abertas no navegador do participante; ao final, um arquivo `.json` era baixado e enviado ao pesquisador) e `lib/screens/participant_profile_screen.dart` (questionário de perfil dentro do app, no primeiro acesso). Texto copiado sem correções, incluindo grafia original.

## A. Questionário de perfil (dentro do aplicativo, primeiro acesso)

Título da tela: **Sobre si**

> Responda ao questionário para continuar. Os dados são usados apenas no âmbito do estudo.

| Campo | Tipo / opções |
| --- | --- |
| Nome ou pseudónimo | Texto livre (validado contra o nome cadastrado com o código) |
| Idade | Número (10 a 120) |
| Género | Feminino; Masculino; Não-binário; Prefiro não informar; Outro |
| Escolaridade | Fundamental incompleto; Fundamental completo; Médio incompleto; Médio completo; Superior incompleto; Superior completo; Pós-graduação; Prefiro não informar |

Caixa de concordância obrigatória:

> Li e concordo, de forma livre e informada, com o termo de consentimento e com o tratamento dos meus dados pessoais para as finalidades do estudo aí descritas (incluindo telemetria técnica e dados das tarefas, conforme aplicável).

Botão "Ler termos completos" abre `ResearchConsent.fullText` (`lib/legal/research_consent.dart`, versão 1.0).

## B. Questionário de período (T1 e T2 — idêntico nos blocos 0 a 5)

Cabeçalho:

> iCEV · Engenharia de Software · Pesquisa de campo
> **Sua experiência com o aplicativo**
> Responda com base no que você realmente viveu nas últimas duas semanas. Não há respostas certas ou erradas.
> Etiqueta: "Primeiro período (T1)" ou "Segundo período (T2)"

### Bloco 0 — Identificação e uso

> Comece com seu código de participante e um resumo de quanto usou o aplicativo.

- Código do participante (informado pelo pesquisador) — texto, ex.: P007
- Intensidade de uso (0 = nenhuma vez · 10 = todos os dias intensamente) — número 0 a 10
- Em quantos dos últimos 15 dias você abriu o aplicativo? (0 a 15)
- Aproximadamente quantas tarefas você criou, editou ou concluiu? (número aproximado)

### Bloco 1 — Facilidade de uso (SUS)

> As dez afirmações a seguir avaliam a usabilidade geral do aplicativo.
> Escala de 1 a 5 · 1 = Discordo totalmente · 3 = Neutro · 5 = Concordo totalmente

| Código | Item |
| --- | --- |
| sus1 | Eu acho que gostaria de usar esse sistema com frequência. |
| sus2 | Eu achei esse sistema desnecessariamente complexo. |
| sus3 | Eu achei esse sistema fácil de usar. |
| sus4 | Eu achei que precisaria de ajuda de uma pessoa técnica para conseguir usar esse sistema. |
| sus5 | Eu achei que as várias funções desse sistema estavam bem integradas. |
| sus6 | Eu acho que o sistema apresenta muita inconsistência. |
| sus7 | Eu imagino que a maioria das pessoas aprenderia a usar esse sistema rapidamente. |
| sus8 | Eu achei esse sistema muito difícil de usar. |
| sus9 | Eu me senti muito seguro(a) usando esse sistema. |
| sus10 | Eu precisei aprender muitas coisas antes de conseguir usar esse sistema. |

Itens pares não eram marcados como invertidos na tela.

### Bloco 2 — Estabilidade e funcionamento (tf)

> Falhas, disponibilidade e recuperação do aplicativo. Itens (R) têm sentido inverso — leia com atenção.
> Escala de 1 a 7 · 1 = Discordo totalmente · 4 = Neutro · 7 = Concordo totalmente

| Subtítulo exibido | Código | Item (a marca "(R)" aparecia na tela) |
| --- | --- | --- |
| Estabilidade | tf1 | O aplicativo funcionou de forma estável durante as duas semanas. |
| | tf2 | Encontrei erros ou comportamentos inesperados no aplicativo. (R) |
| Disponibilidade | tf3 | Sempre que precisei usar o aplicativo, ele estava disponível. |
| | tf4 | Houve momentos em que não consegui acessar minhas tarefas quando precisei. (R) |
| Tolerância a falhas | tf5 | Quando algo deu errado (rede ruim, app fechou), o aplicativo continuou funcionando ou se recuperou de forma controlada. |
| | tf6 | Pequenos problemas se transformaram em falhas grandes que me impediram de trabalhar. (R) |
| Recuperabilidade | tf7 | Após qualquer interrupção, encontrei minhas tarefas íntegras e atualizadas. |
| | tf8 | Perdi informações ou tive que refazer trabalho por causa do aplicativo. (R) |
| Consistência | tf9 | As informações que vejo no aplicativo são consistentes entre diferentes telas e momentos. |

### Bloco 3 — Confiança no aplicativo (cs)

> Sua percepção de que o aplicativo funcionará quando você precisar dele.
> Escala de 1 a 7 · 1 = Discordo totalmente · 4 = Neutro · 7 = Concordo totalmente

| Código | Item |
| --- | --- |
| cs1 | O aplicativo tem os recursos necessários para que eu gerencie minhas tarefas adequadamente. |
| cs2 | O aplicativo é capaz de fazer aquilo de que eu preciso. |
| cs3 | O aplicativo é muito confiável. |
| cs4 | O aplicativo falha comigo em momentos importantes. (R) |
| cs5 | Eu posso contar com o aplicativo para funcionar adequadamente. |
| cs6 | O aplicativo me dá indicações claras sobre seu estado (salvo, sincronizando, pendente). |
| cs7 | Considero esse aplicativo competente para o propósito a que se destina. |
| cs8 | O comportamento do aplicativo é previsível para mim. |
| cs9 | Sinto-me confortável em depender desse aplicativo para tarefas importantes. |
| cs10 | Eu recomendaria esse aplicativo para alguém que precisa gerenciar suas tarefas. |

### Bloco 4 — Situações do dia a dia (ctx)

> Pense em momentos específicos das últimas duas semanas.
> Escala de 1 a 7 · 1 = Discordo totalmente · 4 = Neutro · 7 = Concordo totalmente

| Código | Item |
| --- | --- |
| ctx1 | Em situações de internet ruim ou ausente (ônibus, elevador, áreas sem sinal), consegui usar o aplicativo sem frustração. |
| ctx2 | Quando abri o aplicativo após um tempo sem usá-lo, vi rapidamente o que eu esperava ver. |
| ctx3 | As ações que executei (criar, editar, concluir tarefa) tiveram retorno imediato. |
| ctx4 | Em algum momento fiquei em dúvida se uma alteração minha foi realmente salva. (R) |
| ctx5 | O aplicativo respondeu rapidamente aos meus toques e gestos. |

### Bloco 5 — Em suas palavras (abertas, opcionais)

> Três perguntas abertas. Responda livremente.

1. O que mais te agradou no aplicativo nas últimas duas semanas?
2. O que mais te frustrou ou atrapalhou?
3. Houve algum momento em que você desistiu de usar o aplicativo? Se sim, o que aconteceu?

## C. Comparativo final (somente T2)

> **Comparativo final** — Agora que você usou os dois aplicativos, compare-os diretamente. Estes campos aparecem apenas neste segundo questionário.

### Bloco 6 — 1º aplicativo vs. 2º aplicativo

> Para cada aspecto, marque onde −3 = ← 1º app melhor, 0 = iguais, +3 = 2º app melhor →.
> Opções: −3, −2, −1, 0 ("Iguais"), +1, +2, +3; rótulos nas pontas: "← 1º app melhor" e "2º app melhor →"

| Código | Item |
| --- | --- |
| comp1 | Facilidade de uso geral. |
| comp2 | Velocidade percebida. |
| comp3 | Confiança de que meus dados estão seguros. |
| comp4 | Estabilidade (menos erros e travamentos). |
| comp5 | Comportamento em situações de internet ruim. |
| comp6 | Uso no dia a dia, considerando tudo. |

### Bloco 7 — Escolha e justificativa

> Se tivesse que escolher uma aplicativo para usar permanentemente, qual seria?

- comp7 — Versão preferida: 1º aplicativo; 2º aplicativo; Indiferente
- comp8 — Por quê? (2 a 3 frases) — texto livre

### Bloco 8 — Percepção técnica

> Perguntas de controle — responda com sinceridade.

- comp9 — Você percebeu alguma diferença técnica entre os dois aplicativos? Sim; Não
- comp9_desc — Se sim, o que você percebeu? (deixe em branco se não)
- comp10 — Em algum momento suspeitou que uma versão usava uma estratégia técnica específica? Não percebi diferença técnica; Suspeitei de algo
- comp10_desc — Se suspeitou, descreva: (deixe em branco se não)

## D. Envio

> Finalizar e baixar respostas — Ao finalizar, um arquivo .json será baixado. Envie-o ao pesquisador pelo canal combinado.
> Seu arquivo de respostas foi baixado automaticamente. Envie-o ao pesquisador por WhatsApp ou e-mail.

Itens invertidos no JSON (`reverse_items`): tf2, tf4, tf6, tf8, cs4, ctx4. Itens pares do SUS revertidos na análise pela fórmula de Brooke.
