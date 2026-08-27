#!/usr/bin/env python3
import gzip
import io
import tarfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "pivot.tar.gz"
ORIGINAL = HERE / "su.original"


def header(name, mode, typeflag=tarfile.REGTYPE, linkname="", size=0):
    info = tarfile.TarInfo(name)
    info.mode = mode
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    info.type = typeflag
    info.linkname = linkname
    info.size = size
    return info


with OUTPUT.open("wb") as output:
    with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.GNU_FORMAT) as archive:
            for directory in ("etc/", "etc/pam.d/", "restore/"):
                archive.addfile(header(directory, 0o755, tarfile.DIRTYPE))

            placeholder = b"task-local create target\n"
            archive.addfile(
                header("etc/pam.d/su", 0o644, size=len(placeholder)),
                io.BytesIO(placeholder),
            )

            original = ORIGINAL.read_bytes()
            archive.addfile(
                header("restore/su.original", 0o644, size=len(original)),
                io.BytesIO(original),
            )

            archive.addfile(
                header(
                    "pivot",
                    0o777,
                    tarfile.SYMTYPE,
                    linkname="/proc/self/cwd/etc/pam.d/su",
                )
            )

print(OUTPUT)
