#!/bin/bash
#
# Installer Docker conformément à la doc
# https://docs.docker.com/engine/install/debian/

# Télécharger le Dockerfile
mkdir /root/TP
cd /root/TP
git clone https://github.com/beuneche/iutb_elktpnote.git

# Construction de l'image debian à partir du Dockerfile
docker build -t debian .

# Création des réseaux (bridge par défaut)
# On force la passerelle du réseau à .253 pour laisser le .254 à la connection du parefeu
docker network create --subnet 172.25.1.0/24 --gateway 172.25.1.253 --attachable monitoring
docker network create --subnet 172.25.2.0/24 --gateway 172.25.2.253 --attachable serveurs
docker network create --subnet 172.25.3.0/24 --gateway 172.25.3.253 --attachable clients

# Vérification des paramètres
docker network inspect monitoring

# Création des conteneurs
# Client = Conteneur simple attaché au réseau client
docker run -it --name client -h client.iutb.soc --network clients --ip 172.25.3.1 --privileged -d debian /sbin/init
# Server web = Conteneur attaché au réseau de serveurs avec mapping du port 80
docker run -it --name webserver -h webserver.iutb.soc --network serveurs --ip 172.25.2.1 -p 80:80 --privileged -d debian /sbin/init
# Server logstash = Conteneur attaché au réseau de supervision avec mapping du port 5044
docker run -it --name logstash -h logstash.iutb.soc --network monitoring --ip 172.25.1.1 -p 5044:5044 --privileged -d debian /sbin/init
# Server parefeu = Conteneur simple attaché au réseau de supervision avec une ip en .254
docker run -it --name parefeu -h parefeu.iutb.soc --network monitoring --ip 172.25.1.254 --privileged -d debian /sbin/init
# On connect le parefeu aux 2 autres réseaux
docker network connect --ip 172.25.2.254 serveurs parefeu
docker network connect --ip 172.25.3.254 clients parefeu

# Configuration du pare-feu (à exécuter dans le conteneur parefeu)
docker exec -it parefeu /bin/bash
# Vérification de l'activation de l'ip forwarding :=1
cat /proc/sys/net/ipv4/ip_forward
# Installation de iptables
apt-get install -y iptables
# Vérification que toutes les tables sont en ACCEPT
iptables -L -n
# activation du NAT (à exécuter à chaque restart du conteneur)
iptables -t nat -A POSTROUTING -j MASQUERADE

# Configuration réseau du conteneur client (à exécuter dans le conteneur client)
docker exec -it client /bin/bash
# Changement de la passerelle par défaut vers le parefeu
ip route delete default
ip route add default via 172.25.3.254

# Configuration réseau du conteneur webserver (à exécuter dans le conteneur webserver)
docker exec -it webserver /bin/bash
# Changement de la passerelle par défaut vers le parefeu
ip route delete default
ip route add default via 172.25.2.254

# Test du ping vers l'extérieur
ping 8.8.8.8
# Test du ping de client vers logstash
ping 172.25.1.1
# Test du ping de client vers webserver
ping 172.25.2.1

# Install de filebeat (à exécuter dans le conteneur webserver et parefeu)
docker exec -it parefeu /bin/bash # && docker exec -it webserver /bin/bash
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.1-amd64.deb
dpkg -i filebeat-8.11.1-amd64.deb
update-rc.d filebeat defaults
update-rc.d filebeat enable
# A lancer après la configuration de filebeat
#filebeat setup
#/etc/init.d/filebeat start

# Install de logstash (à exécuter dans le conteneur logstash)
docker exec -it logstash /bin/bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg
apt-get install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
apt-get update && apt-get install logstash


# **** A VOUS DE FAIRE ****
# Configuration simple de logstash
# On renseigne des fichiers locaux
# Ecoute sur le port 5044
# Sorties dans /var/log/logstash/apache et /var/log/logstash/iptables
# en fonction des tags apache2 et iptables  envoyé par filebeat



# Restart de logstash pour prise en compte de la conf
systemctl restart logstash
# surveillance des logs
tail -f /var/log/logstash/logstash-plain.log
# [...]
# [main] Starting input listener {:address=>"0.0.0.0:5044"}
# [...]

# Vérification du port 5044 ouvert depuis partout (0.0.0.0)
netstat -natp
# Active Internet connections (servers and established)
# Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
# tcp        0      0 127.0.0.11:33675        0.0.0.0:*               LISTEN      -                   
# tcp        0      0 127.0.0.1:9600          0.0.0.0:*               LISTEN      745/java            
# tcp        0      0 0.0.0.0:5044            0.0.0.0:*               LISTEN      745/java 

# Vérification sur webserver et parefeu de l'accès au port 5044 de logstash
docker exec -it parefeu /bin/bash # && docker exec -it webserver /bin/bash
nmap -p 5044 172.25.1.1
# Starting Nmap 7.70 ( https://nmap.org ) at 2024-01-27 16:44 UTC
# Nmap scan report for 172.25.1.1
# Host is up (0.00012s latency).
# 
# PORT     STATE SERVICE
# 5044/tcp open  lxi-evntsvc
# 
# Nmap done: 1 IP address (1 host up) scanned in 0.63 seconds

# Configuration webserver
docker exec -it webserver /bin/bash 
# Installation d'un serveur web
apt-get -y install apache2
systemctl start apache2


# **** A VOUS DE FAIRE ****
# Configuration de filebeat pour apache en utilisant le module apache
# Activer module apache
# Remplir /etc/filebeat/filebeat.yml
# Remplir /etc/filebeat/modules.d/apache.yml

# Start filebeat
etc/init.d/filebeat start
# On vérifie qu'une connexion est bien établie
netstat -natp
# [...]
# tcp        0      0 172.25.2.1:34062        172.25.1.1:5044         ESTABLISHED 1057/filebeat      


# Sur client, Vérification de l'accès au webserver
curl -s http://172.25.2.1
# doit retourner le contenu de la page web d'accueil d'apache

# sur webserver, vérification des logs
tail -f /var/log/apache2/access.log 
# 172.25.2.254 - - [27/Jan/2024:16:58:58 +0000] "GET / HTTP/1.1" 200 10956 "-" "curl/7.64.0"
# 172.25.2.254 - - [27/Jan/2024:16:59:08 +0000] "GET / HTTP/1.1" 200 10956 "-" "curl/7.64.0"
# 172.25.2.254 - - [27/Jan/2024:16:59:18 +0000] "GET / HTTP/1.1" 200 10956 "-" "curl/7.64.0"

# Sur logstash, vérification de la bonne reception des flux du webserver
tail -f /var/log/logstash/apache 
#{"host":{"name":"webserver.iutb.soc"},"@timestamp":"2024-01-27T16:54:12.274Z","service":{"type":"apache"},"input":{"type":"log"},"agent":{"version":"8.11.1","type":"filebeat","name":"webserver.iutb.soc","id":"08c6f164-58d5-4af1-ba94-3c94dae8fd69","ephemeral_id":"99478c6d-493b-4fd2-844d-7c619ed48dbd"},"event":{"module":"apache","timezone":"+00:00","dataset":"apache.error","original":"[Sat Jan 27 16:47:21.887569 2024] [core:notice] [pid 976:tid 140043263292544] AH00094: Command line: '/usr/sbin/apache2'"},"fileset":{"name":"error"},"message":"[Sat Jan 27 16:47:21.887569 2024] [core:notice] [pid 976:tid 140043263292544] AH00094: Command line: '/usr/sbin/apache2'","log":{"offset":156,"file":{"path":"/var/log/apache2/error.log"}},"tags":["apache2","web","beats_input_codec_plain_applied"],"@version":"1","ecs":{"version":"1.12.0"}}


# Sur le parefeu
# Installation de ulogd pour superviser le parefeu
apt-get install ulogd2
vi /etc/ulogd.conf
# [global]
# logfile="/var/log/ulogd.log"
# stack=log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU
# 
# [log1]
# group=1
# 
# [emu1]
# file="/var/log/firewall"
# sync=1

/etc/init.d/ulogd2 restart

# Anti Brut Force Rules
IPTABLES="/sbin/iptables"
$IPTABLES -A FORWARD -p tcp --dport 80 -m state --state NEW -m recent --set --name HTTP --rsource
$IPTABLES -A FORWARD -p tcp --dport 80 -m state --state NEW -j NFLOG --nflog-prefix "[Detect brutforce]:" --nflog-group 1

# Générer du traffic avec Curl sur client
# Vérifier dans les logs firewall
tail -f /var/log/firewall
# Jan 27 17:14:20 parefeu [Detect brutforce]: IN=eth1 OUT=eth3 MAC=02:42:ac:19:03:fe:02:42:ac:19:03:01:08:00 SRC=172.25.3.1 DST=172.25.2.1 LEN=60 TOS=00 PREC=0x00 TTL=63 ID=24339 DF PROTO=TCP SPT=37722 DPT=80 SEQ=1343476299 ACK=0 WINDOW=64240 SYN URGP=0 MARK=0
# Jan 27 17:14:20 parefeu [Detect brutforce]: IN=eth1 OUT=eth3 MAC=02:42:ac:19:03:fe:02:42:ac:19:03:01:08:00 SRC=172.25.3.1 DST=172.25.2.1 LEN=60 TOS=00 PREC=0x00 TTL=63 ID=26778 DF PROTO=TCP SPT=37736 DPT=80 SEQ=580960411 ACK=0 WINDOW=64240 SYN URGP=0 MARK=0
# Jan 27 17:14:22 parefeu [Detect brutforce]: IN=eth1 OUT=eth3 MAC=02:42:ac:19:03:fe:02:42:ac:19:03:01:08:00 SRC=172.25.3.1 DST=172.25.2.1 LEN=60 TOS=00 PREC=0x00 TTL=63 ID=9059 DF PROTO=TCP SPT=37742 DPT=80 SEQ=1826218728 ACK=0 WINDOW=64240 SYN URGP=0 MARK=0

# **** A VOUS DE FAIRE ****
# Configuration de filebeat pour parefeu en utilisant le module iptables
# Activer module iptables
# Remplir /etc/filebeat/filebeat.yml
# Remplir /etc/filebeat/modules.d/iptables.yml

/etc/init.d/filebeat restart
netstat -natp
# Active Internet connections (servers and established)
# Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
# tcp        0      0 127.0.0.11:45279        0.0.0.0:*               LISTEN      -
# tcp        0      0 172.25.1.254:51388      172.25.1.1:5044         ESTABLISHED 834/filebeat    

# Sur client on lance des requêtes web (stop with ctrl-c)
for item in {1..20000}; do curl -s -o /dev/null -w "%{http_code}" http://172.25.2.1; echo; sleep 2 ; done

# Sur logstash
# Vérification de la bonne réception des flux
tail -f /var/log/logstash/iptables
#{"service":{"type":"iptables"},"@timestamp":"2024-01-27T17:35:46.984Z","input":{"type":"log"},"agent":{"version":"8.11.1","type":"filebeat","name":"parefeu.iutb.soc","id":"eefc221e-ae81-4e9b-9521-6d892edffd74","ephemeral_id":"7a61709e-25fa-412a-8c65-b3fedbe38edd"},"event":{"module":"iptables","timezone":"+00:00","dataset":"iptables.log","original":"Jan 27 17:35:45 parefeu [Detect brutforce]: IN=eth1 OUT=eth3 MAC=02:42:ac:19:03:fe:02:42:ac:19:03:01:08:00 SRC=172.25.3.1 DST=172.25.2.1 LEN=60 TOS=00 PREC=0x00 TTL=63 ID=14937 DF PROTO=TCP SPT=58560 DPT=80 SEQ=3981665763 ACK=0 WINDOW=64240 SYN URGP=0 MARK=0 "},"fileset":{"name":"log"},"message":"Jan 27 17:35:45 parefeu [Detect brutforce]: IN=eth1 OUT=eth3 MAC=02:42:ac:19:03:fe:02:42:ac:19:03:01:08:00 SRC=172.25.3.1 DST=172.25.2.1 LEN=60 TOS=00 PREC=0x00 TTL=63 ID=14937 DF PROTO=TCP SPT=58560 DPT=80 SEQ=3981665763 ACK=0 WINDOW=64240 SYN URGP=0 MARK=0 ","log":{"offset":9338,"file":{"path":"/var/log/firewall"}},"@version":"1","tags":["iptables","forwarded","iptables","beats_input_codec_plain_applied"],"ecs":{"version":"1.12.0"}}



# **** A VOUS DE FAIRE ****
# on améliore la conf de logstash pour 
# - séparer le traitement des flux apache2 et iptables
# - leur paramétrer un grok pattern
#



# Fichier à lancer à chaque démarrage du conteneur client
echo "
ip route delete default
ip route add default via 172.25.3.254
" > /root/TP/post-start.sh

# Commande à lancer sur client pour lancer des requêtes http en continu pour le test
for item in {1..20000}; do curl -s -o /dev/null -w "%{http_code}" http://172.25.2.1; echo; sleep 2 ; done

# Fichier à lancer à chaque démarrage du conteneur parefeu
echo "
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.accept_redirects=1
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --dport 80 -m state --state NEW -m recent --set --name HTTP --rsource
iptables -A FORWARD -p tcp --dport 80 -m state --state NEW -j NFLOG --nflog-prefix "[Detect brutforce]:" --nflog-group 1
" > /root/TP/post-start.sh

# Fichier à lancer à chaque démarrage du conteneur webserver
echo "
ip route delete default
ip route add default via 172.25.2.254
" > /root/TP/post-start.sh

# Mais avant de relancer logstash, il faut installer et configurer ELK !
# Attention adapter le numero de version en consultant la page :
# https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
#
sudo echo "
vm.max_map_count=262144
" >> /etc/sysctl.conf
reboot

# Install elastic
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.12.0
docker run --name es01 --net monitoring --ip 172.25.1.3 -p 9200:9200 -it -m 1GB --restart always -d docker.elastic.co/elasticsearch/elasticsearch:8.12.0

# Rejouer la commande suivante jusqu'à récupérer les identifiants
docker logs es01

# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ✅ Elasticsearch security features have been automatically configured!
# ✅ Authentication is enabled and cluster connections are encrypted.
# 
# ℹ️  Password for the elastic user (reset with `bin/elasticsearch-reset-password -u elastic`):
#   y9Tep_UHOs2b9JEdJzBH
# 
# ℹ️  HTTP CA certificate SHA-256 fingerprint:
#   70abd97e9d5b058e3fb5a46f7647ad715eeb8166408072c73239c0b1ddc30dd6
# 
# ℹ️  Configure Kibana to use this cluster:
# • Run Kibana and click the configuration link in the terminal when Kibana starts.
# • Copy the following enrollment token and paste it into Kibana in your browser (valid for the next 30 minutes):
#   eyJ2ZXIiOiI4LjEyLjAiLCJhZHIiOlsiMTcyLjI1LjEuMzo5MjAwIl0sImZnciI6IjcwYWJkOTdlOWQ1YjA1OGUzZmI1YTQ2Zjc2NDdhZDcxNWVlYjgxNjY0MDgwNzJjNzMyMzljMGIxZGRjMzBkZDYiLCJrZXkiOiJ4YXl1VG8wQjhyWVkyeFZXU3NFaDpZbnFDdnNtQ1N1cS12ZVRFT2NHVTRRIn0=
# 
# ℹ️ Configure other nodes to join this cluster:
# • Copy the following enrollment token and start new Elasticsearch nodes with `bin/elasticsearch --enrollment-token <token>` (valid for the next 30 minutes):
#   eyJ2ZXIiOiI4LjEyLjAiLCJhZHIiOlsiMTcyLjI1LjEuMzo5MjAwIl0sImZnciI6IjcwYWJkOTdlOWQ1YjA1OGUzZmI1YTQ2Zjc2NDdhZDcxNWVlYjgxNjY0MDgwNzJjNzMyMzljMGIxZGRjMzBkZDYiLCJrZXkiOiJ3Nnl1VG8wQjhyWVkyeFZXU3NFSDpfcTdSRnpEeVJDeTM1RkRReEhwclRBIn0=
# 
#   If you're running in Docker, copy the enrollment token and run:
#   `docker run -e "ENROLLMENT_TOKEN=<token>" docker.elastic.co/elasticsearch/elasticsearch:8.12.0`
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# On  redémarre logstash et on surveille
#systemctl restart logstash && tail -f /var/log/logstash/logstash-plain.log 

export ELASTIC_PASSWORD="y9Tep_UHOs2b9JEdJzBH"
export ELASTIC_TOKEN="eyJ2ZXIiOiI4LjEyLjAiLCJhZHIiOlsiMTcyLjI1LjEuMzo5MjAwIl0sImZnciI6IjcwYWJkOTdlOWQ1YjA1OGUzZmI1YTQ2Zjc2NDdhZDcxNWVlYjgxNjY0MDgwNzJjNzMyMzljMGIxZGRjMzBkZDYiLCJrZXkiOiJ4YXl1VG8wQjhyWVkyeFZXU3NFaDpZbnFDdnNtQ1N1cS12ZVRFT2NHVTRRIn0="

# Effectuez un appel API REST à Elasticsearch pour vous assurer que le conteneur Elasticsearch est en cours d'exécution.
curl --cacert http_ca.crt -u elastic:$ELASTIC_PASSWORD https://localhost:9200
# {
#   "name" : "7ea1e8544052",
#   "cluster_name" : "docker-cluster",
#   "cluster_uuid" : "Y4EGt8bORs6aQYU5N77vXQ",
#   "version" : {
#     "number" : "8.12.0",
#     "build_flavor" : "default",
#     "build_type" : "docker",
#     "build_hash" : "1665f706fd9354802c02146c1e6b5c0fbcddfbc9",
#     "build_date" : "2024-01-11T10:05:27.953830042Z",
#     "build_snapshot" : false,
#     "lucene_version" : "9.9.1",
#     "minimum_wire_compatibility_version" : "7.17.0",
#     "minimum_index_compatibility_version" : "7.0.0"
#   },
#   "tagline" : "You Know, for Search"
# }

# Copiez le certificat SSL http_ca.crt du conteneur es01
docker cp es01:/usr/share/elasticsearch/config/certs/http_ca.crt .
# Le copier dans le conteneur logstash
docker cp http_ca.crt logstash:/opt/ca.crt

# Installation de Kibana
docker pull docker.elastic.co/kibana/kibana:8.12.0
docker run --name kib01 --net monitoring --ip 172.25.1.2 -p 5601:5601 --restart always -d docker.elastic.co/kibana/kibana:8.12.0
# Observation des logs
docker logs kib01
# [...]
# Go to http://0.0.0.0:5601/?code=225390 to get started.

# copier-coller le token
# Se connecter avec les identifiants elastic/y9Tep_UHOs2b9JEdJzBH cf. plus haut
# Aller dans Management puis dans API KEY pour générer une clé qui sera utilisée par logstash
# Attention : choisir le format logstash
# Dans cet exemple => 5azBTo0B8rYY2xVWFMHj:7XKm4qJ4RLSTGNVkn1uUOw

# Parametrage de logstash
# Changer les api_key
vi /etc/logstash/conf.d/logstash.conf
[...]
api_key => "5azBTo0B8rYY2xVWFMHj:7XKm4qJ4RLSTGNVkn1uUOw"
[...]

# Vérifier l'existance du certificat et son accessibilité par le démon logstash
cat /opt/ca.crt
chmod 755 /opt/ca.crt


# **** A VOUS DE FAIRE ****
# Modifier la configuration de logstash pour envoyer les flux vers Elastic
# en utilisant l'api_key et le certificat


# Redémarrer logstash et suivre les logs
systemctl restart logstash && tail -f /var/log/logstash/logstash-plain.log

# Vérifier dans Kibana l'apparition des index paramétrés dans la configuration de logstash
# dans management/data/index management
# puis créer 2 vues correspondant à ces index
# dans management/Kibana/Data views


# **** A VOUS DE FAIRE ****
# Donner des copie d'écran de Kibana et de la bonne reception des logs

# **** A VOUS DE FAIRE ****
# Trouver les règles iptables sur le parefeu pour détecter du forcebrut
# flux > 10 par secondes


# A vous de jouer avec Kibana
# et en premier lieu dans Analytics/Discover


# Memo
# Se connecter à un conteneur
# docker exec -it nom_conteneur /bin/bash
