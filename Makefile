MACOSX_VERSION_MIN := 10.10

CFLAGS = -mmacosx-version-min=$(MACOSX_VERSION_MIN)
COMPATIBILITY_VERSION := 2.0.0

.PHONY: relibfoo.dylib runmain clean

runmain: main relibfoo.dylib
	sw_vers
	otool -L $<
	otool -L libfoo.dylib
	./$<

main: main.c libfoo.dylib
	cc $(CFLAGS) -o $@ $< -L. -lfoo
	install_name_tool -change libfoo.dylib @rpath/libfoo.dylib $@
	install_name_tool -add_rpath ${PWD} $@

libfoo.dylib: foo.c
	cc $(CFLAGS) -shared -o $@ $^ -current_version $(COMPATIBILITY_VERSION) -compatibility_version $(COMPATIBILITY_VERSION)

# Recreate libfoo, but with an older compatibility version number
relibfoo.dylib:
	@$(MAKE) -B libfoo.dylib COMPATIBILITY_VERSION=1.0.0

clean:
	rm -f main libfoo.dylib libfoo.0.dylib
