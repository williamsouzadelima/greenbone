#!/bin/bash

# Atualiza o sistema e instala dependências
echo "[*] Atualizando pacotes e instalando dependências..."
apt update -y && apt upgrade -y
apt install -y \
    sudo curl net-tools \
    postgresql postgresql-contrib \
    redis \
    gpgsm gnutls-bin rsync \
    snmp nmap \
    python3-impacket \
    openvas

# Habilita e inicia os serviços necessários
echo "[*] Iniciando serviços..."
systemctl enable --now postgresql
systemctl enable --now redis-server

# Verifica se o OpenVAS já está instalado
if command -v gvmd &> /dev/null; then
    echo "[*] OpenVAS já está instalado. Continuando configuração..."
else
    echo "[*] Instalando OpenVAS..."
    apt install -y openvas
fi

# Configura o banco de dados
echo "[*] Configurando banco de dados..."
sudo -u postgres gvmd --create-user=admin --password=admin123

# Atualiza os feeds
echo "[*] Atualizando feeds iniciais (isso pode demorar)..."
greenbone-feed-sync --type GVMD_DATA && echo "[*] GVMD_DATA atualizado com sucesso!"
greenbone-feed-sync --type SCAP && echo "[*] SCAP atualizado com sucesso!"
greenbone-feed-sync --type CERT && echo "[*] CERT atualizado com sucesso!"

# Configura a porta do Greenbone Security Assistant (GSA) para 443
echo "[*] Configurando Greenbone para rodar na porta 443..."
sed -i 's/9392/443/' /etc/default/gsad
sed -i 's/9392/443/' /lib/systemd/system/greenbone-security-assistant.service

# Reinicia os serviços para aplicar a nova configuração de porta
systemctl daemon-reload
systemctl restart openvas-scanner
systemctl restart gvmd
systemctl restart gsad

# Configura atualização automática dos feeds às 07:00 e 19:00
echo "[*] Configurando atualização automática dos feeds..."
(crontab -l 2>/dev/null; echo "0 7 * * * /usr/bin/greenbone-feed-sync --type GVMD_DATA && echo '[*] GVMD_DATA atualizado com sucesso às 07:00!'") | crontab -
(crontab -l 2>/dev/null; echo "0 7 * * * /usr/bin/greenbone-feed-sync --type SCAP && echo '[*] SCAP atualizado com sucesso às 07:00!'") | crontab -
(crontab -l 2>/dev/null; echo "0 7 * * * /usr/bin/greenbone-feed-sync --type CERT && echo '[*] CERT atualizado com sucesso às 07:00!'") | crontab -

(crontab -l 2>/dev/null; echo "0 19 * * * /usr/bin/greenbone-feed-sync --type GVMD_DATA && echo '[*] GVMD_DATA atualizado com sucesso às 19:00!'") | crontab -
(crontab -l 2>/dev/null; echo "0 19 * * * /usr/bin/greenbone-feed-sync --type SCAP && echo '[*] SCAP atualizado com sucesso às 19:00!'") | crontab -
(crontab -l 2>/dev/null; echo "0 19 * * * /usr/bin/greenbone-feed-sync --type CERT && echo '[*] CERT atualizado com sucesso às 19:00!'") | crontab -

# Exibe informações de acesso
IP=$(hostname -I | awk '{print $1}')
echo "[*] OpenVAS instalado com sucesso!"
echo "[*] Acesse a interface web pelo navegador:"
echo "➡️  https://$IP"
echo "[*] Login: admin"
echo "[*] Senha: admin123"

exit 0

