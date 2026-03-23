run:
	flutter run

update-icon: reset-flutter-environment
	dart run flutter_launcher_icons

update-splash: reset-flutter-environment
	dart run flutter_native_splash:create

rename-app: reset-flutter-environment
	dart run rename_app:main all="Dooli"

reset-flutter-environment:
	flutter clean
	flutter pub get

build-cli:
	cd cli && dart pub get && mkdir -p build && dart compile exe bin/ploys3.dart -o build/ploys3

install-cli: build-cli
	cp cli/build/ploys3 /usr/local/bin/ploys3

build-macos:
	flutter build macos --release --no-tree-shake-icons

install-macos: build-macos
	trash /Applications/PloyS3.app || true
	mv build/macos/Build/Products/Release/PloyS3.app /Applications
	@echo ""
	@echo "PloyS3 installed with CLI at:"
	@echo "  /Applications/PloyS3.app/Contents/Resources/bin/ploys3"
	@echo ""
	@echo "To use from terminal, either:"
	@echo "  1. Open PloyS3 > Settings > Install CLI"
	@echo "  2. ln -sf /Applications/PloyS3.app/Contents/Resources/bin/ploys3 /usr/local/bin/ploys3"

.PHONY: update-icon update-splash rename-app reset-flutter-environment install-macos build-macos build-cli install-cli run
