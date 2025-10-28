include $(TOPDIR)/rules.mk

PKG_NAME:=parentcontrol
PKG_VERSION:=1.0.0
PKG_RELEASE:=2

LUCI_TITLE:=Parental Control
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

PKG_LICENSE:=GPL-2.0+
PKG_MAINTAINER:=SaDLiF

LUCI_LANGUAGES:=en ru

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) ./files/* $(1)/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "=== Starting post-installation setup ==="
    
    # Make scripts executable
    [ -f /usr/sbin/parentalcontrol ] && chmod 755 /usr/sbin/parentalcontrol
    [ -f /usr/bin/parentalcontrol-apply ] && chmod 755 /usr/bin/parentalcontrol-apply
    [ -f /etc/init.d/parentalcontrol-watch ] && chmod 755 /etc/init.d/parentalcontrol-watch
    
    # Set config permissions
    [ -f /etc/config/parentalcontrol ] && chmod 644 /etc/config/parentalcontrol
    
    # Add cron job
    if [ -f /usr/bin/parentalcontrol-apply ]; then
        (crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply"; echo "* * * * * /usr/bin/parentalcontrol-apply") | crontab -
    fi
    
    # Enable and start service
    if [ -f /etc/init.d/parentalcontrol-watch ]; then
        /etc/init.d/parentalcontrol-watch enable
        /etc/init.d/parentalcontrol-watch start
    fi
    
    echo "=== Parental Control installation completed! ==="
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))