# Instalação completa — ViewCPJC

## 1. Preparar o computador

- Confirme que a placa de vídeo oferece HDMI e VGA simultâneos; conecte os dois monitores antes de iniciar o sistema.
- Prefira SSD, 4 GB de RAM ou mais e conexão Ethernet. Não instale ambiente de desktop: a solução inicia apenas o Xorg, Openbox e os dois players.
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
sudo apt update
sudo apt install -y git
git clone https://github.com/psilaslis-ship-it/viewcpjc.git
cd viewcpjc
sudo ./scripts/install.sh
```

O instalador instala dependências, baixa a cópia operacional em `/opt/viewcpjc`, cria os serviços de inicialização e preserva dados em `/var/lib/viewcpjc`. Com HDMI e VGA conectados, ele detecta e grava automaticamente os nomes das saídas Linux no primeiro uso.

## 4. Associar HDMI e VGA corretamente

No primeiro boot, as telas podem ficar sem conteúdo caso os conectores tenham nomes diferentes dos exemplos. No console, rode:

```bash
DISPLAY=:0 xrandr --query
sudo nano /etc/viewcpjc/display.conf
sudo systemctl restart viewcpjc-display
```

Troque `HDMI-1` e `VGA-1` pelos nomes mostrados em `xrandr`. A VGA é posicionada à esquerda da HDMI. O comando abaixo mostra diagnóstico se algo não abrir:

```bash
sudo journalctl -u viewcpjc-display -n 100 --no-pager
```

## 5. Usar pela rede local

No equipamento, descubra o IP com `hostname -I`. Em outro computador da mesma rede, abra:

```text
http://IP-DO-SERVIDOR:8080/admin.html
```

Para um nome fácil, crie no DNS local do roteador/AdGuard/Pi-hole um registro A, por exemplo `viewcpjc.lan`, apontando para o IP reservado do servidor. Reserve esse IP no DHCP do roteador para ele não mudar.

## 6. Atualizar

```bash
cd /opt/viewcpjc
sudo ./scripts/update.sh
```

O atualizador interrompe os players, obtém a versão `main` do GitHub, atualiza os pacotes, e reinicia os dois serviços. Configurações, uploads e o estado atual não são apagados.

## Segurança

O painel não deve ser publicado na internet. Mantenha a porta 8080 acessível apenas pela LAN confiável. Antes de permitir uso em rede compartilhada, implemente autenticação no painel e regras de firewall restritivas.
