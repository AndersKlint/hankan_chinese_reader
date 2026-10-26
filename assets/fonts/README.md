PDF export fonts are derived from Noto Sans SC, licensed under SIL OFL 1.1
(see OFL.txt).

Source: https://github.com/notofonts/noto-cjk/blob/main/Sans/Variable/TTF/Subset/NotoSansSC-VF.ttf
License: https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE

Generated with fontTools 4.67.0: instantiate the weight axis at 400 and 700,
then generate the italic variants by applying a 0.2 horizontal shear to
glyph outlines and setting post.italicAngle to -11.31 degrees.
Italic is synthetic because Noto Sans SC has no native italic face.
Fonts are bundled for offline use; PDFs embed subsets as selectable text.
Coverage follows Noto Sans SC, including common simplified and traditional
Chinese; rare characters and emoji may not be covered.

All four exact faces are retained as lossless gzip assets and decompressed
in memory on export. Compression preserves the original TTF bytes, including
glyph coverage, bold/italic outlines, metadata and checksums.

| Asset | Original bytes | Gzip bytes |
| --- | ---: | ---: |
| NotoSansSC-Regular.ttf.gz | 10,596,232 | 6,297,464 |
| NotoSansSC-Bold.ttf.gz | 10,585,764 | 6,373,352 |
| NotoSansSC-RegularItalic.ttf.gz | 10,974,288 | 6,693,610 |
| NotoSansSC-BoldItalic.ttf.gz | 10,964,180 | 6,778,165 |
| Total | 43,120,464 | 26,142,591 |

This saves 16,977,873 bytes (39.37%) in raw bundled font assets. Export still
expands the fonts to their original size in memory.

To compress the generated TTFs from the repository root with maximum
compression and a deterministic zero timestamp:

```sh
python -c 'import gzip; from pathlib import Path
for p in sorted(Path("assets/fonts").glob("*.ttf")):
    p.with_suffix(".ttf.gz").write_bytes(gzip.compress(p.read_bytes(), compresslevel=9, mtime=0))'
```

Before removing any original TTFs, verify every compressed asset:

```sh
python -c 'import gzip; from pathlib import Path
files = list(Path("assets/fonts").glob("*.ttf"))
assert len(files) == 4
for p in files:
    assert p.read_bytes() == gzip.decompress(p.with_suffix(".ttf.gz").read_bytes()), p'
```
