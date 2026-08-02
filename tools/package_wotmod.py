from __future__ import print_function

import os
import sys
import zipfile


def main():
    if len(sys.argv) != 3:
        print('Usage: package_wotmod.py <stage-directory> <output.wotmod>', file=sys.stderr)
        return 2

    stage = os.path.abspath(sys.argv[1])
    output = os.path.abspath(sys.argv[2])
    if not os.path.isdir(stage):
        print('Stage directory does not exist: {0}'.format(stage), file=sys.stderr)
        return 2

    archive = zipfile.ZipFile(output, 'w', zipfile.ZIP_STORED, allowZip64=True)
    try:
        for root, directories, files in os.walk(stage):
            directories.sort()
            files.sort()
            for name in files:
                source = os.path.join(root, name)
                entry = os.path.relpath(source, stage).replace(os.sep, '/')
                archive.write(source, entry, zipfile.ZIP_STORED)
    finally:
        archive.close()

    archive = zipfile.ZipFile(output, 'r')
    try:
        compressed = [info.filename for info in archive.infolist()
                      if info.compress_type != zipfile.ZIP_STORED]
    finally:
        archive.close()

    if compressed:
        print('Unsupported compressed entries: {0}'.format(', '.join(compressed)),
              file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    sys.exit(main())
