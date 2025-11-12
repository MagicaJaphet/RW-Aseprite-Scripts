# RW-Aseprite-Scripts
Aseprite scripts made with the intention to make Rain World modding easier.

### Installation
Follow [Aseprite Scripting](https://www.aseprite.org/docs/scripting)'s instruction to open the script data folder, extract the zip or drag the raw code files into the script folder. Reload the scripts either by using File > Script > Rescan Script Folder, pressing F5, or restarting Aseprite.

# Live Palette Previewer
A script with the intention to help with creating palettes outside of the game, usage requires an unrendered screen and a palette file (default palette format is 32 x 16).

## Current Features

### Generate Data
The generate data function stores an internal table of all of the pixel information about the render, in hopes to make the recoloring process smoother.

### Bind Render
Binding the render allows the script to listen to palette updates, in order to rerender the image.

### Unbind Render
Removes the listener for the palette, but not the generated data.

### Real Time Palette Rendering
Currently supports the following colors (and the respective rain variations):
- sky
- fog
- grime
- depth
- decal / soft props

## Possible Future Features
- Water support (this is not built into the render, but a water level slider could be added)
- Shortcut previewing
- General creature previewing (not anything fancy, probably just a built in png)
- More accurate grime mask texturing