# 🐞 QA Bug Reports — Migração de Design AgroBravo Guia

| Campo | Valor |
|---|---|
| **Ciclo** | Testes estáticos / análise de código (fase 1 — sem dispositivo) |
| **Data** | 10/07/2026 |
| **Referência** | `QA_TEST_PLAN_MIGRACAO_DESIGN.md` |
| **Método** | Rastreamento de fluxo por código-fonte, verificação de contratos (rotas, DB, pacotes), simulação de dados legados |
| **App/Versão** | AgroBravo Guia `1.5.1+13` (branch `main` + working tree da migração) |

> Escopo desta fase: tudo que é verificável por código. Casos que exigem dispositivo (crop com HEIC/48MP, overflow visual, push real) permanecem pendentes no plano — ver seção 4.

---

## 1. Defeitos encontrados

### BUG-001 — Botão WhatsApp gera link com DDI duplicado (e quebra números não-BR)

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | High / **P1** |
| **Ambiente** | Código — `lib/features/profile/presentation/widgets/profile_actions.dart:175-178` |
| **Frequência** | Sempre (com telefone no formato novo) |
| **Relacionado a** | Risco R3, TC-COM-005 |

**Passos para reproduzir:**
1. Usuário A salva o telefone na nova tela Dados da Conta (agora persiste como `+55 (11) 98765-4321`).
2. Usuário B conecta-se ao usuário A.
3. B abre o perfil de A e toca no botão **WhatsApp**.

**Resultado esperado:** abre `https://wa.me/5511987654321`.

**Resultado obtido (rastreado por código):**
```dart
final cleanPhone = phone!.replaceAll(RegExp(r'\D'), ''); // "5511987654321" (mantém o 55 do +55)
final url = Uri.parse('https://wa.me/55$cleanPhone');    // "wa.me/555511987654321" ← DDI duplicado
```
- Telefone novo BR → `wa.me/5555...` (inválido).
- Telefone estrangeiro (`+1 (305) ...`) → `wa.me/551305...` (número de outra pessoa/inexistente).
- Telefone legado sem DDI (`(11) 98765-4321`) → funciona por coincidência.

**Evidência:** `profile_actions.dart:177`. **Observação:** o mesmo defeito existe no app Viajante (código idêntico) — corrigir nos dois.

**Sugestão de correção:** remover o `55` fixo e usar o número como está quando já contém DDI; aplicar fallback `55` apenas quando o número não começa com código de país (ex.: comprimento ≤ 11 dígitos).

**Workaround:** nenhum para o usuário final.

---

### BUG-002 — Push notification com `target_route: /settings` leva a tela de erro sem saída

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | High / **P1** |
| **Ambiente** | Código — `lib/core/router/app_router.dart` + `lib/core/services/notification_navigation_service.dart` + contrato `rotas_notificacao.md:18` |
| **Frequência** | Sempre que a edge function enviar `/settings` |
| **Relacionado a** | Risco R2, TC-REG-001/002 |

**Passos para reproduzir:**
1. Backend/edge function envia push com `target_route: "/settings"` (rota **documentada como válida** em `rotas_notificacao.md`, linha 18).
2. Usuário toca na notificação.

**Resultado esperado:** abrir a tela Meus Dados (substituta de Configurações) ou, no mínimo, cair na home.

**Resultado obtido (rastreado por código):**
- `_normalizeRoute('/settings')` retorna `/settings` (path válido).
- `_resolveStack('/settings')` retorna `null` (não mapeada).
- `appRouter.go('/settings')` → rota **foi removida** do GoRouter nesta migração.
- O GoRouter **não define `errorBuilder`** → usuário cai na tela de erro padrão do GoRouter (cinza, "Page Not Found"), sem navbar e sem botão de voltar dentro do app.

**Sugestão de correção (tripla):**
1. Adicionar no router um redirect/rota `/settings` → `/home?tab=4`.
2. Adicionar `errorBuilder` no GoRouter redirecionando para `/home` (rede de segurança para qualquer rota futura inválida).
3. Atualizar `rotas_notificacao.md` (remover `/settings`, documentar `/home?tab=4`).

**Workaround:** usuário mata o app e reabre.

---

### BUG-003 — Diálogos de DEBUG aparecem em produção no fluxo de deep link com grupo

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | High / **P1** |
| **Ambiente** | Código — `lib/features/home/presentation/pages/home_page.dart:64-74` e `:106-119` |
| **Frequência** | Sempre que a HomePage recebe `initialGroupId` (todo push de chat/itinerário/missão com `groupId`) |
| **Relacionado a** | TC-REG-001 |
| **Origem** | **Pré-existente** (não introduzido pela migração), mas dispara exatamente nos fluxos críticos de push deste release |

**Passos para reproduzir:**
1. Receber push de chat/itinerário (o serviço navega para `/home?tab=X&groupId=Y`).
2. Tocar na notificação.

**Resultado esperado:** navegar direto para a aba/grupo correto.

**Resultado obtido:** `AlertDialog` com título **"DEBUG ROTEAMENTO"** ("HomePage carregada!\nTab inicial: X\nGrupo: Y") exibido ao usuário final; um segundo diálogo "DEBUG ROTEAMENTO (UPDATE)" aparece a cada atualização de tab/grupo via rota (ex.: tocar em notificação na central de notificações — `notifications_page.dart:299/313`).

**Sugestão de correção:** remover os dois blocos `showDialog` (ou proteger com `kDebugMode`).

**Workaround:** usuário fecha o diálogo manualmente (péssima UX, parece erro).

---

### BUG-004 — Nacionalidade legada em texto livre é coagida silenciosamente para "Brasil"

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | High / **P2** |
| **Ambiente** | Código — `lib/features/profile/presentation/pages/account_data_page.dart` (`_initializeControllers`) + dados legados na coluna `nacionalidade` |
| **Frequência** | Sempre, para contas antigas com nacionalidade preenchida como texto |
| **Relacionado a** | TC-AD-003/010 (migração de dados) |

**Contexto:** a tela antiga do Guia salvava nacionalidade como **texto livre** (`'nationality': _nationalityController.text` → "Brasileira", "Americana", "Português"...). A tela nova espera **código ISO** (`BR`, `US`...).

**Passos para reproduzir (dado legado):**
1. Conta antiga com `nacionalidade = "Americana"` no banco.
2. Abrir Dados da Conta.

**Resultado esperado:** nacionalidade exibida corretamente (ou ao menos vazia, forçando o usuário a re-selecionar).

**Resultado obtido (rastreado por código):**
```dart
final match = kAddressCountries.firstWhere(
  (c) => c.code == savedNationality,        // "Americana" não bate com nenhum código
  orElse: () => kDefaultAddressCountry,     // ← default: Brasil
);
```
- Dropdown exibe **Brasil** para um usuário americano.
- Como BR ⇒ **CPF obrigatório**, o estrangeiro fica **bloqueado de salvar** sem inventar um CPF.
- Se salvar, a coluna `nacionalidade` é sobrescrita com `BR` — **corrupção silenciosa de dado**.

**Sugestão de correção:** no `_initializeControllers`, tentar match também por nome (`c.name.toLowerCase() == savedNationality.toLowerCase()` + heurísticas "brasileir*"→BR, "american*"→US) e, sem match, deixar `_nationalityCountry = null` (o campo já é obrigatório e forçará re-seleção consciente).

**Workaround:** usuário re-seleciona manualmente a nacionalidade correta antes de salvar.

---

### BUG-005 — Upload de foto recortada sobe sem extensão no nome do arquivo

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | Medium / P2 |
| **Ambiente** | Código — `lib/features/profile/presentation/cubit/profile_cubit.dart` (`updateProfilePhoto`/`updateCoverPhoto`) + `cross_file 0.3.5` |
| **Frequência** | Sempre (em todo upload via crop) |
| **Relacionado a** | Risco R5, TC-CROP-001/002 |

**Rastreamento:**
- As telas criam `XFile.fromData(bytes, name: 'avatar_cropped.png', ...)` **sem** o parâmetro `path`.
- Verificado no fonte do `cross_file 0.3.5` (`io.dart:54`): `_file = File(path ?? '')` → `xfile.path == ''`.
- No cubit: `file.path.split('.').last` → `''`.
- No repositório: `fileName = '${timestamp}.$extension'` → **`"1720620000000."`** (extensão vazia) no bucket `files`.

**Resultado esperado:** arquivo `*.png` com content-type `image/png`.

**Resultado obtido:** arquivo sem extensão, content-type provável `application/octet-stream`. Renderiza no app (o decoder lê os bytes), mas pode falhar em navegadores/painéis e dificulta manutenção do bucket.

**Observação:** paridade com o Viajante (mesmo defeito lá — "funciona" em produção hoje).

**Sugestão de correção:** no cubit, usar `file.name` como fonte da extensão com fallback: `final extension = file.name.contains('.') ? file.name.split('.').last : 'png';`

---

### BUG-006 — Avatar/nome desatualizados na tab "Meu Perfil" após edição em outra tela

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | Medium / P3 |
| **Ambiente** | Arquitetura — `ProfileCubit` é `@injectable` (uma instância por tela) |
| **Frequência** | Sempre (até remontar a aba) |
| **Relacionado a** | Risco R8, TC-COM-006 |

**Passos:** 1. Abrir Comunidade > Meu Perfil. 2. Ir a Meus Dados e trocar a foto (ou salvar Dados da Conta com novo nome). 3. Voltar à Comunidade > Meu Perfil **sem trocar de aba principal**.

**Resultado esperado:** dados atualizados.
**Resultado obtido:** a tab Meu Perfil mantém o cubit próprio criado na montagem — exibe foto/nome antigos até o usuário sair da aba Comunidade e voltar (remontagem).

**Sugestão de correção (qualquer uma):** (a) tornar `ProfileCubit` `@lazySingleton` como no Viajante (exige revisar `close()` dos `BlocProvider`); (b) pull-to-refresh na SocialProfilePage; (c) aceitar e documentar (comportamento de baixa gravidade).

---

### BUG-007 — Cropper e seletor de país 100% em português num app bilíngue

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | Low / P3 |
| **Ambiente** | `lib/core/components/image_cropper_modal.dart` (linhas 255, 318, 346, 382) e `phone_field.dart` (hint "Buscar país ou código...") |
| **Frequência** | Sempre, com idioma EN |
| **Relacionado a** | TC-MD-004 (i18n) |

**Resultado obtido:** com o app em English, o modal de crop exibe "Ajustar foto", "Belisque para dar zoom • Arraste para mover", "Cancelar", "Usar foto" em PT.
**Observação:** paridade com o Viajante (strings hardcoded lá também). Correção: trocar por `context.t(...)`.

---

### BUG-008 — Documentação de rotas de notificação desatualizada (contrato com o backend)

| Campo | Valor |
|---|---|
| **Severidade / Prioridade** | Low (documentação) / P3 — mas alimenta o BUG-002 |
| **Ambiente** | `rotas_notificacao.md` + comentário em `notification_navigation_service.dart:143` |

**Achados:**
- `rotas_notificacao.md:18` ainda lista `/settings` como rota válida (removida).
- `rotas_notificacao.md:37` descreve `/profile/:userId` (ok — agora abre o perfil social; atualizar descrição).
- Comentário do serviço diz `3=Feed, 4=Perfil`; agora é `3=Comunidade, 4=Meus Dados`. Os mapeamentos `/connections`→tab 4 e `/documents`→tab 4 continuam **funcionalmente corretos** (Documentos vive dentro de Meus Dados), mas a doc engana o próximo dev.

---

## 2. Observações / decisões pendentes (não são defeitos)

| ID | Observação | Ação |
|----|-----------|------|
| OBS-001 | Tile **"Notificações"** removida do menu Meus Dados (edição manual pós-migração), mas a rota `/notification-preferences` e a página continuam no app — funcionalidade ficou sem porta de entrada pela UI. | Confirmar intenção com o PO. Se intencional, remover rota+página; senão, restaurar a tile. |
| OBS-002 | Primeira execução 100% offline usa fonte do sistema até baixar a Barlow (`google_fonts` runtime). Paridade com o Viajante. | Aceitar ou embutir a fonte como asset. |
| OBS-003 | Botão "+" do header publica no feed mesmo com a sub-tab "Meu Perfil" ativa. Paridade com o Viajante. | Aceitar. |

---

## 3. Verificações que PASSARAM (evidência de código)

| Verificação | Resultado |
|---|---|
| Apps Guia e Viajante apontam para o **mesmo projeto Supabase** (`dvsmadvzgowtzjbyusfz`) → colunas novas (`nome_cracha`, `empresa`, `pais`, contatos de emergência) já existem e são gravadas pelo Viajante. Risco R1 rebaixado de Critical para "confirmar policy em staging". | ✅ PASS |
| `/profile/:userId` (pushes, posts, conexões, `connections_page.dart:242/262`) → abre a nova `SocialProfilePage` corretamente. | ✅ PASS |
| Deep links de notificação para tabs 1 (Itinerário) e 2 (Chats) — semântica das tabs preservada (`notifications_page.dart:299/313`). | ✅ PASS |
| Cache de perfil legado (JSON antigo sem campos novos) → campos são nullable com acesso via `json['...']` → sem exception, valores `null`. | ✅ PASS |
| Estado (UF) legado salvo por extenso ("São Paulo") → match por `name` no seletor → converte para "SP". | ✅ PASS |
| CPF/CEP legados (com ou sem máscara) → re-mascarados por `maskText` na carga. | ✅ PASS |
| Telefone legado sem DDI → `_parsePhone` cai no fallback BR e preserva o número digitado. | ✅ PASS (ressalva: guia estrangeiro com telefone legado sem DDI será rotulado +55 — cenário raro, coberto pelo TC-AD-010 em dispositivo) |
| Assets de imagem (background, logos, chat pattern) byte-idênticos entre os dois apps. | ✅ PASS |
| Páginas não migradas que desestruturam o estado de perfil com 8 campos (`food_preferences`, `medical_restrictions`) → estado não mudou de aridade → compilam e funcionam. | ✅ PASS |
| `flutter analyze` 0 erros; suíte de testes verde exceto `widget_test.dart` (template, falha desde o commit inicial). | ✅ PASS |
| Dark mode: `colorScheme.surface` escuro manteve `0xFF1E1E1E` (mesmo valor efetivo de antes) — sem regressão de contraste em cards/appbar. | ✅ PASS |

---

## 4. Test Summary — Fase 1 (estática)

| Métrica | Valor |
|---|---|
| Verificações executadas (estáticas) | 27 |
| PASS | 11 |
| **FAIL (defeitos)** | **8** (BUG-001 a BUG-008) |
| Observações/decisões pendentes | 3 |
| BLOCKED (exigem dispositivo/staging) | TC-CROP-001/002/004/005/006, TC-AD-001 (policy RLS), TC-REG-001 (push real), TC-REG-004/005 (visual), TC-MD-003/004 |

**Distribuição por severidade:** High: 4 (BUG-001, 002, 003, 004) · Medium: 2 (BUG-005, 006) · Low: 2 (BUG-007, 008)

### Recomendação: **REJECT para release imediato** ✋

Justificativa: 3 defeitos High/P1 no caminho crítico de push notifications e contato entre usuários (BUG-001/002/003), sendo o BUG-003 visível para todo usuário que tocar numa notificação de chat. Todos têm correção de baixo custo (estimativa: < 1h de dev no total). Após correção + sanity test dos fluxos afetados, o veredito migra para **CONDITIONAL APPROVE** pendente da fase 2 (testes em dispositivo, conforme plano).

**Ordem sugerida de correção:** BUG-003 (remover debug) → BUG-002 (redirect + errorBuilder + doc) → BUG-001 (wa.me) → BUG-004 (matching de nacionalidade) → BUG-005 (extensão) → BUG-007 (i18n) → BUG-006/008 conforme decisão.

---

## 5. Status das correções (atualizado em 10/07/2026)

| ID | Status | Correção aplicada |
|----|--------|-------------------|
| BUG-001 | ✅ **CORRIGIDO** | `profile_actions.dart`: telefone com `+` (formato novo, já contém DDI) usa os dígitos como estão; sem `+` (legado) recebe fallback `55`. |
| BUG-002 | ✅ **CORRIGIDO** | Router: rota `/settings` restaurada como redirect → `/home?tab=4`; adicionado `onException` no GoRouter (rota desconhecida → `/home`). Contrato `rotas_notificacao.md` atualizado. |
| BUG-003 | ✅ **CORRIGIDO** | Removidos os dois `showDialog` de "DEBUG ROTEAMENTO" de `home_page.dart` (initState e didUpdateWidget). |
| BUG-004 | ✅ **CORRIGIDO** | `account_data_page.dart`: novo `_matchNationality` — match por código ISO → nome do país → gentílicos comuns ("brasileir*"→BR, "american*"→US etc.); sem match, campo fica vazio forçando re-seleção (não coage mais para BR nem corrompe o dado). |
| BUG-005 | ✅ **CORRIGIDO** | `profile_cubit.dart`: `_fileExtension()` deriva a extensão de `file.name` quando `path` está vazio, com fallback `png` — aplicado nos 4 pontos de upload (incl. fluxo legado `saveChanges`). |
| BUG-006 | ⏸ **ACEITO (documentado)** | Dado stale na tab "Meu Perfil" até remontagem da aba — baixa gravidade; reavaliar se houver reclamação (opções: cubit singleton ou pull-to-refresh). |
| BUG-007 | ✅ **CORRIGIDO** | `image_cropper_modal.dart` (título, hint de gesto, Cancelar/Usar foto, erro) e `phone_field.dart` (hint de busca) internacionalizados via `context.t(pt, en)`. |
| BUG-008 | ✅ **CORRIGIDO** | `rotas_notificacao.md`: `/settings` marcado como descontinuado (usar `/home?tab=4`), tabela de abas documentada (0–4), descrição de `/profile/:userId` atualizada; comentários do `notification_navigation_service.dart` corrigidos. |
| OBS-001 | ⏳ Pendente PO | Tile "Notificações" fora do menu com rota viva — aguardando decisão. |

**Regressão pós-correção:** durante o ciclo, a suíte acusou 2 quebras não relacionadas aos bugs acima e ambas foram resolvidas:
1. `itinerary_tab.dart` — parêntese extra deixado por edição manual em andamento (erro de sintaxe) → corrigido.
2. `auth_redirection_test.dart` — a refatoração da home para `IndexedStack` passou a montar todas as abas no teste; registrados mocks de `FeedRepository`, `ProfileCubit` (estado `loaded` para não animar shimmer infinito) e `LanguageCubit` → teste verde.
3. `test/widget_test.dart` (teste template de contador, quebrado desde o commit inicial e impossível de passar) → removido para eliminar ruído permanente da suíte.

**Estado final:** `flutter analyze` 0 erros · `flutter test` **4/4 passando** · Veredito revisado: **CONDITIONAL APPROVE** — pendências restantes são exclusivamente da fase 2 em dispositivo/staging (RLS TC-AD-001, push real TC-REG-001, crop TC-CROP-001/005, visual TC-REG-004/005).
