FROM debian:buster-slim

RUN  apt-get update 
RUN  apt-get -y install \
  systemd \
  build-essential \
  vim \
  curl \
  gcc \
  flex \
  bison \
  wget \
  iputils-ping \
  iproute2 \
  net-tools \
  dnsutils \
  nmap \
  lsof \
  procps \
  tcpdump \
  nano \
  cron \
  sudo \
  pkg-config

RUN  apt-get -y install \
  libpcap0.8 \
  libpcap0.8-dev \
  libpcre3 \
  libpcre3-dev \
  libdumbnet1 \
  libdumbnet-dev \
  libdaq2 \
  libdaq-dev

RUN  apt-get -y install \
  zlib1g \
  zlib1g-dev \
  liblzma5 \
  liblzma-dev \
  luajit \
  libluajit-5.1-dev \
  libssl1.1 \
  libssl-dev \
  git \
  tcpreplay && \
  apt-get clean

RUN mkdir /root/TP

RUN echo "alias ls='ls $LS_OPTIONS'" >> /root/.bashrc
RUN echo "alias ll='ls $LS_OPTIONS -l'" >> /root/.bashrc
RUN echo "alias l='ls $LS_OPTIONS -lA'" >> /root/.bashrc

RUN echo "alias rm='rm -i'" >> /root/.bashrc
RUN echo "alias cp='cp -i'" >> /root/.bashrc
RUN echo "alias mv='mv -i'" >> /root/.bashrc
RUN echo "cd /root/TP" >> /root/.bashrc




