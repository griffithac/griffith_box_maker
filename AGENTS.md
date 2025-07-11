# AGENTS Instructions for griffith_box_maker

This project is a Ruby command line tool for designing finger‑jointed boxes that will be cut from sheet goods like plywood. It outputs SVG layouts and optional STL previews. The generated vectors must form closed polygons with no stray segments so they can be converted to GRBL‑compatible GCode for use with CNC routers (such as Bob's CNC). A GCode sender component is planned.

## Testing
- Install dependencies with `bundle install`.
- Run tests with `bundle exec rake` and ensure they pass before committing.

## Coding style
- Target the latest stable Ruby (3.2 or newer).
- Use two spaces for indentation with no hard tabs.
- Keep methods small and readable.

## Notes
- Dogbone reliefs currently do not work correctly. Test and fix them so joints fit together cleanly.
- Generated vectors should create continuous polygons for each part; avoid extraneous line segments.
- Investigate alternative geometry libraries if they would improve vector generation or GCode output.
