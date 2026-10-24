# Instalação completa — ViewCPJC

## 1. Preparar o computador

- Conecte somente o monitor do contador à VGA do computador Debian. A TV será conectada ao HDMI do TV box, que deve estar na mesma rede local.
- Prefira SSD e conexão Ethernet. Não instale ambiente de desktop: a solução inicia apenas o Xorg, Openbox e o contador local.
- Baixe a imagem **Debian 13 netinst amd64** no site oficial, grave um pendrive com Balena Etcher ou Rufus e inicialize por ele.

## 2. Instalar o Debian

1. Escolha idioma, teclado, fuso `America/Sao_Paulo` e uma senha forte para o administrador.
2. Conecte a rede por cabo. Em rede com DHCP, o endereço será entregue automaticamente.
3. No particionamento, a opção guiada com disco inteiro é adequada para uma máquina dedicada. Ela apaga o disco escolhido.
4. Em seleção de software, marque apenas **servidor SSH** e **utilitários padrão do sistema**. Desmarque GNOME e qualquer ambiente gráfico.
5. Reinicie e entre pelo terminal local ou por SSH.

## 3. Instalar a solução

No terminal do Debian, execute cada comando:

```bash
apt update
apt install -y git
git clone https://github.com/psilaslis-ship-it/viewcpjc.git
cd viewcpjc
./scripts/install.sh
```

O instalador instala dependências, baixa a cópia operacional em `/opt/viewcpjc`, cria os serviços de inicialização e preserva dados em `/var/lib/viewcpjc`. Com VGA conectada, ele detecta e grava automaticamente o nome da saída Linux no primeiro uso.

## 4. Conferir a saída VGA

No primeiro boot, as telas podem ficar sem conteúdo caso os conectores tenham nomes diferentes dos exemplos. No console, rode:

```bash
DISPLAY=:0 xrandr --query
nano /etc/viewcpjc/display.conf
systemctl restart viewcpjc-display
```

Troque `VGA-1` pelo nome mostrado em `xrandr` se necessário. O comando abaixo mostra diagnóstico se o contador não abrir:

```bash
journalctl -u viewcpjc-display -n 100 --no-pager
```

## 5. Usar pela rede local

No equipamento, descubra o IP com `hostname -I`. Em outro computador da mesma rede, abra:

```text
http://IP-DO-SERVIDOR:8080/admin.html
```

Na mesma rede, abra no navegador do TV box:

```text
http://IP-DO-SERVIDOR:8080/player.html
```

Ative a tela cheia no navegador do TV box, se disponível. O TV box deve manter a página aberta; a inicialização automática depende do sistema e modelo do aparelho. Primeiro teste uma mensagem e depois uma imagem/vídeo pelo painel. Para o Holyrics, altere **Holyrics → IP e porta** para o IP atual do computador com Holyrics na LAN. O endereço antigo `169.254.83.107` não respondeu a partir do Debian na rede `192.168.15.x`; ele não deve ser usado até que a conectividade seja corrigida. Teste a rota no painel e abra a mesma URL diretamente no navegador do TV box.

Para um nome fácil, crie no DNS local do roteador/AdGuard/Pi-hole um registro A, por exemplo `viewcpjc.lan`, apontando para o IP reservado do Debian. Reserve esse IP no DHCP do roteador para ele não mudar.

## 6. Atualizar

```bash
cd /opt/viewcpjc
./scripts/update.sh
```

O atualizador interrompe o contador local, obtém a versão `main` do GitHub, atualiza os pacotes e reinicia os serviços. Configurações, uploads e o estado atual não são apagados. A página do TV box pode precisar ser recarregada após a atualização.

## Segurança

O painel não deve ser publicado na internet. Mantenha a porta 8080 acessível apenas pela LAN confiável. Antes de permitir uso em rede compartilhada, implemente autenticação no painel e regras de firewall restritivas.
