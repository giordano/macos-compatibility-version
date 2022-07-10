MACOSX_VERSION_MIN := 10.10

CFLAGS = -mmacosx-version-min=$(MACOSX_VERSION_MIN)

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
	cc $(CFLAGS) -shared -o libfoo.0.dylib $^ -current_version 36.0.0 -compatibility_version 36.0.0
	ln -sf libfoo.0.dylib $@

relibfoo.dylib: foo.c
	cc $(CFLAGS) -shared -o libfoo.0.dylib $^ -current_version 35.0.0 -compatibility_version 35.0.0
	ln -sf libfoo.0.dylib libfoo.dylib

clean:
	rm -f main libfoo.dylib libfoo.0.dylib
