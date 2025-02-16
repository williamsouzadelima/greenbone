#!/bin/bash

# Definir a versão do script
SCRIPT_VERSION="1.7"

# Atualiza o sistema e instala dependências
echo "[*] Iniciando instalação do Greenbone OpenVAS - Versão $SCRIPT_VERSION"
echo "[*] Atualizando pacotes e instalando dependências..."
apt update -y && apt upgrade -y
apt install -y \
    sudo curl net-tools \
    postgresql postgresql-contrib \
    redis \
    gpgsm gnutls-bin rsync \
    snmp nmap \
    python3-impacket \
    openvas \
    openssh-server \
    python3-pip \
    python3-flask \
    python3-openssl \
    python3-lxml python3-xlwt python3-xlrd python3-openpyxl \
    git

# Habilita e inicia os serviços necessários
echo "[*] Iniciando serviços..."
systemctl enable --now postgresql
systemctl enable --now redis-server

# Habilita e inicia o SSH
echo "[*] Configurando SSH para iniciar automaticamente..."
systemctl enable --now ssh
echo "[*] SSH foi ativado e está rodando!"

# Instala bibliotecas Python necessárias para os scripts de relatórios
echo "[*] Instalando dependências Python para geração de relatórios..."
pip3 install gvm-tools lxml chardet flask flask-wtf openvasreporting cryptography

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

# Adicionando usuário ao grupo _gvm
USER_TO_ADD="kali"
echo "[*] Adicionando o usuário '$USER_TO_ADD' ao grupo '_gvm' e ajustando permissões..."
sudo chown root:$USER_TO_ADD /bin/gvm-script
sudo chown _gvm:$USER_TO_ADD -R /var/run/gvmd/
sudo usermod -a -G _gvm $USER_TO_ADD
echo "[*] Usuário '$USER_TO_ADD' adicionado ao grupo '_gvm' com sucesso!"

# Configura atualização automática dos feeds às 07:00 e 19:00
echo "[*] Configurando atualização automática dos feeds..."
(crontab -l 2>/dev/null; echo "0 7 * * * /usr/bin/greenbone-feed-sync --type GVMD_DATA") | crontab -
(crontab -l 2>/dev/null; echo "0 7 * * * /usr/bin/greenbone-feed-sync --type SCAP") | crontab -
(crontab -l 2>/dev/null; echo "0 7 * * * /usr/bin/greenbone-feed-sync --type CERT") | crontab -
(crontab -l 2>/dev/null; echo "0 19 * * * /usr/bin/greenbone-feed-sync --type GVMD_DATA") | crontab -
(crontab -l 2>/dev/null; echo "0 19 * * * /usr/bin/greenbone-feed-sync --type SCAP") | crontab -
(crontab -l 2>/dev/null; echo "0 19 * * * /usr/bin/greenbone-feed-sync --type CERT") | crontab -

# Instalação do OpenVAS Reporting (Exportador de Excel)
echo "[*] Clonando o repositório OpenVAS Reporting..."
git clone https://github.com/TheGroundZero/openvasreporting.git /opt/openvasreporting

echo "[*] Instalando OpenVAS Reporting..."
cd /opt/openvasreporting
python3 setup.py install

# Adicionando openvasreporting ao PATH
echo 'export PATH=$PATH:/opt/openvasreporting/scripts' >> ~/.bashrc
source ~/.bashrc

# Verificar instalação do openvasreporting
if command -v openvasreporting &> /dev/null; then
    echo "[*] OpenVAS Reporting instalado com sucesso!"
else
    echo "[!] Erro ao instalar OpenVAS Reporting. Verifique manualmente."
fi

# Exibe informações de acesso
IP=$(hostname -I | awk '{print $1}')
echo "[*] OpenVAS instalado com sucesso!"
echo "[*] Acesse a interface web pelo navegador:"
echo "➡️  https://$IP"
echo "[*] Login: admin"
echo "[*] Senha: admin123"
echo "[*] SSH ativado! Você pode acessar remotamente via:"
echo "➡️  ssh kali@$IP"
echo "[*] OpenVAS Reporting instalado! Para exportar relatórios, use:"
echo "➡️  openvasreporting -i <arquivo.xml> -o <arquivo.xlsx> -f xlsx"
echo "[*] Versão do script: $SCRIPT_VERSION"

exit 0

