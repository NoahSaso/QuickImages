include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = QuickImages
QuickImages_FILES = QIRootListController.m
QuickImages_INSTALL_PATH = /Library/PreferenceBundles
QuickImages_FRAMEWORKS = UIKit
QuickImages_PRIVATE_FRAMEWORKS = Preferences
QuickImages_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/QuickImages.plist$(ECHO_END)
