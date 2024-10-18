# WinChipHead (沁恒) CH341 linux drivers for I2C / SPI and GPIO mode
# By Frank-zago https://github.com/frank-zago/ch341-i2c-spi-gpio/blob/master/README.rst

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

# Указываем имя пакета, его версию и релиз
PKG_NAME:=gpio-ch341
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

# Указываем информацию о поддержке и лицензии
PKG_MAINTAINER:=Frank Zago <https://github.com/frank-zago/ch341-i2c-spi-gpio>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

# Определяем пакет gpio-ch341
define KernelPackage/gpio-ch341
  SUBMENU:=Other modules
  TITLE:=CH341 linux drivers for I2C / SPI and GPIO mode.  # Название пакета
  # Зависимости: пакет требует librt
  #DEPENDS:= @GPIO_SUPPORT
  URL:=https://github.com/frank-zago/ch341-i2c-spi-gpio/blob/master/README.rst   # URL для информации
  FILES:=$(PKG_BUILD_DIR)/gpio-ch341.ko
endef

# Описание пакета
define KernelPackage/example2/description
  The driver provides support for GPIO/I2C/SPI. 
endef

# Конфигурация пакета
#define Package/gpio-ch341/config
#  source "$(SOURCE)/Config.in"  # Подключаем файл конфигурации для параметров сборки
#endef

# Определяем этап подготовки сборки
#define Build/Prepare
#  mkdir -p $(PKG_BUILD_DIR)      # Создаем директорию для сборки пакета
#  $(CP) ./src/* $(PKG_BUILD_DIR)/ # Копируем исходные файлы в директорию сборки
#endef

# Определяем этап конфигурации сборки (ничего не делаем)
#define Build/Configure
# Nothing to do here for us.
# By default gpio-ch341/src/Makefile will be used.
#endef

# Определяем этап компиляции пакета
define Build/Compile
  $(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" modules
endef

# Определяем этап установки пакета
#define Package/example2/install
  #$(INSTALL_DIR) $(1)/usr/sbin   # Создаем директорию для установки пакета
  #$(INSTALL_BIN) $(PKG_BUILD_DIR)/example2 $(1)/usr/sbin/ # Устанавливаем бинарный файл в нужное место
#endef

# Вызов функции для сборки пакета
$(eval $(call KernelPackage,gpio-ch341))
