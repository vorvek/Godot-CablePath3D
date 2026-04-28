using Godot;

[Tool]
[GlobalClass]
public partial class CablePath3D : Path3D
{
    private const string GeneratedMeshName = "GeneratedMesh";
    private const string GeneratedMeshMeta = "_cable_path_3d_generated";

    private float _cableThickness = 0.01f;
    private Material _cableMaterial;
    private float _pathInterval = 0.05f;
    private float _pathUDistance = 1.0f;
    private int _radialSegments = 8;

    private MeshInstance3D _meshInstance;
    private readonly StandardMaterial3D _debugMaterial = new()
    {
        AlbedoColor = new Color(1.0f, 0.0f, 0.0f),
        Metallic = 0.0f,
        Roughness = 0.5f,
    };

    private Curve3D _connectedCurve;
    private bool _updateQueued;

    [Export(PropertyHint.Range, "0.001,1.0,0.001")]
    public float CableThickness
    {
        get => _cableThickness;
        set
        {
            _cableThickness = Mathf.Max(value, 0.001f);
            RequestUpdate();
        }
    }

    [Export]
    public Material CableMaterial
    {
        get => _cableMaterial;
        set
        {
            _cableMaterial = value;
            RequestUpdate();
        }
    }

    [Export(PropertyHint.Range, "0.001,1.0,0.001")]
    public float PathInterval
    {
        get => _pathInterval;
        set
        {
            _pathInterval = Mathf.Max(value, 0.001f);
            RequestUpdate();
        }
    }

    [Export(PropertyHint.Range, "0.001,10.0,0.001")]
    public float PathUDistance
    {
        get => _pathUDistance;
        set
        {
            _pathUDistance = Mathf.Max(value, 0.001f);
            RequestUpdate();
        }
    }

    [Export(PropertyHint.Range, "3,64,1")]
    public int RadialSegments
    {
        get => _radialSegments;
        set
        {
            _radialSegments = Mathf.Max(value, 3);
            RequestUpdate();
        }
    }

    [ExportGroup("Cable Baking")]
    [Export]
    public bool RegenerateMesh
    {
        get => false;
        set
        {
            if (value)
            {
                RequestUpdate();
            }
        }
    }

    public override void _EnterTree()
    {
        CurveChanged -= RequestUpdate;
        CurveChanged += RequestUpdate;
        ConnectCurveChanged();
    }

    public override void _Ready()
    {
        UpdateCable();
    }

    public override void _ExitTree()
    {
        CurveChanged -= RequestUpdate;
        DisconnectCurveChanged();
    }

    public void RegenerateCable()
    {
        UpdateCable();
    }

    public void regenerate_cable()
    {
        RegenerateCable();
    }

    private void RequestUpdate()
    {
        if (!IsInsideTree())
        {
            return;
        }

        if (_updateQueued)
        {
            return;
        }

        _updateQueued = true;
        CallDeferred(nameof(RegenerateCable));
    }

    private void ConnectCurveChanged()
    {
        Curve3D curve = Curve;
        if (_connectedCurve == curve)
        {
            return;
        }

        DisconnectCurveChanged();
        _connectedCurve = curve;

        if (_connectedCurve != null)
        {
            _connectedCurve.Changed += RequestUpdate;
        }
    }

    private void DisconnectCurveChanged()
    {
        if (_connectedCurve != null)
        {
            _connectedCurve.Changed -= RequestUpdate;
        }

        _connectedCurve = null;
    }

    private void UpdateCable()
    {
        _updateQueued = false;
        ConnectCurveChanged();

        ArrayMesh mesh = CreateCableMesh();
        if (mesh == null)
        {
            MeshInstance3D existingMeshInstance = GetExistingMeshInstance();
            if (existingMeshInstance != null)
            {
                existingMeshInstance.Mesh = null;
            }

            return;
        }

        MeshInstance3D meshInstance = GetOrCreateMeshInstance();
        meshInstance.Mesh = mesh;
        meshInstance.MaterialOverride = _cableMaterial ?? _debugMaterial;
    }

    private MeshInstance3D GetOrCreateMeshInstance()
    {
        _meshInstance = GetExistingMeshInstance();
        if (_meshInstance != null)
        {
            return _meshInstance;
        }

        _meshInstance = new MeshInstance3D
        {
            Name = GeneratedMeshName,
        };
        _meshInstance.SetMeta(GeneratedMeshMeta, true);
        AddChild(_meshInstance);

        if (Engine.IsEditorHint() && IsInsideTree())
        {
            Node editedSceneRoot = GetTree().EditedSceneRoot;
            if (editedSceneRoot != null)
            {
                _meshInstance.Owner = editedSceneRoot;
            }
        }

        return _meshInstance;
    }

    private MeshInstance3D GetExistingMeshInstance()
    {
        if (_meshInstance != null && GodotObject.IsInstanceValid(_meshInstance) && _meshInstance.GetParent() == this)
        {
            return _meshInstance;
        }

        _meshInstance = GetNodeOrNull<MeshInstance3D>(GeneratedMeshName);
        if (_meshInstance != null)
        {
            _meshInstance.SetMeta(GeneratedMeshMeta, true);
        }

        return _meshInstance;
    }

    private ArrayMesh CreateCableMesh()
    {
        Curve3D curve = Curve;
        if (curve == null || curve.PointCount < 2)
        {
            return null;
        }

        float totalLength = curve.GetBakedLength();
        if (totalLength <= 0.0f)
        {
            return null;
        }

        int segments = Mathf.Max(1, Mathf.CeilToInt(totalLength / Mathf.Max(_pathInterval, 0.001f)));
        int circleResolution = Mathf.Max(_radialSegments, 3);
        int vertexCount = (segments + 1) * circleResolution;
        int indexCount = segments * circleResolution * 6;

        var vertices = new Vector3[vertexCount];
        var normals = new Vector3[vertexCount];
        var uvs = new Vector2[vertexCount];
        var indices = new int[indexCount];

        int vertexIndex = 0;
        for (int i = 0; i <= segments; i++)
        {
            float t = (float)i / segments;
            float distanceAlongCurve = t * totalLength;

            Transform3D sampleTransform = curve.SampleBakedWithRotation(distanceAlongCurve, false);
            Vector3 position = sampleTransform.Origin;
            Vector3 normal = sampleTransform.Basis.Y.Normalized();
            Vector3 binormal = sampleTransform.Basis.X.Normalized();

            for (int j = 0; j < circleResolution; j++)
            {
                float angle = Mathf.Tau * j / circleResolution;
                Vector3 circlePosition = binormal * Mathf.Cos(angle) * _cableThickness
                    + normal * Mathf.Sin(angle) * _cableThickness;

                vertices[vertexIndex] = position + circlePosition;
                normals[vertexIndex] = circlePosition.Normalized();
                uvs[vertexIndex] = new Vector2((float)j / circleResolution, i * _pathUDistance);
                vertexIndex++;
            }
        }

        int index = 0;
        for (int i = 0; i < segments; i++)
        {
            for (int j = 0; j < circleResolution; j++)
            {
                int current = i * circleResolution + j;
                int next = current + circleResolution;
                int nextVertex = i * circleResolution + ((j + 1) % circleResolution);
                int nextNext = nextVertex + circleResolution;

                indices[index++] = current;
                indices[index++] = nextVertex;
                indices[index++] = next;

                indices[index++] = nextVertex;
                indices[index++] = nextNext;
                indices[index++] = next;
            }
        }

        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices;
        arrays[(int)Mesh.ArrayType.Normal] = normals;
        arrays[(int)Mesh.ArrayType.TexUV] = uvs;
        arrays[(int)Mesh.ArrayType.Index] = indices;

        var mesh = new ArrayMesh();
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        return mesh;
    }
}
