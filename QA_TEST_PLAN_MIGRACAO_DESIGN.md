# 📋 Plano de Testes — Migração de Design AgroBravo Guia

| Campo | Valor |
|---|---|
| **Documento** | QA Test Plan — Migração do padrão de design do app Viajante para o app Guia |
| **Versão** | 1.0 |
| **Data** | 10/07/2026 |
| **Autor** | QA Engineer (Claude) |
| **App/Versão alvo** | AgroBravo Guia `1.5.1+13` |
| **Plataforma alvo** | Mobile (Flutter — Android 8.0+ / iOS 14+) |
| **Backend** | Supabase (compartilhado com o app Viajante — tabela `users`, storage `files`) |
| **Fase do SDLC** | Pós-refactor, pré-release — ciclo de **regressão dirigida por risco** |
| **Escopo da mudança** | 67 arquivos alterados (+4.029 / −2.621 linhas) |

---

## 1. Contexto e escopo

Migração do padrão de design do app Viajante (`agrobravo-app-viajante/appagrobravo`) para o app Guia:

1. **Design tokens / brandbook**: fonte Poppins → **Barlow**; primary `#08B078` → **`#679436`**; secondary `#094EF8` → teal `#07B68D`; escala de espaçamentos (lg 24→32, xl 32→48, xxl 48→64, novo xxxl 96); tema global reescrito (`_buildLightTheme`/`_buildDarkTheme` em `main.dart` com cards, botões, inputs, appbar, switch).
2. **Configurações → Meus Dados**: aba "Perfil" da navegação virou "Meus dados" (ícone crachá + badge de pendência); tela nova com card do usuário (avatar com crop), seções CONTA / PREFERÊNCIAS / SUPORTE e logout. Rota `/settings` e ícone de engrenagem **removidos**.
3. **Perfil junto do feed**: aba "Comunidade" com TabBar **Feed / Meu Perfil** (`CommunityTab` + `SocialProfilePage`). Rota `/profile/:userId` agora abre `SocialProfilePage`.
4. **Crop de imagens**: `ImageCropperModal` portado (avatar circular, capa 16:9 com grade de terços, pinch-zoom 1×–4×, saída PNG 800px, upload imediato).
5. **Dados da Conta**: página completa do Viajante (crachá, telefone internacional com DDI, contato de emergência, empresa, nacionalidade→CPF/SSN, ViaCEP, seletor de país/UF, validação, dirty-check, excluir conta) + campo Passaporte mantido do Guia. Entidade e repositório estendidos com colunas `empresa`, `pais`, `nome_cracha`, `nome_contato_emergencia`, `grau_parentesco_emergencia`, `contato_emergencia`.
6. **Cores hardcoded**: ~40 ocorrências dos verdes antigos (`#00B289`, `#00AA6C`, `#00E676`) substituídas por `AppColors.primary` em login, Início do guia, dashboard, chat, itinerário, lembretes e detalhes de membro.

**Estado estático no momento da escrita:** `flutter analyze` com **0 erros**; suíte de testes verde exceto `test/widget_test.dart` (teste template do Flutter, falha desde o commit inicial — pré-existente, fora do escopo).

### Fora de escopo deste ciclo
- Testes de performance/carga do backend Supabase.
- Telas não afetadas funcionalmente (chat de áudio, documentos, incidentes, despesas) — cobertas apenas por smoke visual (R6).
- Testes de acessibilidade completos WCAG (recomendado para ciclo posterior).

### Critérios de entrada
- Build debug/staging instalável em dispositivo físico Android e iOS.
- Conta de guia de teste em staging + conta descartável para o fluxo de exclusão.
- Acesso ao painel do Supabase (staging) para verificação de persistência.

### Critérios de saída
- 100% dos casos P1 executados; 0 defeitos Critical/High abertos sem correção ou aceite formal do risco.
- Riscos residuais documentados e aceitos pelo PO.

---

## 2. Análise de Riscos (priorizada)

| # | Risco | Impacto | Prob. | Justificativa |
|---|-------|---------|-------|---------------|
| R1 | **UPDATE nas colunas novas do Supabase falhar por RLS** (`empresa`, `pais`, `nome_cracha`, `nome_contato_emergencia`, `grau_parentesco_emergencia`, `contato_emergencia`) | Critical | Média | O Viajante grava nessas colunas, mas as *policies* podem filtrar por role/colunas. Usuário `tipouser=GUIA` nunca gravou nelas. Falha aqui quebra o "Salvar" da tela inteira de Dados da Conta (o update é um único statement). |
| R2 | **Deep links / push notifications apontando para rotas alteradas** — `/settings` removida; `/profile/:userId` mudou de tela | High | Média | O guia tem `NotificationNavigationService` e roteamento custom (ver `rotas_notificacao.md`). Um push antigo ou payload do backend apontando `/settings` agora cai no redirect ou em rota inexistente. |
| R3 | **Formato do telefone mudou** — antes `(11) 98765-4321`, agora `+55 (11) 98765-4321`; e o botão WhatsApp monta `https://wa.me/55$phone` com prefixo `55` fixo | High | Alta | (a) Dado legado sem dial code cai no fallback BR — errado para guia estrangeiro. (b) **Suspeita de defeito**: telefone já salvo com `+55` gera `wa.me/5555DDD...` (código duplicado) — o `replaceAll(\D)` preserva o `55` do dial code. |
| R4 | **Cache de perfil (SharedPreferences) com schema antigo** após update do app | Medium | Alta | `_getProfileFromCache` lê JSON gravado pela versão anterior, sem os campos novos (nullable → deve funcionar, mas precisa de verificação em upgrade real). |
| R5 | **Crop de imagem em dispositivos reais** — fotos 48MP, HEIC no iOS, permissões negadas, pouca RAM | High | Média | Componente novo no guia. Detalhe técnico: `XFile.fromData` tem `path` vazio → a extensão enviada ao storage fica vazia (arquivo `"<timestamp>."`). Funciona no Viajante, mas confirmar no bucket `files` usado pelo guia. |
| R6 | **Mudança global de `AppSpacing`** (lg 24→32, xl 32→48) afeta todas as telas, inclusive não migradas (dashboard, despesas, incidentes) | Medium | Alta | Risco de overflow de `Row`/`Column` e cortes de texto em telas pequenas (320px de largura lógica) que antes cabiam com 24px. |
| R7 | **Fonte Barlow via `google_fonts` = download em runtime** no primeiro uso | Medium | Média | Primeira execução 100% offline exibe fonte fallback do sistema. Mesmo comportamento do Viajante — aceito, mas documentado. |
| R8 | **`ProfileCubit` por instância (não singleton)**: dado stale entre telas | Medium | Alta | Meus Dados recarrega ao remontar a aba, mas a tab "Meu Perfil" dentro da Comunidade **não remonta** ao alternar sub-tabs — foto/nome alterados em outra tela podem não refletir imediatamente. |

### Ambiguidade a resolver com o PO
- A tile **"Notificações"** foi removida do menu Meus Dados (edição manual posterior à migração), mas a rota `/notification-preferences` continua registrada. **Intencional ou perda de acesso à funcionalidade?** Enquanto não respondido, tratado como risco residual documentado.

---

## 3. Casos de Teste

> Convenções: **Sev** = Critical / High / Medium / Low · **Pri** = P1 (bloqueador de release) a P4.
> Campos "Resultado obtido" e "Status" (PASS / FAIL / BLOCKED / SKIP) devem ser preenchidos na execução.

### 3.1 Módulo NAV — Navegação inferior

| ID | Título | Pré-condições | Passos | Resultado esperado | Sev | Pri |
|----|--------|---------------|--------|--------------------|-----|-----|
| TC-NAV-001 | Estrutura das 5 abas | Guia logado | 1. Login como guia 2. Observar bottom nav | Início, Itinerário, Chats, **Comunidade** (ícone grupo), **Meus dados** (ícone crachá). Aba ativa: verde `#679436`, ícone preenchido, sublinhado animado de 18px | High | P1 |
| TC-NAV-002 | Badge de pendência em Meus Dados | Documento com ação pendente | 1. Observar aba Meus dados 2. Resolver a pendência 3. Reobservar | Bolinha vermelha sobre o ícone de crachá; some após resolver | Medium | P2 |
| TC-NAV-003 | Botão “+” só na Comunidade | Missão ativa selecionada | Percorrer as 5 abas observando o header | “+” aparece apenas na Comunidade; habilitado somente se a missão permite post | Medium | P2 |
| TC-NAV-004 | Engrenagem removida | — | Abrir aba Meus dados e observar o header | **Não** existe ícone de configurações | Low | P3 |

### 3.2 Módulo COM — Comunidade (Feed + Meu Perfil)

| ID | Título | Pré-condições | Passos | Resultado esperado | Sev | Pri |
|----|--------|---------------|--------|--------------------|-----|-----|
| TC-COM-001 | Tabs Feed / Meu Perfil | Missão com posts | 1. Abrir Comunidade 2. Alternar tabs por tap e por swipe | TabBar com indicador verde; swipe horizontal funciona; posição de scroll preservada ao alternar | High | P1 |
| TC-COM-002 | Feed sem missão selecionada | Nenhuma missão selecionada | 1. Abrir Comunidade > Feed | EmptyState "Nenhum feed ativo" com botão que leva à aba Início. Tab **Meu Perfil continua acessível e funcional** | High | P1 |
| TC-COM-003 | Meu Perfil = usuário logado | Guia com posts e conexões | Abrir tab Meu Perfil | Capa, avatar, stats (conexões/posts/missões), selo "Guia oficial", botões Editar perfil/Publicar, grid de posts. Sem AppBar duplicada | High | P1 |
| TC-COM-004 | Perfil de terceiro via post | Feed com post de outro usuário | 1. Tocar no avatar do autor | Abre `SocialProfilePage` com header "Perfil" (voltar) e botão de conexão conforme status: Conectar / Solicitado / Aceitar+Recusar / Desconectar+WhatsApp | High | P1 |
| TC-COM-005 | ⚠️ R3 — WhatsApp com telefone novo formato | Conexão aceita; telefone do outro usuário salvo como `+55 (11) 9...` | 1. Abrir perfil do conectado 2. Tocar WhatsApp | Abre `wa.me/55DDDNÚMERO` — **sem** `5555` duplicado no início | High | P1 |
| TC-COM-006 | ⚠️ R8 — Stale data entre tabs | — | 1. Abrir Meu Perfil 2. Ir a Meus Dados e trocar a foto 3. Voltar à Comunidade > Meu Perfil | Avatar atualizado (ou comportamento documentado como limitação conhecida) | Medium | P2 |
| TC-COM-007 | Publicar pela tab Meu Perfil | Missão permite post | 1. Meu Perfil > Publicar 2. Câmera/Galeria 3. Concluir post | Post criado aparece no grid e no feed após reload | High | P1 |

### 3.3 Módulo CROP — Recorte de imagens

| ID | Título | Pré-condições | Passos | Resultado esperado | Sev | Pri |
|----|--------|---------------|--------|--------------------|-----|-----|
| TC-CROP-001 | Avatar circular (galeria) | Foto landscape 4000×3000 na galeria | 1. Meus Dados > tocar avatar 2. Galeria 3. Pinch zoom + arrastar 4. "Usar foto" | Overlay circular; zoom limitado 1×–4×; pan limitado às bordas da imagem; spinner no avatar durante upload; imagem final corresponde à área recortada, sem distorção | High | P1 |
| TC-CROP-002 | Capa 16:9 | Foto **portrait** na galeria | 1. Meu Perfil > Editar perfil 2. Câmera da capa 3. Selecionar foto 4. Ajustar e confirmar | Overlay retangular 16:9 com grade de terços; imagem cobre a área sem esticar; capa atualizada | High | P1 |
| TC-CROP-003 | Cancelamento em cada etapa | — | Cancelar: (a) no bottom sheet de origem (b) no picker (c) no crop (X e botão Cancelar) | Nenhum upload disparado; nenhum estado de loading preso | High | P1 |
| TC-CROP-004 | Permissão de câmera negada | Permissão negada no SO | 1. Tocar avatar > Câmera | Snackbar de erro amigável; sem crash | High | P1 |
| TC-CROP-005 | ⚠️ R5 — Foto pesada / HEIC | iPhone com foto HEIC 48MP | 1. Selecionar a foto no fluxo de avatar | Crop abre sem OOM; resultado PNG 800px; upload conclui e URL renderiza | High | P1 |
| TC-CROP-006 | Perda de rede durante upload | — | 1. Confirmar crop 2. Ativar modo avião imediatamente | Erro tratado (estado de erro do cubit); sem spinner infinito; nova tentativa possível | High | P2 |

### 3.4 Módulo MD — Meus Dados

| ID | Título | Pré-condições | Passos | Resultado esperado | Sev | Pri |
|----|--------|---------------|--------|--------------------|-----|-----|
| TC-MD-001 | Estrutura da tela | Guia logado | Abrir Meus dados | Card do usuário (avatar+câmera, nome, missão em verde, e-mail) → CONTA (Meus documentos c/ badge "Pendente", Dados da conta) → PREFERÊNCIAS (Condições médicas, Modo claro/escuro, Idioma) → SUPORTE (Política de privacidade, Sobre nós) → botão Sair → rodapé "AgroBravo Guia". Shimmer durante carregamento | High | P1 |
| TC-MD-002 | Navegação das tiles | — | Tocar cada tile e voltar | Cada rota abre corretamente; retorno preserva a aba Meus dados | High | P1 |
| TC-MD-003 | Toggle de tema | — | 1. Alternar switch escuro/claro 2× 2. Matar e reabrir o app | Tema muda imediatamente em toda a UI; escolha persiste após restart | Medium | P2 |
| TC-MD-004 | Troca de idioma | — | 1. Idioma > English 2. Percorrer telas 3. Matar e reabrir | Bottom sheet com bandeiras BR/US; UI inteira em EN na hora; persiste após restart | Medium | P2 |
| TC-MD-005 | Logout com confirmação | — | 1. Sair da conta > Cancelar 2. Repetir > Sair | Cancelar mantém sessão; Sair leva ao login e invalida sessão (voltar não re-entra) | High | P1 |
| TC-MD-006 | Pull-to-refresh | — | Puxar a lista para baixo | Recarrega o perfil sem duplicar elementos | Low | P3 |

### 3.5 Módulo AD — Dados da Conta ⚠️ *maior risco do release*

| ID | Título | Pré-condições | Passos | Resultado esperado | Sev | Pri |
|----|--------|---------------|--------|--------------------|-----|-----|
| TC-AD-001 | ⚠️ R1 — **Persistência dos campos novos** | Conta guia em staging; acesso ao painel Supabase | 1. Preencher crachá, empresa, contato de emergência (nome/parentesco/telefone), país, endereço completo 2. Salvar 3. **Matar o app**, reabrir, voltar à tela 4. Conferir no painel Supabase | Snackbar de sucesso + retorno automático; TODOS os valores persistidos no app e nas colunas `nome_cracha`, `empresa`, `pais`, `nome_contato_emergencia`, `grau_parentesco_emergencia`, `contato_emergencia` | **Critical** | **P1** |
| TC-AD-002 | Validação de obrigatórios | — | 1. Limpar o campo Nome 2. Salvar | Snackbar de erro; campos obrigatórios vazios com borda vermelha; **nenhuma** chamada ao backend | High | P1 |
| TC-AD-003 | Nacionalidade BR ↔ US ↔ outra | — | Alternar a nacionalidade entre BR, US e Portugal | BR: exibe CPF (máscara `###.###.###-##`, obrigatório); US: exibe SSN (obrigatório); outra: nenhum dos dois. A troca limpa o campo anterior | High | P1 |
| TC-AD-004 | ViaCEP happy + error | País = Brasil | (a) CEP `01310-100` (b) CEP inexistente `99999-999` (c) sem rede | (a) rua/bairro/cidade/UF autopreenchidos, spinner no campo durante busca (b) sem alteração, preenchimento manual possível (c) falha silenciosa, sem crash | High | P1 |
| TC-AD-005 | Telefone internacional | — | 1. Trocar país do telefone para US 2. Digitar número | Máscara muda para `(###) ###-####`; campo é limpo na troca de país; valor salvo com `+1 ` | Medium | P2 |
| TC-AD-006 | Botão Salvar por dirty-check | — | 1. Abrir a tela sem alterar nada 2. Alterar um campo 3. Reverter manualmente | Salvar inicia desabilitado; habilita na 1ª alteração; desabilita ao reverter | Medium | P2 |
| TC-AD-007 | Data de nascimento — BVA | — | (a) Tentar data futura (b) Selecionar 01/01/1900 | (a) Picker bloqueia datas futuras (b) 1900 aceito | Low | P3 |
| TC-AD-008 | Passaporte (campo mantido do guia) | — | 1. Preencher passaporte 2. Salvar 3. Reabrir | Valor persistido (`n_passaporte`) | Medium | P2 |
| TC-AD-009 | Excluir conta — fluxo destrutivo | **Conta descartável em staging** | 1. Excluir conta > Cancelar 2. Repetir > "Sim, excluir" | Cancelar = sem efeito. Confirmar = loading → logout → redirect ao login; login com as credenciais antigas falha | Critical | P1 |
| TC-AD-010 | ⚠️ R3 — Perfil legado (telefone sem `+XX`) | Conta antiga com `(11) 98765-4321` no banco | Abrir Dados da Conta | Campo carrega com bandeira BR e número correto, sem truncamento | High | P1 |

### 3.6 Módulo REG — Regressão de rotas, integrações e design

| ID | Título | Pré-condições | Passos | Resultado esperado | Sev | Pri |
|----|--------|---------------|--------|--------------------|-----|-----|
| TC-REG-001 | ⚠️ R2 — **Push notification com deep link** | Backend de staging capaz de enviar push | Enviar push dos tipos usados em produção (chat, documento, lembrete) com app em **foreground, background e killed** | Navegação correta nos 3 estados; nenhum payload referencia `/settings` | Critical | P1 |
| TC-REG-002 | Rota `/settings` morta | Link/push antigo apontando `/settings` | Forçar navegação para `/settings` | Redirect gracioso (sem tela branca ou crash) | Medium | P2 |
| TC-REG-003 | Grid de posts → user-feed | Perfil com múltiplos posts | 1. Meu Perfil > tocar num post do grid | Abre "Publicações" com scroll posicionado no post tocado; like/editar/excluir funcionam | High | P1 |
| TC-REG-004 | ⚠️ R6 — Fluxos não migrados intactos | Dispositivo 320px lógico (mdpi) | Smoke: check-in/check-out, chat (texto+áudio), documentos, incidentes, despesas, lembretes | Sem regressão funcional; sem overflow visual (faixas amarelas/cortes) com os novos espaçamentos | High | P1 |
| TC-REG-005 | Tema/fonte no app inteiro | — | Percorrer todas as telas em modo claro **e** escuro | Barlow em 100% dos textos (nenhum Poppins residual); verde `#679436` em botões/links/acentos; **nenhum** verde antigo (`#08B078`/`#00B289`/`#00E676`) visível | High | P1 |
| TC-REG-006 | ⚠️ R7 — Primeira execução offline | Instalação limpa; sem rede | Abrir o app | App abre com fonte fallback do sistema (documentado); sem crash; Barlow aparece após primeira execução online | Low | P3 |
| TC-REG-007 | ⚠️ R4 — Cache de perfil legado | Versão anterior instalada com cache de perfil gravado | 1. Atualizar o app por cima 2. Abrir perfil em modo offline | Perfil carrega do cache sem exception; campos novos vazios | Medium | P2 |

---

## 4. Matriz mínima de dispositivos

| Dispositivo | Motivo |
|---|---|
| Android físico low-end (2–3GB RAM, mdpi/hdpi, Android 9) | R5 (crop/OOM) + R6 (overflow em 320px) |
| Android recente (API 34+) | Permissões granulares de mídia (`READ_MEDIA_IMAGES`) |
| iPhone físico (iOS 16+) | HEIC no crop, permissões, push APNS |
| Modo escuro + idioma EN em ambos | Combinação tema × i18n |

---

## 5. Recomendações

1. **Bloqueadores de release:** TC-AD-001, TC-REG-001 e TC-CROP-001/005. Se o RLS do Supabase rejeitar as colunas novas (R1), o update inteiro da tela falha — testar primeiro (5 minutos com um usuário guia em staging).
2. **Verificação por código antes do ciclo manual:** (a) o defeito suspeito do `wa.me/55` duplicado (R3) — análise estática sugere defeito real e a correção é de 1 linha; (b) policies RLS via query no painel do Supabase.
3. **Automatizar (pós-release):** golden tests dos design tokens (cor/fonte) para impedir regressão de brandbook; widget tests da validação de Dados da Conta — são os fluxos que mais quebram silenciosamente.
4. **Riscos residuais documentados:**
   - Tile "Notificações" removida do menu deixa `/notification-preferences` inacessível por UI (aguardando decisão do PO).
   - Primeira execução 100% offline usa fonte de sistema até a primeira execução online (comportamento idêntico ao Viajante).
   - Tab "Meu Perfil" pode exibir dado stale após edição em outra tela (R8) até remontagem da aba.

---

## 6. Test Summary (preencher ao fim do ciclo)

| Métrica | Valor |
|---|---|
| Total de casos | 30 |
| Executados | — |
| PASS | — |
| FAIL | — |
| BLOCKED | — |
| SKIP | — |
| Pass rate | — |
| Defeitos por severidade | Critical: — / High: — / Medium: — / Low: — |

**Veredito atual (pré-execução): CONDITIONAL APPROVE** — código estaticamente íntegro (`flutter analyze` 0 erros; testes verdes exceto template pré-existente), porém os cenários **Critical (R1/R2/R3) exigem execução em dispositivo/staging** antes de qualquer distribuição.
