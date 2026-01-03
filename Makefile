update-icon: reset-flutter-environment
	dart run flutter_launcher_icons

update-splash: reset-flutter-environment
	dart run flutter_native_splash:create

rename-app: reset-flutter-environment
	dart run rename_app:main all="Dooli"

reset-flutter-environment:
	flutter clean
	flutter pub get

.PHONY: update-icon update-splash rename-app reset-flutter-environment

