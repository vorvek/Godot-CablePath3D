# Godot-CablePath3D
A simple Editor tool for Godot 4 that allows the user to generate cables, tubes and pipes along any arbitrary path.

![Screenshot of the CablePath3D tool working inside the Godot 4 Editor](/readme_img/editor_sample.jpg)

## Installation

Simply drop the .gd file somewhere in your project folder. It will give you access to a new node called **CablePath3D**.

## Usage

This tool extends the [Path3D](https://docs.godotengine.org/en/4.4/classes/class_path3d.html) node, giving you access to all the Path3D point editing features. To create a cable, simply add a new CablePath3D node to your scene, and start adding points to it. You can then customize the cable's appearance using the various properties available in the Inspector. You can force an update by checking the "Regenerate Mesh" chekbox under the Cable Baking section.

The generation doesn't use CSGPolygon3D, so the results may be a bit funkier than Godot's native CSG extrusion through a path, but I needed loads of arbitrary-shaped cables in my project, and CSG was too slow and cumbersome to work with.

**NOTE:** Don't add child nodes to the CablePath3D node, as they will be deleted when the mesh is regenerated.

This tool is provided as-is, and is intended to be a starting point for further customization. Feel free to modify the code to suit your needs.

## Licence
This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
