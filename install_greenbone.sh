#!/bin/bash

# Definir a versão do script
SCRIPT_VERSION="1.9"
LOG_FILE="/var/log/install_openvas.log"
PROGRESS_BAR_WIDTH=50

# Criar ou limpar o arquivo de log
echo "[*] Iniciando instalação do Greenbone OpenVAS - Versão $SCRIPT_VERSION" | tee $LOG_FILE
echo "[*] Registro da instalação salvo em $LOG_FILE"

# Função para exibir barra de progresso
progress_bar() {
    local progress=$1
    local filled=$((progress * PROGRESS_BAR_WIDTH / 100))
    local empty=$((PROGRESS_BAR_WIDTH - filled))
    printf "\r[%-${filled}s%${empty}s] %d%%" "#" "" "$progress"
}

# Função para executar comandos e mostrar progresso
run_step() {
    local message=$1
    local command=$2
    local increment=10

    echo "[*] $message..." | tee -a $LOG_FILE
    for ((i = 0; i <= 100; i += increment)); do
        progress_bar $i
        sleep 0.2
    done
    echo ""

    eval "$command" >> $LOG_FILE 2>&1 || { echo "[ERRO] $message falhou! Verifique o log em $LOG_FILE"; exit 1; }
    echo "[OK] $message concluído!" | tee -a $LOG_FILE
}

# Atualizar pacotes
run_step "Atualizando pacotes do sistema" "apt update -y && apt upgrade -y"

# Instalar dependências essenciais
run_step "Instalando dependências do OpenVAS" "apt install -y sudo curl net-tools postgresql postgresql-contrib redis gpgsm gnutls-bin rsync snmp nmap python3-impacket openvas openssh-server python3-pip python3-flask python3-openssl python3-lxml python3-xlwt python3-xlrd python3-openpyxl git"

# Habilitar e iniciar serviços essenciais
run_step "Iniciando PostgreSQL" "systemctl enable --now postgresql"
run_step "Iniciando Redis" "systemctl enable --now redis-server"
run_step "Iniciando SSH" "systemctl enable --now ssh"

# Instalar bibliotecas Python
run_step "Instalando pacotes Python para relatórios" "pip3 install --break-system-packages gvm-tools lxml chardet flask flask-wtf openvasreporting cryptography"

# Instalar OpenVAS
if command -v gvmd &> /dev/null; then
    echo "[*] OpenVAS já está instalado. Pulando esta etapa..." | tee -a $LOG_FILE
else
    run_step "Instalando OpenVAS" "apt install -y openvas"
fi

# Configurar o banco de dados do OpenVAS
run_step "Configurando banco de dados do OpenVAS" "sudo -u postgres gvmd --create-user=admin --password=admin123"

# Atualizar os feeds do OpenVAS
run_step "Atualizando os feeds do OpenVAS" "greenbone-feed-sync --type GVMD_DATA && greenbone-feed-sync --type SCAP && greenbone-feed-sync --type CERT"

# Alterar a porta do Greenbone para 443
run_step "Alterando a porta do Greenbone para 443" "sed -i 's/9392/443/' /etc/default/gsad && sed -i 's/9392/443/' /lib/systemd/system/greenbone-security-assistant.service"

# Reiniciar serviços do OpenVAS
run_step "Reiniciando serviços do OpenVAS" "systemctl daemon-reload && systemctl restart openvas-scanner && systemctl restart gvmd && systemctl restart gsad"

# Adicionar usuário ao grupo _gvm
USER_TO_ADD="kali"
run_step "Adicionando o usuário '$USER_TO_ADD' ao grupo '_gvm'" "sudo chown root:$USER_TO_ADD /bin/gvm-script && sudo chown _gvm:$USER_TO_ADD -R /var/run/gvmd/ && sudo usermod -a -G _gvm $USER_TO_ADD"

# Configurar atualização automática dos feeds
run_step "Configurando atualização automática dos feeds" "(crontab -l 2>/dev/null; echo '0 7 * * * /usr/bin/greenbone-feed-sync --type GVMD_DATA') | crontab - && (crontab -l 2>/dev/null; echo '0 19 * * * /usr/bin/greenbone-feed-sync --type GVMD_DATA') | crontab -"

# Instalação do OpenVAS Reporting (Exportador de Excel)
run_step "Clonando o repositório OpenVAS Reporting" "git clone https://github.com/TheGroundZero/openvasreporting.git /opt/openvasreporting"

run_step "Instalando OpenVAS Reporting" "cd /opt/openvasreporting && python3 setup.py install"

# Adicionando openvasreporting ao PATH
run_step "Adicionando openvasreporting ao PATH" "echo 'export PATH=$PATH:/opt/openvasreporting/scripts' >> ~/.bashrc && source ~/.bashrc"

# Verificar se o openvasreporting foi instalado corretamente
if command -v openvasreporting &> /dev/null; then
    echo "[*] OpenVAS Reporting instalado com sucesso!" | tee -a $LOG_FILE
else
    echo "[!] Erro ao instalar OpenVAS Reporting. Verifique manualmente." | tee -a $LOG_FILE
fi

# Exibir informações finais
IP=$(hostname -I | awk '{print $1}')
echo "[*] Instalação concluída com sucesso!" | tee -a $LOG_FILE
echo "[*] OpenVAS está disponível em: https://$IP" | tee -a $LOG_FILE
echo "[*] Login: admin | Senha: admin123" | tee -a $LOG_FILE
echo "[*] SSH disponível: ssh kali@$IP" | tee -a $LOG_FILE
echo "[*] Para exportar relatórios, use: openvasreporting -i <arquivo.xml> -o <arquivo.xlsx> -f xlsx" | tee -a $LOG_FILE
echo "[*] Versão do script: $SCRIPT_VERSION" | tee -a $LOG_FILE

exit 0

