FROM ubuntu:16.10
MAINTAINER krad.tv

WORKDIR /opt
RUN apt-get update -y
RUN apt-get install -y git build-essential nasm wget curl yasm g++ clang libicu-dev libpython2.7 libxml2 libxml2-dev libcurl3
RUN wget https://swift.org/builds/swift-4.0.3-release/ubuntu1610/swift-4.0.3-RELEASE/swift-4.0.3-RELEASE-ubuntu16.10.tar.gz ; tar zxfv swift-4.0.3-RELEASE-ubuntu16.10.tar.gz
