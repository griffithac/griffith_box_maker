# Griffith Box Maker

A command line utility for designing custom finger‑jointed boxes. It generates SVG panel files and cutting layouts for laser cutters or CNC routers. Optional features include lids, dividers and dogbone reliefs.

## Installation

1. Install **Ruby 2.7** or newer.
2. Install the gem dependencies using Bundler:

```bash
bundle install
```

## Quick Start

Generate a simple box directly from the command line:

```bash
ruby box_maker.rb --length 200 --width 150 --height 80 \
  --finger-width 25 --output ./output --no-open
```

Run with no arguments (or `--interactive`) to launch the menu driven interface:

```bash
ruby box_maker.rb
```

## Interactive Menu & CLI Options

The interactive mode lets you configure dimensions, material stock, tools, joints and features using a TTY menu. Navigate with the arrow keys (or hjkl) and press ENTER to select. Command‑line users can see all options with:

```bash
ruby box_maker.rb --help
```

Use `--stl` to also generate an assembled box as an STL file for 3‑D preview:

```bash
ruby box_maker.rb --length 200 --width 150 --height 80 --stl
```

Settings may also be saved and loaded as projects for later use.

## Examples

Example SVG output is included in the [`output/`](output/) folder such as the cutting layout:

- [cutting_layout_sheet_1.svg](output/cutting_layout_sheet_1.svg)

More examples can be generated using the steps above.

# box_maker
# griffith_box_maker

## Dependencies

Run `bundle install` to install required gems. The application relies on
`victor`, `tty-prompt`, `pastel`, `svgcode`, and now `launchy` for opening
generated previews.

## License

This project is licensed under the [MIT License](LICENSE).
