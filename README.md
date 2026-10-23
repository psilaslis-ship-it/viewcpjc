# Dual Display Player

MVP local para um computador Linux com duas saídas: contador digital na VGA e player de mídia/Holyrics na HDMI. O navegador de cada tela é separado; o painel só controla o estado por Socket.IO na rede local.

No painel, a cor do contador começa em **contraste automático**: dígitos claros sobre fundo escuro e dígitos escuros sobre fundo claro. Em **cor personalizada**, é possível escolher a cor dos dígitos independentemente do fundo. Configurações existentes são preservadas; instalações anteriores passam ao modo automático quando atualizadas.

## Executar para desenvolvimento

```bash
npm install
npm start
```

Abra `http://IP-DO-SERVIDOR:8080/admin.html`. As telas de reprodução são `clock.html` e `hdmi.html`.

## Implantação

O procedimento reproduzível completo, incluindo a instalação do Debian sem desktop, está em [docs/INSTALACAO-PT-BR.md](docs/INSTALACAO-PT-BR.md). Para a instalação e atualização operacional, use respectivamente `scripts/install.sh` e `scripts/update.sh`.

## Implantação manual resumida (Debian 13)

1. Instale `nodejs`, `chromium`, `xserver-xorg`, um WM leve (Openbox ou i3), `fonts-dseg`, e os drivers gráficos corretos. O pacote `fonts-dseg` fornece a fonte de sete segmentos usada como padrão pelo contador.
2. Copie a aplicação para `/opt/dual-display-player`; crie o usuário de serviço `display` e o diretório `/var/lib/dual-display-player` pertencentes a ele.
3. Rode `npm ci --omit=dev` em `/opt/dual-display-player` e habilite `deploy/dual-display-player.service` com `systemctl enable --now`.
4. Inicialize uma única sessão X leve no boot (sem desktop completo) e execute `deploy/start-displays.sh` nela. Antes disso, confira os nomes reais com `xrandr --query`; HDMI/VGA podem aparecer como `HDMI-1`, `HDMI-A-0`, `VGA-1` etc.
5. Fixe a posição de cada janela no gerenciador leve. Em produção, configure as regras pelo `WM_CLASS` `VgaClock` e `HdmiPlayer`, em monitores distintos, sem decoração e em tela cheia.
6. Reserve IP DHCP ou configure IP estático e acesse o painel em `http://IP:8080/admin.html`. Se houver DNS local, crie um registro como `painel-igreja.lan` apontando para esse IP.

## Holyrics

As cinco rotas fornecidas já são incluídas por padrão. É possível cadastrar, excluir e selecionar outras no painel. O HDMI abre a rota escolhida por `/holyrics?url=...`, um proxy de mesma origem; assim não há polling, captura de tela ou atraso introduzido pela aplicação. A atualização continua sendo feita diretamente pela página do Holyrics.

## Segurança antes de expor a outras redes

O painel foi desenhado para LAN confiável. Antes de colocá-lo em uma rede compartilhada, adicione autenticação e limite o firewall para as sub-redes administrativas. Não exponha a porta 8080 à internet.
