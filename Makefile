APP_NAME  = ASRInput
BUNDLE    = $(APP_NAME).app
BUILD_DIR = .build/release
BIN       = $(BUILD_DIR)/$(APP_NAME)
CONTENTS  = $(BUNDLE)/Contents
RESOURCES = $(CONTENTS)/Resources
ICON_DIR  = $(BUILD_DIR)/AppIcon.iconset
ICNS      = $(BUILD_DIR)/AppIcon.icns
ICON_SRC  = Sources/ASRInput/Resources/AppIconSource.png
DMG       = .build/$(APP_NAME).dmg
DMG_DIR   = .build/dmg

.PHONY: all build icon bundle dmg run install clean

all: bundle

build:
	swift build -c release 2>&1

icon: $(ICNS)

$(ICNS): scripts/make_icon.swift $(ICON_SRC)
	@echo "=== Generating app icon ==="
	@mkdir -p $(BUILD_DIR)
	swift scripts/make_icon.swift $(BUILD_DIR)/icon_1024.png
	@mkdir -p $(ICON_DIR)
	sips -z 16   16   $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_16x16.png    2>/dev/null
	sips -z 32   32   $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_16x16@2x.png 2>/dev/null
	sips -z 32   32   $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_32x32.png    2>/dev/null
	sips -z 64   64   $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_32x32@2x.png 2>/dev/null
	sips -z 128  128  $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_128x128.png  2>/dev/null
	sips -z 256  256  $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_128x128@2x.png 2>/dev/null
	sips -z 256  256  $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_256x256.png  2>/dev/null
	sips -z 512  512  $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_256x256@2x.png 2>/dev/null
	sips -z 512  512  $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_512x512.png  2>/dev/null
	sips -z 1024 1024 $(BUILD_DIR)/icon_1024.png --out $(ICON_DIR)/icon_512x512@2x.png 2>/dev/null
	iconutil -c icns $(ICON_DIR) -o $(ICNS)
	@echo "=== Icon generated: $(ICNS) ==="

bundle: build icon
	@echo "=== Creating app bundle ==="
	@rm -rf $(BUNDLE)
	@mkdir -p $(CONTENTS)/MacOS $(RESOURCES)
	@cp $(BIN) $(CONTENTS)/MacOS/$(APP_NAME)
	@cp Sources/ASRInput/Resources/Info.plist $(CONTENTS)/Info.plist
	@cp $(ICNS) $(RESOURCES)/AppIcon.icns
	codesign --sign - --force --deep $(BUNDLE)
	@echo "=== Bundle ready: $(BUNDLE) ==="

dmg: bundle
	@echo "=== Creating DMG ==="
	@rm -rf $(DMG_DIR) $(DMG)
	@mkdir -p $(DMG_DIR)
	@cp -R $(BUNDLE) $(DMG_DIR)/
	@ln -s /Applications $(DMG_DIR)/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(DMG_DIR) -ov -format UDZO $(DMG)
	@echo "=== DMG ready: $(DMG) ==="

run: bundle
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.3
	open "$(CURDIR)/$(BUNDLE)"

install: bundle
	@cp -R $(BUNDLE) /Applications/
	@echo "=== Installed to /Applications/$(BUNDLE) ==="

clean:
	swift package clean
	@rm -rf $(BUNDLE) $(BUILD_DIR) $(DMG)
