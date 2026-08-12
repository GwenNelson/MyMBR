## MyMBR

A small legacy BIOS MBR boot selector, together with a deliberately
thorough test harness for building disk images, installing boot records,
booting them under QEMU, and checking that the surrounding filesystems
have not been damaged.

The test scripts included are intended to answer two questions independently:

1.  **Does the image/PBR tooling work correctly?**\
    A known-good reference MBR is used to boot the generated test PBRs.
    This checks that image generation, filesystem-aware PBR
    installation, active-partition handling, and the QEMU test path are
    sane.

2.  **Does `MyMBR` work correctly?**\
    The project's own MBR is then tested against the same PBRs and
    images. The automated build reads partition choices over an emulated
    serial port, while the normal build retains BIOS keyboard input for
    interactive use and real hardware.

A major goal of the test suite is not merely to prove that something
boots, but to verify the image before and after operations so that
boot-sector manipulation does not silently corrupt filesystem metadata.

## Current bootloader

`my-mbr.asm` is a 16-bit legacy BIOS MBR boot selector.

At boot it:

1.  starts at the BIOS load address `0000:7C00`;
2.  establishes a small real-mode stack;
3.  relocates the complete 512-byte MBR to `0000:0600`;
4.  remembers the BIOS boot drive from `DL`;
5.  queries and displays the BIOS disk geometry;
6.  waits for a partition choice from `1` through `4`;
7.  clears the existing active flags and marks the selected primary
    partition active;
8.  writes the modified MBR back to disk;
9.  reads the selected partition's PBR using legacy INT 13h CHS I/O;
10. verifies the PBR's `55 AA` signature; and
11. transfers control to the PBR at `0000:7C00`.

The installed boot-code region is limited to the traditional first **440
bytes** of the MBR. NASM fails the build if the code grows beyond that
limit.

### Interactive and automated input

There are two builds of the same source:

-   `bin/my-mbr.bin` --- normal build, using BIOS `INT 16h` keyboard
    input.
-   `bin/my-mbr-test.bin` --- automated-test build, compiled with
    `TEST_SERIAL_INPUT` and reading the selector choice from COM1.

The partition-selection logic itself is shared. The compile-time switch
changes the input transport rather than maintaining a separate test
bootloader.

This is important: **the normal interactive mode is the real
bootloader**. The serial-input build exists only so the automated suite
can select partitions without pretending to be a keyboard.

## Repository structure

The important parts of the tree are conceptually:

``` text
.
├── Makefile
├── my-mbr.asm
├── test-pbr.asm
├── bin/                    generated MBR/PBR binaries
├── images/                 generated layout images
├── test/
│   ├── layouts/            disk layout definitions
│   └── syslinux-mbr.bin    known-good reference MBR
└── scripts/
    ├── gen-img.sh
    ├── install-mbr.sh
    ├── install-pbr.sh
    ├── verify-img.sh
    ├── verify-active.sh
    ├── activate-partition.sh
    ├── run-qemu-test.sh
    ├── run-my-mbr-test.sh
    ├── test-common.sh
    ├── test-reference.sh
    ├── test-my-mbr.sh
    ├── loop-funcs.sh
    └── filesystems/
        └── ...
```

`bin/`, `images/`, and `.stamps/` are generated state and can be removed
with `make clean`.

## Requirements

The build and test environment currently assumes a Unix-like host with
the tools used by the scripts, including:

-   GNU Make
-   NASM
-   QEMU (`qemu-system-i386`)
-   standard shell utilities
-   Linux loop-device support
-   filesystem creation/checking utilities required by the layouts being
    tested

Some image operations require permission to create and manipulate loop
devices.

## Building

The default Make target is `all`:

``` sh
make
```

This builds the normal MBR, the serial-input test MBR, and all test PBR
binaries.

Equivalent useful targets are:

``` sh
make mbr
make pbr-tests
```

The generated bootloader binaries are:

``` text
bin/my-mbr.bin
bin/my-mbr-test.bin
```

and the test PBRs are:

``` text
bin/test-pbr1.bin
bin/test-pbr2.bin
bin/test-pbr3.bin
bin/test-pbr4.bin
```

## Layouts and images

Disk layouts live under:

``` text
test/layouts/*.layout
```

The default layout is:

``` text
test/layouts/default.layout
```

Unless an image name is explicitly supplied, the image filename is
derived from the layout name. For example:

``` text
test/layouts/default.layout
    -> images/default.layout.img

test/layouts/legacy-chs.layout
    -> images/legacy-chs.layout.img
```

This means different layouts naturally keep separate generated images.

### Selecting a layout

Use the default:

``` sh
make test
```

or select another layout:

``` sh
make test LAYOUT=test/layouts/legacy-chs.layout
```

### Overriding the image name

`IMAGE_NAME` overrides only the filename inside `images/`:

``` sh
make test IMAGE_NAME=foo.img
```

which uses:

``` text
images/foo.img
```

`IMAGE` is the lower-level override and supplies the complete path:

``` sh
make test IMAGE=/tmp/foo.img
```

The precedence is therefore:

``` text
IMAGE
  -> IMAGE_NAME
       -> name derived from LAYOUT
```

### Building every layout

``` sh
make all-layouts
```

builds an image for every `test/layouts/*.layout` file.

These are real Make file targets, so an existing image is not
regenerated merely because `make all-layouts` was invoked again.
Changing the corresponding layout causes it to be rebuilt.

## Filesystem-aware PBR installation

Installing a PBR is not treated as blindly overwriting sector zero of a
partition.

Different filesystems can have different boot-sector layouts, backup
boot sectors, and metadata requirements. The scripts therefore dispatch
filesystem-specific behaviour through handlers under:

``` text
scripts/filesystems/
```

The filesystem layer is responsible for the details required to create,
install, and verify boot records safely for each supported filesystem.

This is why the test suite repeatedly runs image/filesystem
verification: successfully reaching a PBR is not enough if installing it
damaged filesystem metadata along the way.

## Interactive use

Interactive runs use persistent generated images and the normal
keyboard-input build.

### Run `my-mbr`

``` sh
make run-my-mbr
```

This ensures the test PBRs and normal `my-mbr.bin` are installed, then
starts QEMU.

Choose a partition with the normal BIOS keyboard path by pressing:

``` text
1  2  3  4
```

To use another layout:

``` sh
make run-my-mbr LAYOUT=test/layouts/legacy-chs.layout
```

### Run the reference MBR

``` sh
make run-reference
```

This installs the test PBRs and the known-good reference MBR before
launching QEMU.

### Installation stamps

Interactive runs use `.stamps/` to avoid reinstalling unchanged MBRs and
PBRs every time QEMU is launched.

The generated image is deliberately an order-only dependency of these
installation stamps. This matters because a bootloader is allowed to
modify the disk image---for example, `my-mbr` persists the newly
selected active partition. Such a legitimate write should not by itself
cause Make to reinstall every boot record on the next interactive run.

When an image is regenerated, its associated installation stamps are
removed because the newly generated image no longer contains those
installed boot records.

## Automated testing

The automated suite has two complementary halves:

``` text
test-reference
test-my-mbr
```

and the complete test for one layout is:

``` sh
make test
```

Conceptually:

``` text
                    generated image
                          |
             +------------+------------+
             |                         |
      test-reference              test-my-mbr
             |                         |
       reference MBR              my-mbr-test.bin
             |                         |
     activate partition N         send N over COM1
             |                         |
          boot PBR                   boot PBR
             |                         |
      expect PBR_TEST_OK:N       expect PBR_TEST_OK:N
             |                         |
       verify image             verify active=N
                               verify image
```

### Why test against a reference MBR?

`test-reference` is the control test.

Its job is to establish that the infrastructure around `MyMBR` is
behaving correctly:

-   the generated image is sane;
-   test PBRs can be installed;
-   filesystem-specific boot-sector handling is not corrupting metadata;
-   active partitions can be selected correctly;
-   the reference MBR can launch each PBR;
-   the expected `PBR_TEST_OK:N` result is observed; and
-   the image remains sane after the boot test.

If this test fails, the problem may be in image generation, PBR
installation, filesystem handling, active-partition manipulation, or the
QEMU harness rather than in `MyMBR`.

The reference boot itself can use QEMU snapshot mode because the
reference MBR is not being tested for persistent disk modification.
Guest writes need not reach the backing image.

### Testing `MyMBR`

``` sh
make test-my-mbr
```

uses:

``` text
bin/my-mbr-test.bin
```

which is assembled from the same `my-mbr.asm` source with:

``` text
TEST_SERIAL_INPUT
```

defined.

For each partition `1` through `4`, the test runner:

1.  sends the partition number to the emulated COM1 port;
2.  waits for the selected test PBR to emit `PBR_TEST_OK:N` through
    QEMU's debug console;
3.  verifies that `my-mbr` persisted that partition as the active
    partition; and
4.  verifies the image/filesystems again.

Unlike the reference-MBR boot test, this test **must not use QEMU
snapshot mode for the disk under test**. Persisting the new active flag
is part of `my-mbr`'s required behaviour, so the test needs to inspect
the real backing image afterward.

The sequence also deliberately moves through selections `1`, `2`, `3`,
and `4`. This exercises the requirement that selecting a new partition
clears the previous active flag rather than accumulating multiple active
partitions.

### Test PBR output

The test PBRs identify themselves using messages of the form:

``` text
PBR_TEST_OK:1
PBR_TEST_OK:2
PBR_TEST_OK:3
PBR_TEST_OK:4
```

The PBR output is sent through QEMU's debug console, independently of
the COM1 channel used to feed automated choices into `my-mbr`.

This gives the automated test two separate directions:

``` text
host -> COM1 -> my-mbr selector input

test PBR -> debug port -> host result capture
```

## Testing every layout

The complete automated suite can be run against every layout with:

``` sh
make test-all-layouts
```

This enumerates `test/layouts/*.layout` and invokes the normal `test`
target separately for each layout.

That is intentionally implemented in terms of the ordinary per-layout
test: there is only one definition of what constitutes the complete
suite.

There are also narrower all-layout targets:

``` sh
make test-reference-all-layouts
make test-my-mbr-all-layouts
```

The first runs only the reference/control suite for every layout; the
second runs only the project's MBR suite.

Adding another valid `.layout` file therefore automatically adds another
configuration to the all-layout regression suite.

## Useful Make targets

Here's the markdown properly formatted as a table:

| Make Target | Purpose |
|---|---|
| `make` / `make all` | Build MBRs and test PBRs |
| `make mbr` | Build normal and automated-test MBR binaries |
| `make pbr-tests` | Build the four test PBRs |
| `make all-layouts` | Generate every layout image |
| `make install-test-pbrs` | Install test PBRs into the selected persistent image |
| `make install-my-mbr` | Install the normal interactive `MyMBR` |
| `make install-reference-mbr` | Install the reference MBR |
| `make run-my-mbr` | Interactive QEMU run using the normal keyboard build |
| `make run-reference` | Interactive QEMU run using the reference MBR |
| `make test-reference` | Automated reference/control test for one layout |
| `make test-my-mbr` | Automated `MyMBR` test for one layout |
| `make test` | Run both automated suites for one layout |
| `make test-reference-all-layouts` | Reference/control tests for every layout |
| `make test-my-mbr-all-layouts` | `MyMBR` tests for every layout |
| `make test-all-layouts` | Complete automated suite for every layout |
| `make check-scripts` | Run Bash syntax checks over project scripts |
| `make clean` | Remove generated binaries, images, and stamps |

## Typical workflows

### Change `my-mbr.asm` and try it interactively

``` sh
make run-my-mbr LAYOUT=test/layouts/legacy-chs.layout
```

The normal build still uses BIOS keyboard input.

### Change `my-mbr.asm` and run its automated regression test

``` sh
make test-my-mbr LAYOUT=test/layouts/legacy-chs.layout
```

The test build reads selections over COM1.

### Check the tooling independently of `my-mbr`

``` sh
make test-reference
```

### Run everything for the current/default layout

``` sh
make test
```

### Run everything against every layout

``` sh
make test-all-layouts
```

### Check shell syntax

``` sh
make check-scripts
```

### Start over

``` sh
make clean
make test
```

## Test philosophy

The project deliberately treats boot-sector code as something that can
appear to work while still doing damage.

A successful jump into a PBR is therefore only one assertion.

The broader invariant is:

> **Before and after every meaningful operation, the disk image should
> remain valid except for the exact metadata changes that the operation
> is intended to make.**

The reference-MBR suite provides a control path for the image/PBR
tooling. The `my-mbr` suite then exercises the project's own selector
against the same fixtures.

This separation makes failures much easier to interpret:

``` text
reference test fails
    -> suspect image/PBR/filesystem/test infrastructure

reference passes, my-mbr fails
    -> suspect my-mbr or its automated selector path
```

The layout system extends the same principle across different disk
geometries, partition arrangements, and filesystem combinations without
requiring separate hard-coded test logic for each image.

## Legacy BIOS focus

The current MBR deliberately uses legacy BIOS services and CHS PBR
loading.

Layouts such as the legacy CHS fixture are useful for proving the pure
CHS path on a disk whose relevant partitions are representable by the
BIOS geometry.

Other layouts can exercise cases where CHS is insufficient and provide
regression fixtures as the bootloader grows additional disk-access
support.

Keeping these as separate layouts allows newer functionality to be added
without losing a known test of the oldest supported boot path.

## Cleaning generated state

``` sh
make clean
```

removes:

``` text
bin/
images/
.stamps/
```

The source layouts, assembly, scripts, and reference test data remain
untouched.
