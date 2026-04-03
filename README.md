[![Gitter](https://badges.gitter.im/fl2000_drm/community.svg)](https://gitter.im/fl2000_drm/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
[![Build](https://github.com/klogg/fl2000_drm/actions/workflows/makefile.yml/badge.svg)](https://github.com/klogg/fl2000_drm/actions/workflows/makefile.yml)
[![Stylecheck](https://github.com/klogg/fl2000_drm/actions/workflows/codingstyle.yaml/badge.svg)](https://github.com/klogg/fl2000_drm/actions/workflows/codingstyle.yaml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=klogg_fl2000_drm&metric=alert_status)](https://sonarcloud.io/dashboard?id=klogg_fl2000_drm)

# Linux kernel FL2000DX/IT66121FN dongle DRM driver

Clean re-implementation of FrescoLogic FL2000DX DRM driver and ITE Tech IT66121F driver, allowing to enable full display controller capabilities for [USB-to-HDMI dongles](https://www.aliexpress.com/item/32821739801.html?spm=a2g0o.productlist.0.0.14ee52fb8rFfu5) based on such chips in Linux

### Building driver

Check out the code and type
```
make
```
Use
```
insmod fl2000.ko && insmod it66121.ko
```
with sudo or in root shell to start the driver. If you are running on a system with secure boot enabled, you may need to sign kernel modules. Try using provided script for this:
```
./scritps/sign.sh
```
ensure that DRM components are loaded in your system, if not - please use
```
modprobe drm
modprobe drm_kms_helper
```
**NOTE:** proper kernel headers and build tools (e.g. "build-essential" package) must be installed on the system. Driver is developed and tested on Ubuntu 22.04 with **Linux kernel 6.5.0**, so better to test it this way. Please use gcc-8 or newer to build the driver

For more information check project's [Wiki](https://github.com/klogg/fl2000_drm/wiki)

---

## Instalador Automatizado

Este repositorio incluye un script de instalación automatizada (`install-driver.sh`) que simplifica el proceso de compilación, empaquetado e instalación del driver FL2000/IT66121.

### Características del Instalador

- ✅ Verificación automática de dependencias
- ✅ Compilación del driver para tu kernel actual
- ✅ Creación de paquete `.deb` para fácil instalación/desinstalación
- ✅ Integración con DKMS para reconstrucción automática tras actualizaciones del kernel
- ✅ Configuración de carga automática de módulos
- ✅ Creación de reglas udev para detección de dispositivos
- ✅ Limpieza de archivos temporales

### Requisitos Previos

- **Sistema Operativo**: Ubuntu 22.04+, Pop!_OS 22.04+, o distribuciones basadas en Debian/Ubuntu
- **Kernel**: Linux 6.5.0 o superior recomendado
- **Permisos**: Ejecución con `sudo` (requiere privilegios de root)
- **Espacio en disco**: ~50MB libres

### Compatibilidad con Pop!_OS 24.04 LTS

El instalador es **compatible con Pop!_OS 24.04 LTS**, pero existen consideraciones importantes:

#### ⚠️ Problemas Potenciales y Soluciones

1. **Headers del Kernel**
   
   Pop!_OS 24.04 LTS está basado en Ubuntu 24.04 Noble Numbat y utiliza kernels más recientes (6.8+).
   
   **Problema**: Los headers deben coincidir exactamente con la versión del kernel en ejecución.
   
   **Solución**:
   ```bash
   # Verificar versión del kernel
   uname -r
   
   # Instalar headers específicos para tu kernel
   sudo apt update
   sudo apt install linux-headers-$(uname -r)
   ```

2. **Secure Boot**
   
   Pop!_OS tiene Secure Boot habilitado por defecto en algunas instalaciones.
   
   **Problema**: Los módulos del kernel deben estar firmados para cargarse con Secure Boot activo.
   
   **Solución**:
   ```bash
   # Opción A: Usar el script de firmado incluido
   sudo ./scripts/sign.sh
   
   # Opción B: Deshabilitar Secure Boot desde la BIOS/UEFI
   # (Recomendado solo para sistemas de desarrollo/prueba)
   ```

3. **GCC Version**
   
   Pop!_OS 24.04 incluye GCC 13.x por defecto.
   
   **Problema**: El driver fue desarrollado con GCC 8+, pero versiones muy recientes pueden mostrar warnings diferentes.
   
   **Solución**: El instalador detecta y usa el GCC disponible. No se requiere acción adicional.

4. **DKMS y Actualizaciones del Kernel**
   
   **Problema**: Tras una actualización del kernel, los módulos deben recompilarse.
   
   **Solución**: El paquete `.deb` creado incluye configuración DKMS que automáticamente reconstruye los módulos cuando se instala un nuevo kernel.

5. **Dependencias de DRM**
   
   **Problema**: Las versiones recientes del kernel pueden tener cambios en las APIs de DRM.
   
   **Solución**: 
   ```bash
   # Cargar manualmente las dependencias si es necesario
   sudo modprobe drm
   sudo modprobe drm_kms_helper
   sudo modprobe drm_kms_fb_helper
   ```

### Uso del Instalador

#### Instalación Básica

```bash
# Clonar el repositorio (si no lo has hecho)
git clone <url-del-repositorio>
cd fl2000_drm

# Hacer ejecutable el script
chmod +x install-driver.sh

# Ejecutar el instalador
sudo ./install-driver.sh
```

#### Verificación Post-Instalación

```bash
# Verificar que los módulos están cargados
lsmod | grep -E 'fl2000|it66121'

# Ver mensajes del kernel sobre el driver
dmesg | grep -i fl2000

# Ver dispositivos USB detectados
lsusb | grep -i fresco
```

#### Desinstalación

```bash
# Usando el gestor de paquetes
sudo dpkg -r fl2000-dkms

# O eliminar completamente
sudo apt remove fl2000-dkms
```

### Solución de Problemas para Pop!_OS 24.04

#### Error: "Headers del kernel no encontrados"

```bash
# Actualizar lista de paquetes
sudo apt update

# Instalar headers genéricos (pop!_os usa kernel personalizado)
sudo apt install linux-headers-generic

# Si usas kernel específico de Pop!_OS
sudo apt install linux-headers-$(uname -r)
```

#### Error: "Módulo no se carga - Key was rejected by service"

Esto indica que Secure Boot está bloqueando el módulo.

```bash
# Verificar estado de Secure Boot
mokutil --sb-state

# Firmar módulos manualmente
sudo ./scripts/sign.sh

# O seguir el proceso de inscripción de claves MOK
sudo mokutil --import /path/to/public_key.der
# Reiniciar y seguir instrucciones en pantalla
```

#### Error: "Unknown symbol in module"

Indica dependencias faltantes o incompatibilidad de versión del kernel.

```bash
# Recargar dependencias de módulos
sudo depmod -a

# Verificar símbolos desconocidos
modinfo fl2000.ko
```

#### El adaptador no es detectado

```bash
# Verificar que el dispositivo USB es reconocido
lsusb -v | grep -A 20 "Fresco Logic"

# Forzar carga de módulos
sudo modprobe fl2000
sudo modprobe it66121

# Ver logs del sistema
journalctl -f | grep -i fl2000
```

### Estructura del Paquete Generado

El instalador crea un paquete DEB con la siguiente estructura:

```
fl2000-dkms_1.0.0_amd64.deb
├── DEBIAN/
│   ├── control          # Metadatos del paquete
│   ├── postinst         # Script post-instalación
│   └── prerm            # Script pre-eliminación
├── usr/src/fl2000-dkms-1.0.0/  # Fuentes para DKMS
├── lib/modules/.../kernel/drivers/gpu/drm/fl2000/  # Módulos compilados
├── etc/modprobe.d/      # Configuración de módulos
└── etc/udev/rules.d/    # Reglas de dispositivos
```

### Notas Importantes para Pop!_OS 24.04 LTS

1. **Kernel Personalizado**: Pop!_OS utiliza kernels con parches específicos. Asegúrate de usar los headers correctos.

2. **Gestión de Energía**: Pop!_OS tiene características avanzadas de gestión de energía que pueden afectar dispositivos USB. Si experimentas problemas de estabilidad:
   ```bash
   # Deshabilitar suspensión selectiva de USB
   sudo sh -c 'echo -1 > /sys/module/usbcore/parameters/autosuspend'
   ```

3. **Wayland vs X11**: Pop!_OS 24.04 usa Wayland por defecto. El driver funciona en ambos, pero si tienes problemas:
   - Cambia a sesión X11 desde la pantalla de login
   - O reporta el problema para soporte Wayland específico

4. **Actualizaciones del Sistema**: Después de actualizar Pop!_OS, ejecuta:
   ```bash
   sudo dkms autoinstall
   ```
   Para asegurar que los módulos estén disponibles para el nuevo kernel.

### Contribuciones

Si encuentras problemas específicos de Pop!_OS 24.04 LTS, por favor reporta el issue incluyendo:
- Versión exacta de Pop!_OS
- Versión del kernel (`uname -r`)
- Salida de `dmesg | grep -i fl2000`
- Modelo del adaptador USB-to-HDMI

### Enlaces Útiles

- [Wiki del Proyecto](https://github.com/klogg/fl2000_drm/wiki)
- [Comunidad Gitter](https://gitter.im/fl2000_drm/community)
- [Documentación DKMS](https://github.com/dell/dkms)
- [Foros de Pop!_OS](https://forum.pop-os.org/)
