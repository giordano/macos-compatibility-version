.PHONY: relibfoo.dylib runmain clean

runmain: main relibfoo.dylib
	sw_vers
	otool -L $<
	otool -L libfoo.dylib
	./$<

main: main.c libfoo.dylib
	cc -o $@ $< -L. -lfoo

libfoo.dylib: foo.c
	cc -shared -o $@ $^ -current_version 2.0.0 -compatibility_version 2.0

relibfoo.dylib: foo.c
	cc -shared -o libfoo.dylib $^ -current_version 1.0.0 -compatibility_version 1.0

clean:
	rm -f main libfoo.dylib
