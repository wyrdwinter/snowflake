# Package

version     = "0.1.0"
author      = "Wyrd"
description = "A simple web application that parses and displays Neverwinter Nights character files in a human-readable format."
license     = "AGPL-3.0-or-later"
srcDir      = "src"
bin         = @["snowflake"]

# Dependencies

requires "nim >= 1.6.2"
requires "neverwinter >= 1.5.4"
requires "jester >= 0.5.0"
requires "mustache >= 0.4.3"
requires "redis >= 0.3.0"
requires "nimPNG >= 0.3.1"
