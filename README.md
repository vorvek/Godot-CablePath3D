# Godot-CablePath3D
A simple Editor tool for Godot 4 that allows the user to generate cables, tubes and pipes along any arbitrary path.

![Screenshot of the CablePath3D tool working inside the Godot 4 Editor](/readme_img/editor_sample.jpg)

## Installation

For regular Godot projects, copy `CablePath3D.gd` somewhere in your project folder. It will give you access to a new node called **CablePath3D**.

For Godot .NET projects, copy `CablePath3D.cs` instead. Use only one implementation in the same project, as both versions register the same **CablePath3D** node name.

## Usage

This tool extends the [Path3D](https://docs.godotengine.org/en/stable/classes/class_path3d.html) node, giving you access to all the Path3D point editing features. To create a cable, simply add a new CablePath3D node to your scene, and start adding points to it. The cable updates when the path or exported properties change. You can force an update by checking the "Regenerate Mesh" checkbox under the Cable Baking section.

## Generation

CablePath3D generates a regular `ArrayMesh`; it does not use `CSGPolygon3D` or any CSG nodes. The script samples the baked `Curve3D` along the path, creates a circular ring of vertices at each sample point, then connects neighboring rings with triangles to form an open tube.

The main Inspector properties control the mesh like this:

- `Cable Thickness`: the tube radius.
- `Cable Material`: the material applied to the generated mesh. If empty, the tool uses a red debug material.
- `Path Interval`: approximate distance between generated rings along the curve. Lower values make smoother cables with more vertices.
- `Path U Distance`: vertical UV tiling step per generated ring.
- `Radial Segments`: number of vertices around each ring. Higher values make rounder cables with more vertices.

The generated tube follows the baked curve rotation using Godot's `sample_baked_with_rotation()` behavior. It is intentionally uncapped at both ends, which keeps the mesh simple and fast for cable, tube, and pipe runs where the ends are usually hidden or covered by other scene geometry.

The GDScript and C# versions generate the same mesh. The C# version is provided for Godot .NET projects that want the same tool behavior with faster script execution.

**NOTE:** The generated child node is named `GeneratedMesh` and is managed by the script. You can add your own child nodes under CablePath3D, but direct edits to `GeneratedMesh` may be replaced when the mesh is regenerated.

This tool is provided as-is, and is intended to be a starting point for further customization. Feel free to modify the code to suit your needs.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
