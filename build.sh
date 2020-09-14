#! /bin/bash

mkdir -p /root/sandbox/src

export GOPATH=/root/sandbox

# Helper functions
message() {
    echo ""
    echo "*******************************************************"
    echo "        $1"
    echo "*******************************************************"
    echo ""
}

# Work functions
installLibs() {
    message "Installing libraries"
    apt update
    apt install build-essential -y
    apt install git -y
    apt install cmake -y
    apt install debootstrap -y
    apt install libunwind-dev -y
    apt install squid-deb-proxy -y
    /etc/init.d/squid-deb-proxy start
}

installGo() {
    message "Installing Golang for build"
    wget -O /root/go1.15.linux-amd64.tar.gz https://golang.org/dl/go1.15.linux-amd64.tar.gz
    tar -C /usr/local -xzf /root/go1.15.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
}

setupBoring() {
    message "Retrieving BoringSSL"
    cd $GOPATH/src
    mkdir boringssl.googlesource.com
    cd boringssl.googlesource.com

    git clone https://boringssl.googlesource.com/boringssl
    cd boringssl
    git checkout fips-20190808

    message "Building BoringSSL"
    mkdir build
    cd build
    cmake -DFIPS=1 -DCMAKE_BUILD_TYPE=Release ..
    make

    cd ../..
    message "Creating BoringSSL archive"
    tar --exclude '.git' -cJf boringssl-ae223d6138807a13006342edfeef32e813246b39.tar.xz boringssl
    mv boringssl-ae223d6138807a13006342edfeef32e813246b39.tar.xz /root
}

setupBoringGo() {
    message "Retrieving Golang+BoringSSL"

    # Need SSH key to do this
    cd $GOPATH/src
    mkdir -p github.com
    cd github.com
    git clone git@github.com:TrustedKeep/go
    cd go
    git checkout tkgo1.15

    message "Building GoBoring crypto module"
    cd src/crypto/internal/boring/build
    ./build.sh

    message "Building Golang tools"
    cd $GOPATH/src/github.com/go/src
    ./all.bash

    message "Building dist package"
    cd ../../

    tar --exclude '.git' --exclude 'pkg/obj' -czvf boringgo.1.15.tgz go
    mv boringgo.1.15.2.tgz /root
}

installLibs
installGo
setupBoring
setupBoringGo