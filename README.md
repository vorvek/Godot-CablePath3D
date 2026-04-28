# Godot-CablePath3D
A simple Editor tool for Godot 4 that allows the user to generate cables, tubes and pipes along any arbitrary path.

![Screenshot of the CablePath3D tool working inside the Godot 4 Editor](/readme_img/editor_sample.jpg)

## Installation

For regular Godot projects, copy `CablePath3D.gd` somewhere in your project folder. It will give you access to a new node called **CablePath3D**.

For Godot .NET projects, copy `csharp/CablePath3D.cs` instead. Use only one implementation in the same project, as both versions register the same **CablePath3D** node name.

## Usage

This tool extends the [Path3D](https://docs.godotengine.org/en/stable/classes/class_path3d.html) node, giving you access to all the Path3D point editing features. To create a cable, simply add a new CablePath3D node to your scene, and start adding points to it. The cable updates when the path or exported properties change. You can customize the cable's appearance with the Inspector properties, including thickness, material, path interval, UV distance, and radial segments. You can force an update by checking the "Regenerate Mesh" checkbox under the Cable Baking section.

The generation doesn't use CSGPolygon3D, so the results may be a bit funkier than Godot's native CSG extrusion through a path, but I needed loads of arbitrary-shaped cables in my project, and CSG was too slow and cumbersome to work with.

**NOTE:** The generated child node is named `GeneratedMesh` and is managed by the script. You can add your own child nodes under CablePath3D, but direct edits to `GeneratedMesh` may be replaced when the mesh is regenerated.

This tool is provided as-is, and is intended to be a starting point for further customization. Feel free to modify the code to suit your needs.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
