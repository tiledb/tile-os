#!/bin/bash

set -e

PYTHON_VERSION="3.7.17"
SRC_DIR="/usr/src"
PYTHON_SRC="${SRC_DIR}/Python-${PYTHON_VERSION}"

echo "Installing build dependencies..."
apt update
apt install -y \
    build-essential \
    wget \
    curl \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzma-dev \
    tk-dev \
    uuid-dev

cd ${SRC_DIR}

if [ ! -f "Python-${PYTHON_VERSION}.tgz" ]; then
    echo "Downloading Python ${PYTHON_VERSION}..."
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
fi

rm -rf "${PYTHON_SRC}"

echo "Extracting source..."
tar -xzf Python-${PYTHON_VERSION}.tgz

cd "${PYTHON_SRC}"

echo "Configuring build..."
./configure \
    --enable-optimizations \
    --enable-shared

echo "Compiling..."
make -j$(nproc)

echo "Installing..."
make altinstall

echo "Registering shared library..."
cat > /etc/ld.so.conf.d/python37.conf << EOF
/usr/local/lib
EOF

ldconfig

echo
echo "Verifying installation..."
python3.7 --version

echo
echo "Checking shared library..."
ldconfig -p | grep libpython3.7m || true

echo
echo "Installed libraries:"
ls -l /usr/local/lib/libpython3.7*

echo
echo "Testing SSL..."
python3.7 -c "import ssl; print(ssl.OPENSSL_VERSION)"

echo
echo "Testing pip..."
python3.7 -m pip --version

echo
echo "Done."