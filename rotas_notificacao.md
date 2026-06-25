# Rotas do Aplicativo Agrobravo Guia

Abaixo estão listadas todas as rotas disponíveis no aplicativo, junto com o formato que deve ser utilizado no campo `target_route` (ou `targetRoute`) ao disparar notificações push pelo painel.

## Formato do `target_route`

O painel deve enviar o caminho exato da rota, substituindo os parâmetros dinâmicos (como `:groupId` ou `:userId`) pelos IDs reais correspondentes.

### Rotas Principais (Sem parâmetros dinâmicos na URL)
Essas rotas podem ser chamadas diretamente como estão escritas.

- **Login / Tela Inicial:** `/`
- **Redefinição de Senha:** `/reset-password`
- **Home:** `/home`
  - *Opcional:* Pode receber aba e grupo via query. Exemplo: `/home?tab=1&groupId=123`
- **Criar Postagem:** `/create-post`
- **Notificações:** `/notifications`
- **Configurações:** `/settings`
- **Documentos:** `/documents`
- **Preferências Alimentares:** `/food-preferences`
- **Restrições Médicas:** `/medical-restrictions`
- **Preferências de Notificações:** `/notification-preferences`
- **Dados da Conta:** `/account-data`
- **Política de Privacidade:** `/privacy-policy`
- **Sobre Nós:** `/about-us`

### Rotas com Parâmetros Dinâmicos
Nestas rotas, você **deve** substituir a variável que começa com `:` pelo ID real.

- **Itinerário do Grupo:** `/itinerary/:groupId`
  - *Exemplo de uso:* `/itinerary/c85a1...`
- **Feed de Usuário Específico:** `/user-feed/:userId`
  - *Exemplo de uso:* `/user-feed/f92b4...`
  - *Opcional:* Pode focar em um post específico via query: `/user-feed/f92b4...?postId=123`
- **Conexões do Usuário:** `/connections/:userId`
  - *Exemplo de uso:* `/connections/f92b4...`
- **Perfil de Usuário:** `/profile/:userId`
  - *Exemplo de uso:* `/profile/f92b4...`
- **Chat Direto (DM):** `/chat/dm/:userId`
  - *Exemplo de uso:* `/chat/dm/f92b4...`
- **Lista de Ocorrências (Incidentes):** `/incident-list/:groupId`
  - *Exemplo de uso:* `/incident-list/c85a1...`
- **Lista de Despesas:** `/expense-list/:groupId`
  - *Exemplo de uso:* `/expense-list/c85a1...`
- **Histórico de Lembretes:** `/lembretes-historico/:groupId`
  - *Exemplo de uso:* `/lembretes-historico/c85a1...`

### Rotas que exigem estado interno (Não recomendadas para Push Notification direto)
As rotas a seguir dependem de objetos complexos (dados de estado interno - `extra`) passados durante a navegação pelo Flutter e **não** são recomendadas para redirecionamento direto via `target_route` de notificações push, pois podem falhar ao tentar abri-las diretamente sem o contexto adequado:

- `/document-details`
- `/document-history`
- `/member-details`

---

## Como usar no envio da notificação

Ao configurar a notificação no painel ou via API (Edge Function do Supabase), o payload (ou metadata) da notificação deve incluir o campo `targetRoute` (ou `target_route` dependendo da sua convenção) apontando para uma das rotas válidas acima.

**Exemplo de Payload de Notificação:**
```json
{
  "title": "Novo roteiro adicionado!",
  "body": "Toque para ver os detalhes do roteiro atualizado.",
  "data": {
    "target_route": "/itinerary/3aa788bf-1234-4567-8901-abcdef123456"
  }
}
```
