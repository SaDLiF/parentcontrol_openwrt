include $(TOPDIR)/rules.mk

PKG_NAME:=parentcontrol
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=SaDLiF
PKG_LICENSE:=GPL-2.0+

include $(INCLUDE_DIR)/package.mk

define Package/parentcontrol
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Parental Control
  DEPENDS:=+libc
  PKGARCH:=all
endef

define Package/parentcontrol/description
  A parental control module for OpenWRT
endef

define Build/Compile
  # Nothing to compile - files are pre-built
endef

define Package/parentcontrol/install
	$(INSTALL_DIR) $(1)
	$(CP) ./files/* $(1)/
endef

define Package/parentcontrol/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Setting up Parental Control..."
    
    # Make scripts executable
    [ -f /usr/sbin/parentalcontrol ] && chmod 755 /usr/sbin/parentalcontrol
    [ -f /usr/bin/parentalcontrol-apply ] && chmod 755 /usr/bin/parentalcontrol-apply
    [ -f /etc/init.d/parentalcontrol-watch ] && chmod 755 /etc/init.d/parentalcontrol-watch
    
    # Set config permissions
    [ -f /etc/config/parentalcontrol ] && chmod 644 /etc/config/parentalcontrol
    
    # Add cron job
    if [ -f /usr/bin/parentalcontrol-apply ]; then
        echo "Adding cron job for parentalcontrol-apply..."
        (crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply"; echo "* * * * * /usr/bin/parentalcontrol-apply") | crontab -
    fi
    
    # Enable and start watch service
    [ -f /etc/init.d/parentalcontrol-watch ] && {
        /etc/init.d/parentalcontrol-watch enable
        /etc/init.d/parentalcontrol-watch start
    }
    
    # Restart LuCI
    echo "Restarting LuCI..."
    /etc/init.d/uhttpd restart 2>/dev/null || true
    /etc/init.d/rpcd restart 2>/dev/null || true
    
    echo "Parental Control installation completed!"
    echo "Cron job: * * * * * /usr/bin/parentalcontrol-apply"
    echo "Service: parentalcontrol-watch (config monitor)"
    echo "LuCI restarted - please refresh browser"
fi
exit 0
endef

define Package/parentcontrol/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    # Remove cron job
    echo "Removing cron job..."
    crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply" | crontab -
    
    # Stop watch service
    [ -f /etc/init.d/parentalcontrol-watch ] && {
        /etc/init.d/parentalcontrol-watch stop
        /etc/init.d/parentalcontrol-watch disable
    }
    
    # Restart LuCI
    /etc/init.d/uhttpd restart 2>/dev/null || true
    /etc/init.d/rpcd restart 2>/dev/null || true
fi
exit 0
endef

$(eval $(call BuildPackage,parentcontrol))
