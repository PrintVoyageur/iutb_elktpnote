# Guide d'Installation Docker avec ELK et Filebeat

Ce guide détaille les étapes pour installer Docker et configurer un environnement avec des containers Debian, Logstash, Filebeat, Apache, et ELK (Elasticsearch, Logstash, Kibana). Suivez chaque étape pour configurer votre infrastructure de supervision et de journalisation.

## Prérequis

- Un système Debian ou Ubuntu avec Docker installé.
- Accès root ou sudo.
- Connexion internet pour télécharger les images et les dépendances.

---

## 1. Créer les réseaux Docker

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

