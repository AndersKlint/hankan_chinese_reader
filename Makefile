APP_ID := com.andersklint.hankan_chinese_reader
MANIFEST := flatpak/$(APP_ID).yml
BUNDLE := hankan_chinese_reader.flatpak

.PHONY: flatpak clean

flatpak:
	flutter build linux --release
	flatpak-builder --repo=repo build-dir $(MANIFEST) --force-clean
	flatpak build-bundle repo $(BUNDLE) $(APP_ID)
	flatpak install $(BUNDLE)

clean:
	rm -rf build-dir repo .flatpak-builder $(BUNDLE)
