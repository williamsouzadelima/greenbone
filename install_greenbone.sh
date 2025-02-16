#!/bin/bash

# Definir a versão do script
SCRIPT_VERSION="1.5"

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
    openvas-reporting

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
pip3 install gvm-tools lxml chardet openvasreporting

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

# Instala o script de geração de relatórios XLSX
echo "[*] Instalando o script de geração de relatórios XLSX..."
cat << 'EOF' > /usr/local/bin/gerar_relatorio.py
import os
import subprocess
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading
import socket
import getpass
import time

def get_local_ip():
    hostname = socket.gethostname()
    return socket.gethostbyname(hostname)

def generate_report_interactively():
    print("=== Greenbone Report Generator ===\n")
    gmp_username = input("Digite o GMP Username (exemplo: admin): ").strip()
    gmp_password = getpass.getpass("Digite o GMP Password (entrada segura): ").strip()
    report_id = input("Digite o Report ID do relatório que deseja gerar: ").strip()
    xlsx_name = input("Digite o nome desejado para o arquivo XLSX (sem extensão): ").strip()
    port = input("Digite a porta para o servidor HTTP (padrão: 8000): ").strip()
    port = int(port) if port else 8000

    if not xlsx_name.endswith(".xlsx"):
        xlsx_name += ".xlsx"

    socket_path = "/var/run/gvmd/gvmd.sock"
    gen_report_script = "/usr/local/bin/gen_report_full.py"
    temp_report_path = "/tmp/report_generated.xml"
    output_report_path = f"/tmp/{xlsx_name}"

    gvm_command = [
        "sudo", "-u", "_gvm", "gvm-script",
        "--gmp-username", gmp_username,
        "--gmp-password", gmp_password,
        "socket",
        "--socketpath", socket_path,
        gen_report_script,
        report_id,
        temp_report_path
    ]

    print("\nGerando o relatório em formato XML...")
    try:
        subprocess.run(gvm_command, check=True)
        print(f"Relatório gerado com sucesso: {temp_report_path}")
    except subprocess.CalledProcessError as e:
        print(f"Erro ao gerar o relatório XML: {e}")
        return None, None, None

    openvas_command = [
        "openvasreporting",
        "-i", temp_report_path,
        "-o", output_report_path,
        "-f", "xlsx"
    ]

    print("\nConvertendo o relatório para formato XLSX...")
    try:
        subprocess.run(openvas_command, check=True)
        print(f"Relatório convertido com sucesso: {output_report_path}")
    except subprocess.CalledProcessError as e:
        print(f"Erro ao converter o relatório: {e}")
        return temp_report_path, None, None

    return temp_report_path, output_report_path, port

def start_http_server(directory, ip, port, xlsx_filename, duration=300):
    os.chdir(directory)
    server_address = (ip, port)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)

    def stop_server_after_duration():
        time.sleep(duration)
        print("\nO tempo limite de 5 minutos foi atingido. Encerrando o servidor HTTP...")
        httpd.shutdown()

    thread = threading.Thread(target=stop_server_after_duration, daemon=True)
    thread.start()

    print(f"\nServidor HTTP disponível em: http://{ip}:{port}")
    print(f"XML: http://{ip}:{port}/report_generated.xml")
    print(f"XLSX: http://{ip}:{port}/{xlsx_filename}")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor HTTP encerrado pelo usuário.")

if __name__ == "__main__":
    local_ip = get_local_ip()
    xml_path, xlsx_path, port = generate_report_interactively()
    if xml_path and xlsx_path:
        start_http_server("/tmp", local_ip, port, os.path.basename(xlsx_path), duration=300)
EOF

chmod +x /usr/local/bin/gerar_relatorio.py
echo "[*] Script de geração de relatórios instalado em /usr/local/bin/gerar_relatorio.py"

exit 0

