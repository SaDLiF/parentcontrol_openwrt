include $(TOPDIR)/rules.mk

PKG_NAME:=parentcontrol
PKG_VERSION:=1.0.0
PKG_RELEASE:=2  # ← Увеличим для нового билда

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
  echo "=== Build/Compile: No compilation needed ==="
endef

define Package/parentcontrol/install
	echo "=== Starting package installation ==="
	echo "Source files directory: $(PWD)/files"
	echo "Target directory: $(1)"
	echo "Files to copy:"
	ls -la ./files/ || echo "No files directory"
	ls -la ./files/etc/ || echo "No etc directory" 
	ls -la ./files/usr/ || echo "No usr directory"
	ls -la ./files/www/ || echo "No www directory"
	
	$(INSTALL_DIR) $(1)
	echo "Copying files from ./files/ to $(1)/..."
	$(CP) ./files/* $(1)/
	
	echo "=== Checking copied files ==="
	echo "Files in target etc/config:"
	ls -la $(1)/etc/config/ || echo "No etc/config"
	echo "Files in target usr/sbin:"
	ls -la $(1)/usr/sbin/ || echo "No usr/sbin"
	echo "Files in target usr/bin:"
	ls -la $(1)/usr/bin/ || echo "No usr/bin"
	echo "Files in target etc/init.d:"
	ls -la $(1)/etc/init.d/ || echo "No etc/init.d"
	
	echo "=== Package installation completed ==="
endef

define Package/parentcontrol/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "=== Starting post-installation setup ==="
    
    echo "Current files in system:"
    echo "/usr/sbin/parentalcontrol: $(ls -la /usr/sbin/parentalcontrol 2>/dev/null || echo 'NOT FOUND')"
    echo "/usr/bin/parentalcontrol-apply: $(ls -la /usr/bin/parentalcontrol-apply 2>/dev/null || echo 'NOT FOUND')"
    echo "/etc/init.d/parentalcontrol-watch: $(ls -la /etc/init.d/parentalcontrol-watch 2>/dev/null || echo 'NOT FOUND')"
    echo "/etc/config/parentalcontrol: $(ls -la /etc/config/parentalcontrol 2>/dev/null || echo 'NOT FOUND')"
    
    echo "Setting up Parental Control..."
    
    # Make scripts executable
    echo "Setting executable permissions..."
    [ -f /usr/sbin/parentalcontrol ] && chmod 755 /usr/sbin/parentalcontrol && echo "Set permissions for /usr/sbin/parentalcontrol"
    [ -f /usr/bin/parentalcontrol-apply ] && chmod 755 /usr/bin/parentalcontrol-apply && echo "Set permissions for /usr/bin/parentalcontrol-apply"
    [ -f /etc/init.d/parentalcontrol-watch ] && chmod 755 /etc/init.d/parentalcontrol-watch && echo "Set permissions for /etc/init.d/parentalcontrol-watch"
    
    # Set config permissions
    [ -f /etc/config/parentalcontrol ] && chmod 644 /etc/config/parentalcontrol && echo "Set permissions for /etc/config/parentalcontrol"
    
    # Add cron job
    if [ -f /usr/bin/parentalcontrol-apply ]; then
        echo "Adding cron job for parentalcontrol-apply..."
        (crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply"; echo "* * * * * /usr/bin/parentalcontrol-apply") | crontab -
        echo "Cron job added: * * * * * /usr/bin/parentalcontrol-apply"
    else
        echo "WARNING: /usr/bin/parentalcontrol-apply not found, skipping cron job"
    fi
    
    # Enable and start watch service
    if [ -f /etc/init.d/parentalcontrol-watch ]; then
        echo "Enabling and starting parentalcontrol-watch service..."
        /etc/init.d/parentalcontrol-watch enable && echo "Service enabled"
        /etc/init.d/parentalcontrol-watch start && echo "Service started"
    else
        echo "ERROR: /etc/init.d/parentalcontrol-watch not found!"
    fi
    
    # Restart LuCI
    echo "Restarting LuCI..."
    /etc/init.d/uhttpd restart 2>/dev/null && echo "uhttpd restarted" || echo "uhttpd restart failed"
    /etc/init.d/rpcd restart 2>/dev/null && echo "rpcd restarted" || echo "rpcd restart failed"
    
    echo "=== Parental Control installation completed! ==="
    echo "Summary:"
    echo "- Cron job: * * * * * /usr/bin/parentalcontrol-apply"
    echo "- Service: parentalcontrol-watch"
    echo "- LuCI: restarted"
    echo "- Please refresh browser"
fi
exit 0
endef

define Package/parentcontrol/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "=== Starting pre-removal cleanup ==="
    
    # Remove cron job
    echo "Removing cron job..."
    crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply" | crontab -
    echo "Cron job removed"
    
    # Stop watch service
    if [ -f /etc/init.d/parentalcontrol-watch ]; then
        echo "Stopping parentalcontrol-watch service..."
        /etc/init.d/parentalcontrol-watch stop && echo "Service stopped"
        /etc/init.d/parentalcontrol-watch disable && echo "Service disabled"
    else
        echo "Service file not found, skipping stop"
    fi
    
    # Restart LuCI
    echo "Restarting LuCI..."
    /etc/init.d/uhttpd restart 2>/dev/null && echo "uhttpd restarted" || echo "uhttpd restart failed"
    /etc/init.d/rpcd restart 2>/dev/null && echo "rpcd restarted" || echo "rpcd restart failed"
    
    echo "=== Pre-removal cleanup completed ==="
fi
exit 0
endef

$(eval $(call BuildPackage,parentcontrol))