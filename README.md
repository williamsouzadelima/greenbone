📌 Instalação e Configuração do Greenbone OpenVAS no Kali Linux

Este script automatiza a instalação e configuração do Greenbone OpenVAS em um sistema Kali Linux, tornando-o pronto para uso rapidamente. Ele inclui diversas otimizações para melhorar a experiência do usuário e garantir que o scanner de vulnerabilidades funcione corretamente.
🔧 O que o script faz?
✅ Atualiza o sistema e instala todas as dependências necessárias
✅ Instala e configura o Greenbone OpenVAS
✅ Habilita e inicia os serviços essenciais (PostgreSQL, Redis, OpenVAS Scanner, GSA)
✅ Configura a interface web para rodar na porta 443
✅ Atualiza automaticamente os feeds do Greenbone (GVMD_DATA, SCAP e CERT) às 07:00 e 19:00
✅ Exibe as credenciais de acesso e a URL para acesso ao scanner
📜 Como usar o script?
Clone o repositório ou baixe o script manualmente:
git clone https://github.com/seu-usuario/Greenbone-Install.git
cd Greenbone-Install
Dê permissão de execução:
chmod +x install_openvas.sh
Execute o script como root:
sudo ./install_openvas.sh
🌐 Acesso ao Greenbone OpenVAS
Após a instalação, o OpenVAS estará acessível via navegador:
🌍 URL: https://<IP_DO_KALI>
🔑 Usuário: admin
🔒 Senha: admin123
📢 Nota: Após a instalação, recomenda-se alterar a senha do usuário admin por questões de segurança.
🛠 Personalizações Futuras
Se precisar de ajustes, como agendamento de scans automáticos, exportação de relatórios, ou integração com Wazuh, contribuições são bem-vindas! 🚀
📩 Dúvidas ou sugestões? Abra uma Issue ou um Pull Request!
