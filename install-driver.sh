#!/bin/bash
#
# Script de instalación automatizada para el driver FL2000/IT66121
# Compila el driver, crea un paquete .deb y lo instala correctamente
#

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables globales
DRIVER_NAME="fl2000-dkms"
DRIVER_VERSION="1.0.0"
WORK_DIR=$(pwd)
DEB_DIR="${WORK_DIR}/debian_package"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root (use sudo)"
        exit 1
    fi
}

# Verificar dependencias necesarias
check_dependencies() {
    log_info "Verificando dependencias..."
    
    local missing_deps=()
    
    # Paquetes necesarios para compilación
    for pkg in make gcc linux-headers-$(uname -r) dkms devscripts build-essential fakeroot; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            missing_deps+=("$pkg")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_info "Instalando dependencias faltantes: ${missing_deps[*]}"
        apt-get update -qq
        apt-get install -y -qq "${missing_deps[@]}" || {
            log_error "No se pudieron instalar las dependencias"
            exit 1
        }
    else
        log_info "Todas las dependencias están instaladas"
    fi
}

# Limpiar directorios temporales
cleanup() {
    log_info "Limpiando directorios temporales..."
    rm -rf "${DEB_DIR}"
    rm -f "${WORK_DIR}"/*.ko
    rm -f "${WORK_DIR}"/*.o
    rm -f "${WORK_DIR}"/*.mod.c
    rm -f "${WORK_DIR}"/*.mod
    rm -f "${WORK_DIR}"/*.order
    rm -f "${WORK_DIR}"/*.symvers
    rm -f "${WORK_DIR}"/*.ur-safe
    rm -rf "${WORK_DIR}"/.tmp_versions
    rm -rf "${WORK_DIR}"/Module.symvers
}

# Compilar el driver
compile_driver() {
    log_info "Compilando el driver..."
    
    cd "${WORK_DIR}"
    
    # Verificar headers del kernel
    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        log_error "Headers del kernel no encontrados. Instale linux-headers-$(uname -r)"
        exit 1
    fi
    
    make clean 2>/dev/null || true
    make
    
    # Verificar que se crearon los módulos
    if [ ! -f "${WORK_DIR}/fl2000.ko" ] || [ ! -f "${WORK_DIR}/it66121.ko" ]; then
        log_error "La compilación falló. No se encontraron los módulos .ko"
        exit 1
    fi
    
    log_info "Driver compilado exitosamente"
}

# Crear estructura del paquete DEB
create_deb_structure() {
    log_info "Creando estructura del paquete DEB..."
    
    # Directorio principal del paquete
    mkdir -p "${DEB_DIR}"
    mkdir -p "${DEB_DIR}/DEBIAN"
    mkdir -p "${DEB_DIR}/usr/src/${DRIVER_NAME}-${DRIVER_VERSION}"
    mkdir -p "${DEB_DIR}/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/fl2000"
    mkdir -p "${DEB_DIR}/etc/modprobe.d"
    mkdir -p "${DEB_DIR}/etc/udev/rules.d"
    
    # Copiar archivos del driver al directorio DKMS
    cp -r "${WORK_DIR}"/* "${DEB_DIR}/usr/src/${DRIVER_NAME}-${DRIVER_VERSION}/" 2>/dev/null || true
    
    # Copiar módulos compilados
    cp "${WORK_DIR}/fl2000.ko" "${DEB_DIR}/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/fl2000/"
    cp "${WORK_DIR}/it66121.ko" "${DEB_DIR}/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/fl2000/"
    
    # Crear archivo de control del paquete DEB
    cat > "${DEB_DIR}/DEBIAN/control" << EOF
Package: ${DRIVER_NAME}
Version: ${DRIVER_VERSION}
Section: misc
Priority: optional
Architecture: amd64
Depends: dkms, linux-headers-$(uname -r), linux-image-$(uname -r)
Maintainer: FL2000 Driver Team
Description: FL2000DX/IT66121FN USB-to-HDMI DRM Driver
 Este paquete contiene el driver DKMS para adaptadores USB-to-HDMI
 basados en los chips FrescoLogic FL2000DX e ITE Tech IT66121FN.
EOF

    # Crear script postinst
    cat > "${DEB_DIR}/DEBIAN/postinst" << 'POSTINST_EOF'
#!/bin/bash
set -e

DRIVER_NAME="fl2000-dkms"
DRIVER_VERSION="1.0.0"

echo "Configurando el driver FL2000..."

# Registrar con DKMS si está disponible
if command -v dkms &> /dev/null; then
    if [ ! -d "/var/lib/dkms/${DRIVER_NAME}/${DRIVER_VERSION}" ]; then
        echo "Registrando módulo con DKMS..."
        dkms add -m ${DRIVER_NAME} -v ${DRIVER_VERSION} || true
    fi
    
    echo "Construyendo módulo DKMS..."
    dkms build -m ${DRIVER_NAME} -v ${DRIVER_VERSION} || true
    dkms install -m ${DRIVER_NAME} -v ${DRIVER_VERSION} || true
fi

# Actualizar dependencias de módulos
echo "Actualizando dependencias de módulos..."
depmod -a $(uname -r)

# Cargar módulos automáticamente al inicio
if [ ! -f "/etc/modules-load.d/fl2000.conf" ]; then
    echo "Creando configuración de carga automática..."
    echo "fl2000" > /etc/modules-load.d/fl2000.conf
    echo "it66121" >> /etc/modules-load.d/fl2000.conf
fi

# Crear reglas udev para el dispositivo
cat > /etc/udev/rules.d/99-fl2000.rules << 'UDEV_EOF'
# Reglas para FL2000 USB-to-HDMI
SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", ATTR{idProduct}=="*", MODE="0666"
UDEV_EOF

echo "Recargando reglas udev..."
udevadm control --reload-rules || true
udevadm trigger || true

echo "Driver FL2000 configurado exitosamente"
exit 0
POSTINST_EOF

    chmod +x "${DEB_DIR}/DEBIAN/postinst"
    
    # Crear script prerm
    cat > "${DEB_DIR}/DEBIAN/prerm" << 'PRERM_EOF'
#!/bin/bash
set -e

DRIVER_NAME="fl2000-dkms"
DRIVER_VERSION="1.0.0"

echo "Eliminando el driver FL2000..."

# Detener módulos si están cargados
rmmod it66121 2>/dev/null || true
rmmod fl2000 2>/dev/null || true

# Eliminar de DKMS
if command -v dkms &> /dev/null; then
    dkms remove -m ${DRIVER_NAME} -v ${DRIVER_VERSION} --all || true
fi

echo "Driver FL2000 eliminado"
exit 0
PRERM_EOF

    chmod +x "${DEB_DIR}/DEBIAN/prerm"
    
    # Crear archivo dkms.conf para soporte DKMS
    cat > "${DEB_DIR}/usr/src/${DRIVER_NAME}-${DRIVER_VERSION}/dkms.conf" << EOF
PACKAGE_NAME="${DRIVER_NAME}"
PACKAGE_VERSION="${DRIVER_VERSION}"
MAKE[0]="make -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build modules"
CLEAN="make -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build clean"
BUILT_MODULE_NAME[0]="fl2000"
BUILT_MODULE_NAME[1]="it66121"
DEST_MODULE_LOCATION[0]="/kernel/drivers/gpu/drm/fl2000"
DEST_MODULE_LOCATION[1]="/kernel/drivers/gpu/drm/fl2000"
AUTOINSTALL="yes"
EOF

    log_info "Estructura del paquete creada exitosamente"
}

# Construir el paquete .deb
build_deb() {
    log_info "Construyendo paquete .deb..."
    
    cd "${DEB_DIR}"
    
    # Calcular tamaño del paquete instalado
    du -sk "${DEB_DIR}" | awk '{print $1}' > "${DEB_DIR}/DEBIAN/installed-size"
    
    # Construir el paquete
    fakeroot dpkg-deb --build . ../${DRIVER_NAME}_${DRIVER_VERSION}_amd64.deb
    
    if [ ! -f "${WORK_DIR}/${DRIVER_NAME}_${DRIVER_VERSION}_amd64.deb" ]; then
        log_error "Falló la creación del paquete .deb"
        exit 1
    fi
    
    log_info "Paquete .deb creado: ${DRIVER_NAME}_${DRIVER_VERSION}_amd64.deb"
}

# Instalar el paquete .deb
install_deb() {
    log_info "Instalando paquete .deb..."
    
    dpkg -i "${WORK_DIR}/${DRIVER_NAME}_${DRIVER_VERSION}_amd64.deb" || {
        log_warn "Error durante la instalación, intentando corregir..."
        apt-get install -f -y
    }
    
    log_info "Paquete instalado exitosamente"
}

# Cargar los módulos del driver
load_modules() {
    log_info "Cargando módulos del driver..."
    
    # Cargar dependencias primero
    modprobe drm || true
    modprobe drm_kms_helper || true
    
    # Cargar módulos del driver
    if ! lsmod | grep -q "fl2000"; then
        insmod "${WORK_DIR}/fl2000.ko" || {
            log_warn "No se pudo cargar fl2000.ko"
        }
    fi
    
    if ! lsmod | grep -q "it66121"; then
        insmod "${WORK_DIR}/it66121.ko" || {
            log_warn "No se pudo cargar it66121.ko"
        }
    fi
    
    # Verificar módulos cargados
    if lsmod | grep -q "fl2000" && lsmod | grep -q "it66121"; then
        log_info "Módulos cargados exitosamente"
        echo ""
        echo "Módulos cargados:"
        lsmod | grep -E "fl2000|it66121"
    else
        log_warn "Algunos módulos no se cargaron. Puede requerir reinicio."
    fi
}

# Mostrar información de uso
show_usage() {
    echo ""
    echo "========================================"
    echo "  Instalación del Driver FL2000 Completada"
    echo "========================================"
    echo ""
    echo "El driver ha sido compilado e instalado correctamente."
    echo ""
    echo "Paquete creado: ${DRIVER_NAME}_${DRIVER_VERSION}_amd64.deb"
    echo ""
    echo "Para verificar que el driver está funcionando:"
    echo "  lsmod | grep -E 'fl2000|it66121'"
    echo ""
    echo "Para ver los dispositivos detectados:"
    echo "  dmesg | grep -i fl2000"
    echo ""
    echo "Si necesita firmar los módulos para Secure Boot:"
    echo "  ./scripts/sign.sh"
    echo ""
    echo "========================================"
}

# Función principal
main() {
    echo "========================================"
    echo "  Script de Instalación FL2000 Driver"
    echo "========================================"
    echo ""
    
    check_root
    check_dependencies
    cleanup
    compile_driver
    create_deb_structure
    build_deb
    install_deb
    load_modules
    show_usage
}

# Manejo de errores
trap 'log_error "Error en línea $LINENO. Saliendo..."; exit 1' ERR

# Ejecutar función principal
main "$@"
