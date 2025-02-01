# Commandes Filebeat

## Installer Filebeat sur le serveur web et le pare-feu

1. **Télécharger et installer Filebeat**

```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.1-amd64.deb
dpkg -i filebeat-8.11.1-amd64.deb
update-rc.d filebeat defaults
update-rc.d filebeat enable
```

2. **Sur le serveur web :**

Éditer /etc/filebeat/filebeat.yml pour configurer la sortie vers Logstash.

```yml
output.logstash:
  hosts: ["172.25.1.1:5044"]
  ssl.certificate_authorities: ["/opt/ca.crt"]
```

filebeat modules enable apache

```bash
filebeat modules enable apache
```

Configurer le module Apache dans /etc/filebeat/modules.d/apache.yml :

```yml
apache:
  var.paths: ["/var/log/apache2/access.log", "/var/log/apache2/error.log"]
  input:
    type: log
    enabled: true
    paths:
      - /var/log/apache2/*.log
```
**Démarrer Filebeat**

```bash
/etc/init.d/filebeat start
```

3. **Sur le pare-feu :**

Configurer également Filebeat pour envoyer les logs du pare-feu vers Logstash.

```bash
filebeat modules enable iptables
```

Configurer le module dans /etc/filebeat/modules.d/iptables.yml :

```yml
iptables:
  var.paths: ["/var/log/firewall"]
  input:
    type: log
    enabled: true
    paths:
      - /var/log/firewall
```

Démarrer Filebeat sur le pare-feu

```bash
/etc/init.d/filebeat start
```

