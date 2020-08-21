#! /bin/bash

export BORING_TAG="fips-20190808"
export BORING_DIR=$HOME/boringssl
export BUILD_DIR=$BORING_DIR/build
export GO_VERSION="1.15"
export GOROOT="/usr/local/go"
export PATH=$PATH:$GOROOT/bin
export BREAK_TESTS=" \
    AES_CBC \
    AES_GCM \
    DES \
    SHA_1 \
    SHA_256 \
    SHA_512 \
    RSA_SIG \
    ECDSA_SIG \
    DRBG \
    RSA_PWCT \
    ECDSA_PWCT"

message() {
    echo ""
    echo "*******************************************************"
    echo "        $1"
    echo "*******************************************************"
    echo ""
}

setupEnv() {
    message "Installing packages"
    sudo yum install gcc-c++-4.8.5-39.el7 -y
    sudo yum install http://repo.okay.com.mx/centos/7/x86_64/release/okay-release-1-1.noarch.rpm -y
    sudo yum install cmake3 -y
    sudo yum install git -y
    sudo yum install wget -y

    message "Installing bootstrapping Golang $GO_VERSION"
    cd $HOME
    local goFile="go$GO_VERSION.linux-amd64.tar.gz"
    wget https://golang.org/dl/$goFile
    sudo tar -C /usr/local -xf $goFile
    go version

    message "Cloning BoringSSL $BORING_TAG"
    cd $HOME
    git clone https://boringssl.googlesource.com/boringssl
    cd boringssl
    git checkout $BORING_TAG
    mkdir build
}

buildAndTest() {
    local breakTest=$1
    if [ "$breakTest" != "" ]; then
        breakTest="-DFIPS_BREAK_TEST=$breakTest"
    fi

    message "Building $breakTest"
    cd $BUILD_DIR
    local cmd="cmake3 -DFIPS=1 $breakTest .."
    eval $cmd
    make

    message "Running crypto test $breakTest"
    ./crypto/crypto_test

    message "Running ssl test $breakTest"
    ./ssl/ssl_test
}

setupEnv
echo "Starting tests `date`"
buildAndTest
for bt in $BREAK_TESTS; do
    buildAndTest $bt
done
echo "Complete `date`"