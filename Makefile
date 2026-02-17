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

install-macos: build-macos
	mv build/macos/Build/Products/Release/PloyS3.app /Applications

build-macos:
	flutter build macos --release --no-tree-shake-icons

.PHONY: update-icon update-splash rename-app reset-flutter-environment install-macos build-macos run

