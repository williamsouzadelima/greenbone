📌 Como usar a versão 1.7?

Baixe o script atualizado:

```
git clone https://github.com/seu-usuario/Greenbone-Install.git
cd Greenbone-Install
```


Dê permissão de execução:

```
chmod +x install_openvas.sh
```

Execute com permissões de root:

```
sudo ./install_openvas.sh
```


🌐 Acesso ao OpenVAS

```
URL: https://<IP_DO_KALI>
Usuário: admin
Senha: admin123
Acesso SSH:
ssh kali@<IP_DO_KALI>
```
Exportar relatório para Excel:

```
openvasreporting -i report.xml -o report.xlsx -f xlsx
```
