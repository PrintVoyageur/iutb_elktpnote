# Guide d'Installation Docker avec ELK et Filebeat

Ce guide détaille les étapes pour installer Docker et configurer un environnement avec des containers Debian, Logstash, Filebeat, Apache, et ELK (Elasticsearch, Logstash, Kibana). Suivez chaque étape pour configurer votre infrastructure de supervision et de journalisation.

## Prérequis

- Un système Debian ou Ubuntu avec Docker installé.
- Accès root ou sudo.
- Connexion internet pour télécharger les images et les dépendances.

---

## 1. Créer un répertoire pour le projet

Commencez par créer un répertoire de travail dans `/root/TP` et clonez le repository contenant le Dockerfile.

```bash
mkdir /root/TP
cd /root/TP

git clone https://github.com/PrintVoyageur/iutb_elktpnote.git
```

## 2. Créer les réseaux Docker

Nous allons créer trois réseaux Docker avec des sous-réseaux et des passerelles spécifiques pour chaque réseau.

``` bash
docker network create --subnet 172.25.1.0/24 --gateway 172.25.1.253 --attachable monitoring
docker network create --subnet 172.25.2.0/24 --gateway 172.25.2.253 --attachable serveurs
docker network create --subnet 172.25.3.0/24 --gateway 172.25.3.253 --attachable clients
``` 

Vérifiez la configuration des réseaux :

``` bash
docker network inspect monitoring
```

[]

##  3. Construire l'image Docker

Construisez l'image Debian à partir du Dockerfile dans le répertoire cloné.

``` bash
docker build -t debian .
```

##   4. Créer les Conteneurs Docker

Créez les conteneurs suivants avec leurs réseaux et IPs spécifiques :

- Conteneur Client (réseau clients)

``` bash
docker run -it --name client -h client.iutb.soc --network clients --ip 172.25.3.1 --privileged -d debian /sbin/init
```

- Conteneur Web Server (réseau serveurs)

``` bash
docker run -it --name webserver -h webserver.iutb.soc --network serveurs --ip 172.25.2.1 -p 80:80 --privileged -d debian /sbin/init
```

Conteneur Logstash (réseau monitoring)

``` bash
docker run -it --name logstash -h logstash.iutb.soc --network monitoring --ip 172.25.1.1 -p 5044:5044 --privileged -d debian /sbin/init
```

Conteneur Pare-feu (réseau monitoring)
``` bash
docker run -it --name parefeu -h parefeu.iutb.soc --network monitoring --ip 172.25.1.254 --privileged -d debian /sbin/init
```

## 5. Connecter le Pare-feu aux autres réseaux

Connectez le pare-feu aux réseaux **serveurs** et **clients** :

Vérification de l'IP forwarding

``` bash
cat /proc/sys/net/ipv4/ip_forward
```

Installation d'iptables

``` bash
apt-get install -y iptables
```

## 7. Configuration Réseau des Conteneurs

Client

``` bash
docker exec -it client /bin/bash
ip route delete default
ip route add default via 172.25.3.254
```

Web Server

``` bash
docker exec -it webserver /bin/bash
ip route delete default
ip route add default via 172.25.2.254
```

## 8. Test de Connectivité

Testez la connectivité réseau entre les conteneurs et l'extérieur.

``` bash
ping 8.8.8.8
```

Ping du Client vers Logstash

``` bash
ping 172.25.1.1
```

Ping du Client vers le Web Server

``` bash
ping 172.25.2.1
```

## 9. Installer Filebeat dans le Web Server et le Pare-feu

Téléchargement et Installation de Filebeat

``` bash
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.1-amd64.deb
dpkg -i filebeat-8.11.1-amd64.deb
update-rc.d filebeat defaults
update-rc.d filebeat enable
```

Configuration de Filebeat

Dans le conteneur **webserver** et **parefeu**, activez le module **apache** et **iptables** de Filebeat.

[filebeat configuration][def2]

``` bash
/etc/init.d/filebeat start
```

## 10. Installer Logstash

Téléchargement et Installation de Logstash

``` bash
docker exec -it logstash /bin/bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg
apt-get install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
apt-get update && apt-get install logstash
```

## 11. Configurer Logstash pour Collecter les Logs

Configurez Logstash pour recevoir les logs de Filebeat et les envoyer vers Elasticsearch.

``` conf
input {
  beats {
    port => 5044
    ssl => false
  }
}

filter {
  if "apache2" in [tags] {
    grok {
      match => { "message" => "%{COMMONAPACHELOG}" }
    }
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
  }
  if "iptables" in [tags] {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP} %{IPV4:src_ip} %{IPV4:dst_ip} %{DATA:protocol} %{INT:src_port} %{INT:dst_port} %{GREEDYDATA:message}" }
    }
    date {
      match => [ "timestamp", "MMM dd HH:mm:ss" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["https://172.25.1.3:9200"]
    api_key => "5azBTo0B8rYY2xVWFMHj:7XKm4qJ4RLSTGNVkn1uUOw"
    ssl => true
    cacert => "/opt/ca.crt"
    index => "apache2-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "${y9Tep_UHOs2b9JEdJzBH}"
  }
}

```
[file logstash.conf][def]



## 12. Installer Elasticsearch

Pull d'Elasticsearch et Lancement du Conteneur

``` bash
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.12.0
docker run --name es01 --net monitoring --ip 172.25.1.3 -p 9200:9200 -it -m 1GB --restart always -d docker.elastic.co/elasticsearch/elasticsearch:8.12.0
```

##  13. Installer Kibana

Pull de Kibana et Lancement du Conteneur

``` bash
docker pull docker.elastic.co/kibana/kibana:8.12.0
docker run --name kib01 --net monitoring --ip 172.25.1.2 -p 5601:5601 --restart always -d docker.elastic.co/kibana/kibana:8.12.0
```

## 14. Configurer Kibana et Vérifier les Logs

Accédez à Kibana à l'adresse http://localhost:5601 et configurez les index de Logstash. Vous pouvez maintenant surveiller les logs Apache et iptables via Kibana.

[def]: logstash.conf
[def2]: filebeat.md