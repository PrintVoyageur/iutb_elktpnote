# Projet : Surveillance des Logs avec ELK et Pare-feu

Ce projet consiste à créer un environnement de surveillance des logs et de filtrage des connexions réseau à l'aide de Docker, avec la pile Elastic (ELK : Elasticsearch, Logstash, Kibana) et un pare-feu utilisant `iptables`. Le but est de détecter des attaques de type **brute force** et d'analyser les logs générés par les serveurs et les pare-feu pour améliorer la sécurité.

## Objectif

Ce projet met en place une infrastructure où :

- Un **client** se connecte à un **serveur web** (Apache2).
- Un **pare-feu** filtrera les connexions et surveillera les tentatives de connexion suspectes.
- Les logs générés par le serveur et le pare-feu seront envoyés à **Logstash** pour être traités.
- Les logs seront stockés dans **Elasticsearch** et visualisés dans **Kibana** pour une analyse approfondie.

## Prérequis

Avant d'exécuter ce projet, vous devez avoir installé :

- **Docker** et **Docker Compose** sur votre machine.
- Une connexion à Internet pour télécharger les images Docker nécessaires.