MACOSX_VERSION_MIN := 10.10

CFLAGS = -mmacosx-version-min=$(MACOSX_VERSION_MIN)

.PHONY: relibfoo.dylib runmain clean

runmain: main relibfoo.dylib
	sw_vers
	otool -L $<
	otool -L libbar.dylib
	otool -L libfoo.dylib
	./$<

main: main.c libbar.dylib
	cc $(CFLAGS) -o $@ $< -L. -lbar
	install_name_tool -change libbar.dylib @rpath/libbar.dylib $@
	install_name_tool -add_rpath ${PWD} $@

libbar.dylib: bar.c libfoo.dylib
	cc $(CFLAGS) -shared -o $@ $^ -L. -lfoo
	install_name_tool -change libfoo.dylib @rpath/libfoo.dylib $@
	install_name_tool -add_rpath ${PWD} $@

libfoo.dylib: foo.c
	cc $(CFLAGS) -shared -o libfoo.0.dylib $^ -current_version 36.0.0 -compatibility_version 36.0.0
	ln -sf libfoo.0.dylib $@

relibfoo.dylib: foo.c
	cc $(CFLAGS) -shared -o libfoo.0.dylib $^ -current_version 35.0.0 -compatibility_version 35.0.0
	ln -sf libfoo.0.dylib libfoo.dylib

clean:
	rm -f main libfoo.dylib libfoo.0.dylib libbar.dylib
