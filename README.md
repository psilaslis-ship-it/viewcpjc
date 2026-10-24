# Dual Display Player

O computador Debian exibe somente o contador digital na VGA. O TV box exibe mídia e Holyrics pelo navegador, acessando `http://IP-DO-DEBIAN:8080/player.html`. O painel de controle fica em `http://IP-DO-DEBIAN:8080/admin.html`. Os dois players recebem estados independentes por Socket.IO na rede local.

No painel, a cor do contador começa em **contraste automático**: dígitos claros sobre fundo escuro e dígitos escuros sobre fundo claro. Em **cor personalizada**, é possível escolher a cor dos dígitos independentemente do fundo. Configurações existentes são preservadas; instalações anteriores passam ao modo automático quando atualizadas.

O contador VGA abre sem barras do navegador e em tela cheia pelo Openbox. O HDMI do Debian não é mais usado. O TV box precisa ter navegador compatível e manter `player.html` aberta em tela cheia; inicialização automática depende do modelo e sistema do aparelho. O ponteiro do Debian fica oculto após um segundo de inatividade e o Chromium do contador não oferece tradução de páginas.

## Executar para desenvolvimento

```bash
npm install
npm start
```

Abra `http://IP-DO-SERVIDOR:8080/admin.html`. O contador local usa `clock.html`; o TV box usa `player.html` (`hdmi.html` continua disponível como endereço legado).

## Implantação

O procedimento reproduzível completo, incluindo a instalação do Debian sem desktop, está em [docs/INSTALACAO-PT-BR.md](docs/INSTALACAO-PT-BR.md). Para a instalação e atualização operacional, use respectivamente `scripts/install.sh` e `scripts/update.sh`.

## Implantação manual resumida (Debian 13)

Use o [guia de instalação](docs/INSTALACAO-PT-BR.md) e os scripts `scripts/install.sh` e `scripts/update.sh`. Reserve o IP do Debian no DHCP do roteador para que o endereço do player não mude.

## Holyrics

As cinco rotas fornecidas já são incluídas por padrão. No painel, **Holyrics → IP e porta** troca o servidor de todas as rotas, preservando os caminhos; também é possível cadastrar, excluir e selecionar rotas individuais. Em **Conteúdo → Holyrics → Testar conexão**, o Debian verifica se a rota responde. O navegador do TV box abre a rota escolhida diretamente, sem proxy ou captura de tela introduzidos pela aplicação. O plugin Holyrics deve estar iniciado e **tanto o Debian quanto o TV box** precisam alcançar o IP e a porta configurados. Endereços `169.254.x.x` não devem ser presumidos acessíveis pela rede local `192.168.x.x`; configure no painel o endereço LAN atual do computador com Holyrics.

## Segurança antes de expor a outras redes

O painel foi desenhado para LAN confiável. Antes de colocá-lo em uma rede compartilhada, adicione autenticação e limite o firewall para as sub-redes administrativas. Não exponha a porta 8080 à internet.
