TARGET := iphone:clang:latest:17.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES = Facebook
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FBAudioFix
FBAudioFix_FILES = Tweak.xm
FBAudioFix_FRAMEWORKS = Foundation AVFoundation UIKit
FBAudioFix_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -fno-modules
# Release: make package ADDITIONAL_CFLAGS="-DFB_AUDIOFIX_LOG_ENABLED=0"
# Debug (log file Documents/FBAudioFix-*.txt, cap 256KB): default =1

include $(THEOS_MAKE_PATH)/tweak.mk
