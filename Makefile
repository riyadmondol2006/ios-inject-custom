# Detect OS
UNAME_S := $(shell uname -s)
host_arch := arm64

# Frida version
frida_version := 17.1.5

# Common flags
COMMON_CFLAGS := -Wall -pipe -Os

ifeq ($(UNAME_S),Darwin)
    # macOS Configuration
    CC := $(shell xcrun --sdk iphoneos -f clang 2>/dev/null || echo clang) -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || echo /) -miphoneos-version-min=14.0
    CFLAGS := $(COMMON_CFLAGS) -fmodules -fobjc-arc
    LDFLAGS := -Wl,-dead_strip
    STRIP := $(shell xcrun --sdk iphoneos -f strip 2>/dev/null || echo strip) -Sx
    CODESIGN := $(shell xcrun --sdk iphoneos -f codesign 2>/dev/null || echo codesign) -f -s -
    LIPO := $(shell xcrun --sdk iphoneos -f lipo 2>/dev/null || echo lipo)
    INSTALL_NAME_TOOL := $(shell xcrun --sdk iphoneos -f install_name_tool 2>/dev/null || echo install_name_tool)
else
    # Linux Configuration - Creates mock binaries that compile
    CC := clang
    CFLAGS := $(COMMON_CFLAGS) -DLINUX_BUILD
    LDFLAGS := -Wl,--gc-sections  # Linux equivalent of -dead_strip
    STRIP := strip
    CODESIGN := echo "Skipping codesign on Linux for"
    LIPO := echo "Skipping lipo on Linux for"
    INSTALL_NAME_TOOL := echo "Skipping install_name_tool on Linux for"
endif

# Swift runtime paths (for macOS builds)
SWIFT_RPATH_FLAGS := -Xlinker -rpath -Xlinker /usr/lib/swift \
                     -Xlinker -rpath -Xlinker @executable_path/Frameworks \
                     -Xlinker -rpath -Xlinker @loader_path/Frameworks

all: bin/inject bin/agent.dylib bin/victim

clean:
	$(RM) -r bin/ obj/

# Platform-specific binary creation
ifeq ($(UNAME_S),Darwin)
bin/inject: obj/arm64/inject obj/arm64e/inject
	@mkdir -p $(@D)
	$(LIPO) $^ -create -output $@
	$(CODESIGN) --entitlements inject.xcent --deep $@

bin/agent.dylib: obj/arm64/agent.dylib obj/arm64e/agent.dylib
	@mkdir -p $(@D)
	$(LIPO) $^ -create -output $@
	@for lib in $$(otool -L $@ 2>/dev/null | grep '@rpath/libswift' | awk '{print $$1}'); do \
		libname=$$(basename $$lib); \
		echo "Fixing $$lib -> /usr/lib/swift/$$libname"; \
		$(INSTALL_NAME_TOOL) -change "$$lib" "/usr/lib/swift/$$libname" $@ || true; \
	done
	$(CODESIGN) $@

bin/victim: obj/arm64/victim obj/arm64e/victim
	@mkdir -p $(@D)
	$(LIPO) $^ -create -output $@
	$(CODESIGN) $@
else
# Linux builds - single architecture
bin/inject: obj/$(host_arch)/inject
	@mkdir -p $(@D)
	cp $< $@
	$(CODESIGN) $@

bin/agent.dylib: obj/$(host_arch)/agent.dylib
	@mkdir -p $(@D)
	cp $< $@
	$(CODESIGN) $@

bin/victim: obj/$(host_arch)/victim
	@mkdir -p $(@D)
	cp $< $@
	$(CODESIGN) $@
endif

# Compilation rules
obj/%/inject: inject.c obj/%/frida-core/.stamp
	@mkdir -p $(@D)
ifeq ($(UNAME_S),Darwin)
	$(CC) -arch $* $(CFLAGS) -I$(@D)/frida-core inject.c -o $@ \
		-L$(@D)/frida-core -lfrida-core \
		-Wl,-framework,Foundation,-framework,UIKit,-framework,Security \
		-lresolv -lc++ $(LDFLAGS)
else
	$(CC) $(CFLAGS) -I$(@D)/frida-core inject.c -o $@ \
		-L$(@D)/frida-core -lfrida-core \
		-lresolv -lpthread -ldl $(LDFLAGS) || \
	$(CC) $(CFLAGS) -DMOCK_BUILD inject.c -o $@ -lpthread -ldl $(LDFLAGS)
endif
	$(STRIP) $@ 2>/dev/null || true

obj/%/agent.dylib: agent.c obj/%/frida-gum/.stamp
	@mkdir -p $(@D)
ifeq ($(UNAME_S),Darwin)
	$(CC) -arch $* -shared -Wl,-exported_symbol,_example_agent_main \
		$(CFLAGS) $(SWIFT_RPATH_FLAGS) \
		-I$(@D)/frida-gum agent.c -o $@ \
		-L$(@D)/frida-gum -lfrida-gum -ldl -lc++ $(LDFLAGS)
else
	$(CC) -shared -fPIC $(CFLAGS) -I$(@D)/frida-gum agent.c -o $@ \
		-L$(@D)/frida-gum -lfrida-gum -ldl $(LDFLAGS) || \
	$(CC) -shared -fPIC $(CFLAGS) -DMOCK_BUILD agent.c -o $@ -ldl $(LDFLAGS)
endif
	$(STRIP) $@ 2>/dev/null || true

obj/%/victim: victim.c
	@mkdir -p $(@D)
ifeq ($(UNAME_S),Darwin)
	$(CC) -arch $* $(CFLAGS) victim.c -o $@ $(LDFLAGS)
else
	$(CC) $(CFLAGS) victim.c -o $@ $(LDFLAGS)
endif
	$(STRIP) $@ 2>/dev/null || true

# Frida SDK download
obj/%/frida-core/.stamp:
	@mkdir -p $(@D)
	@$(RM) $(@D)/*
	@echo "Downloading frida-core $(frida_version) for $*..."
	@curl -Ls https://github.com/frida/frida/releases/download/$(frida_version)/frida-core-devkit-$(frida_version)-ios-$*.tar.xz | xz -d | tar -C $(@D) -xf - 2>/dev/null || \
		echo "Note: Frida iOS SDK download expected to fail on Linux. Using mock build."
	@touch $@

obj/%/frida-gum/.stamp:
	@mkdir -p $(@D)
	@$(RM) $(@D)/*
	@echo "Downloading frida-gum $(frida_version) for $*..."
	@curl -Ls https://github.com/frida/frida/releases/download/$(frida_version)/frida-gum-devkit-$(frida_version)-ios-$*.tar.xz | xz -d | tar -C $(@D) -xf - 2>/dev/null || \
		echo "Note: Frida iOS SDK download expected to fail on Linux. Using mock build."
	@touch $@

# Build only for current architecture on Linux
ifeq ($(UNAME_S),Linux)
obj/arm64e/%.stamp:
	@mkdir -p $(@D)
	@touch $@

obj/arm64e/%: 
	@echo "Skipping arm64e build on Linux"
	@mkdir -p $(@D)
	@touch $@
endif

.PHONY: all clean
.PRECIOUS: obj/%/frida-core/.stamp obj/%/frida-gum/.stamp
