include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QuickImages
QuickImages_FILES = Tweak.xm
QuickImages_CFLAGS = -fobjc-arc
QuickImages_FRAMEWORKS = UIKit

include $(THEOS)/makefiles/tweak.mk

after-install::
	install.exec "killall -9 MobileSMS"
	# install.exec "killall -9 Preferences"

SUBPROJECTS += Preferences

include $(THEOS_MAKE_PATH)/aggregate.mk
