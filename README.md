# Demonstration of the use of `-compatibility_version` on macOS

Shared libraries in the form of [Mach-O](https://en.wikipedia.org/wiki/Mach-O) object files
for macOS can specify a compatibility version number.  This can be achieved by passing the
`-compatibility_version` option to the linker (usually done through the compiler driver).

Quoting from the man page of `ld`:

```
-compatibility_version number
        Specifies the compatibility version number of the library.  When a library is
        loaded by dyld, the compatibility version is checked and if the program's
        version is greater that the library's version, it is an error.  The format of
        number is X[.Y[.Z]] where X must be a positive non-zero number less than or
        equal to 65535, and .Y and .Z are optional and if present must be non-
        negative numbers less than or equal to 255.  If the compatibility version
        number is not specified, it has a value of 0 and no checking is done when the
        library is used.  This option is also called -dylib_compatibility_version for
        compatibility.
```

The file [`Makefile`](./Makefile) in this
repository shows an example of use:

* a shared library `libfoo.dylib` is built from [`foo.c`](./foo.c), with compatibility version number
  `2.0.0`
* the program `main` is built from [`main.c`](./main.c), linking to `libfoo.dylib`, requiring
  compatibility version number `2.0.0` for this library
* `libfoo.dylib` is built again, but this time with compatibility version number `1.0.0`
* the program `main` is run, after printing to screen some diagnostic messages.

Since `main` requires `libfoo.dylib` with version `2.0.0` and the `libfoo.dylib` shared
library currently available has version number `1.0.0`, this in principle should trigger the
check of the version number, and `main` would not be run because of the incompatible version
number.  However, whether this check is actually run or not depends on:

* what's the minimum compatible macOS version for the library,
* and what's the version macOS you're using.

As pointed out by `Siguza` in [this answer on Stack
Overflow](https://stackoverflow.com/a/67067009/2442087):

> But that is only half the truth. For what's _really_ happening, we have to look at [dyld
> sources](https://opensource.apple.com/source/dyld/dyld-832.7.3/src/ImageLoader.cpp.auto.html):
>
> ```c++
> // check found library version is compatible
> // <rdar://problem/89200806> 0xFFFFFFFF is wildcard that matches any version
> if ( (requiredLibInfo.info.minVersion != 0xFFFFFFFF) && (actualInfo.minVersion < requiredLibInfo.info.minVersion)
>         && ((dyld3::MachOFile*)(dependentLib->machHeader()))->enforceCompatVersion() ) {
>     // record values for possible use by CrashReporter or Finder
>     dyld::throwf("Incompatible library version: %s requires version %d.%d.%d or later, but %s provides version %d.%d.%d",
>             this->getShortName(), requiredLibInfo.info.minVersion >> 16, (requiredLibInfo.info.minVersion >> 8) & 0xff, requiredLibInfo.info.minVersion & 0xff,
>             dependentLib->getShortName(), actualInfo.minVersion >> 16, (actualInfo.minVersion >> 8) & 0xff, actualInfo.minVersion & 0xff);
> }
> ```
>
> Besides the fact that `0xffffffff` can be used as a wildcard, the interesting bit here is
> the call to [`enforceCompatVersion()`](https://opensource.apple.com/source/dyld/dyld-832.7.3/dyld3/MachOFile.cpp.auto.html):
>
> ```c++
> bool MachOFile::enforceCompatVersion() const
> {
>     __block bool result = true;
>     forEachSupportedPlatform(^(Platform platform, uint32_t minOS, uint32_t sdk) {
>         switch ( platform ) {
>             case Platform::macOS:
>                 if ( minOS >= 0x000A0E00 )  // macOS 10.14
>                     result = false;
>                 break;
>             case Platform::iOS:
>             case Platform::tvOS:
>             case Platform::iOS_simulator:
>             case Platform::tvOS_simulator:
>                 if ( minOS >= 0x000C0000 )  // iOS 12.0
>                     result = false;
>                 break;
>             case Platform::watchOS:
>             case Platform::watchOS_simulator:
>                 if ( minOS >= 0x00050000 )  // watchOS 5.0
>                     result = false;
>                 break;
>             case Platform::bridgeOS:
>                 if ( minOS >= 0x00030000 )  // bridgeOS 3.0
>                     result = false;
>                 break;
>             case Platform::driverKit:
>             case Platform::iOSMac:
>                 result = false;
>                 break;
>             case Platform::unknown:
>                 break;
>         }
>     });
>     return result;
> }
> ```
>
> As you can see, if the library declares its minimum supported OS version to be somewhat
> recent, then the compatibility version is outright ignored by dyld.
>
> So if you rely on the compatibility version being enforced at all, you'll want to use an
> option like `--target=arm64-macos10.13` to build your library.

I'll add that another way to set the minimum supported version of macOS is to pass the flag
`-mmacosx-version-min=...` to the compiler.

However, this check was removed altogether in macOS 12. The new source code of `dyld` is
available at <https://github.com/apple-oss-distributions/dyld>.  The above code path [has
been
deleted](https://github.com/apple-oss-distributions/dyld/commit/9a9e3e4cfa7de205d61f4114c9b564e4bab7ef7f#diff-a4220c07a272a49770dacc147307f3b01f83d575c28b52ede7b08cff31cdc63f).
The method `MachOFile::enforceCompatVersion` is still defined but completely unused.  See
the [Apple Open Source](https://opensource.apple.com/releases/) website to find which
version of `dyld` is shipped in each version of macOS.

## Examples of output

### macOS 11.6, `MACOSX_VERSION_MIN`=10.13

```console
$ make MACOSX_VERSION_MIN=10.13
cc -mmacosx-version-min=10.13 -shared -o libfoo.dylib foo.c -current_version 2.0.0 -compatibility_version 2.0.0
cc -mmacosx-version-min=10.13 -o main main.c -L. -lfoo
install_name_tool -change libfoo.dylib @rpath/libfoo.dylib main
install_name_tool -add_rpath /Users/runner/work/macos-compatibility-version/macos-compatibility-version main
cc -mmacosx-version-min=10.13 -shared -o libfoo.dylib foo.c -current_version 1.0.0 -compatibility_version 1.0.0
sw_vers
ProductName:	macOS
ProductVersion:	11.6.6
BuildVersion:	20G624
otool -L main
main:
	@rpath/libfoo.dylib (compatibility version 2.0.0, current version 2.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
otool -L libfoo.dylib
libfoo.dylib:
	libfoo.dylib (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
./main
dyld: Library not loaded: @rpath/libfoo.dylib
  Referenced from: /Users/runner/work/macos-compatibility-version/macos-compatibility-version/./main
  Reason: Incompatible library version: main requires version 2.0.0 or later, but libfoo.dylib provides version 1.0.0
make: *** [runmain]
```

The check is triggered and the program can't be run because of the incompatible version number.

### macOS 11.6, `MACOSX_VERSION_MIN`=10.14

```console
$ make MACOSX_VERSION_MIN=10.14
cc -mmacosx-version-min=10.14 -shared -o libfoo.dylib foo.c -current_version 2.0.0 -compatibility_version 2.0.0
cc -mmacosx-version-min=10.14 -o main main.c -L. -lfoo
install_name_tool -change libfoo.dylib @rpath/libfoo.dylib main
install_name_tool -add_rpath /Users/runner/work/macos-compatibility-version/macos-compatibility-version main
cc -mmacosx-version-min=10.14 -shared -o libfoo.dylib foo.c -current_version 1.0.0 -compatibility_version 1.0.0
sw_vers
ProductName:	macOS
ProductVersion:	11.6.6
BuildVersion:	20G624
otool -L main
main:
	@rpath/libfoo.dylib (compatibility version 2.0.0, current version 2.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
otool -L libfoo.dylib
libfoo.dylib:
	libfoo.dylib (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
./main
Magic number: 42
```

The check is not triggered because the minimum version of macOS required is recent enough
and the program is run normally.

### macOS 12.4, `MACOSX_VERSION_MIN`=10.10

```console
$ make MACOSX_VERSION_MIN=10.10
cc -mmacosx-version-min=10.10 -shared -o libfoo.dylib foo.c -current_version 2.0.0 -compatibility_version 2.0.0
cc -mmacosx-version-min=10.10 -o main main.c -L. -lfoo
install_name_tool -change libfoo.dylib @rpath/libfoo.dylib main
install_name_tool -add_rpath /Users/runner/work/macos-compatibility-version/macos-compatibility-version main
cc -mmacosx-version-min=10.10 -shared -o libfoo.dylib foo.c -current_version 1.0.0 -compatibility_version 1.0.0
sw_vers
ProductName:	macOS
ProductVersion:	12.4
BuildVersion:	21F79
otool -L main
main:
	@rpath/libfoo.dylib (compatibility version 2.0.0, current version 2.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.100.3)
otool -L libfoo.dylib
libfoo.dylib:
	libfoo.dylib (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.100.3)
./main
Magic number: 42
```

The check no longer exists on macOS 12, not even when requesting a relatively old
version of macOS, and so the program is run normally.
