using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class WaveMeshes : MonoBehaviour
{
    // Main Camera
    private GameObject mc;
    private float cameraXFloor, cameraZFloor;
    // 频谱&波形数据
    //   常量（需与 MATLAB 生成原始数据所用的参数一致）
    const int p = 9;
    const int N = 1 << p;
    const float dd = 20.0f /* m */;
    public TextAsset spectrumSource;
    private ComputeBuffer spectrumBuffer;
    private ComputeBuffer semiFinishedBuffer;
    private RenderTexture waveform;
    private RenderTexture waveformNormal;
    // 计算着色器
    public ComputeShader shaderComputeWave;
    private int shaderCWInitialIdx, shaderCWFinalIdx;
    public ComputeShader shaderComputeNormal;
    private int shaderCNIdx;


    private int ToIndex(int start, int i, int j, int n)
    {
        return start + i * n + j;
    }

    private void BuildMeshes(float centerLBX, float centerLBZ)
    {
        const int bN = 15;
        // 顶点与三角形数组
        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();
        List<Vector2> uv = new List<Vector2>();
        int[,] blockStartIdx = new int[2 * bN + 1, 2 * bN + 1];
        int[,] blockSize = new int[2 * bN + 1, 2 * bN + 1];

        // Block 循环
        for (int a = -bN; a <= bN; a++)
            for (int b = -bN; b <= bN; b++)
            {
                float dis = Mathf.Sqrt(a * a + b * b);
                int pp;
                if (dis > 1e-6)
                    pp = 5 + Mathf.FloorToInt(Mathf.Log(1.5f / dis) / Mathf.Log(2));
                else
                    pp = 5;
                if (pp < 0) pp = 0;
                int n = 1 << pp;
                int start = vertices.Count;
                blockStartIdx[a + bN, b + bN] = start;
                blockSize[a + bN, b + bN] = n;
                // Vertex 循环
                for (int i = 0; i < n; i++)
                    for (int j = 0; j < n; j++)
                    {
                        vertices.Add(new Vector3(
                            centerLBX + dd * (a + (float)i / n),
                            0,
                            centerLBZ + dd * (b + (float)j / n)
                        ));
                        uv.Add(new Vector2(
                            (centerLBX + dd * (a + (float)i / n)),
                            (centerLBZ + dd * (b + (float)j / n))
                            ) / dd
                        );
                    }

                // Triangle 循环
                int A, B, C, D, E;
                int start1 = 0, start2 = 0, start3 = 0;
                int n1 = 0, n2 = 0, n3 = 0;
                //   X间距补齐
                if (a + bN > 0)
                {
                    start1 = blockStartIdx[a - 1 + bN, b + bN];
                    n1 = blockSize[a - 1 + bN, b + bN];
                    if (n > n1)
                    {
                        for (int j = 0; j < n1 - 1; j++)
                        {
                            A = ToIndex(start, 0, 2 * j, n);
                            B = ToIndex(start, 0, 2 * j + 1, n);
                            C = ToIndex(start, 0, 2 * j + 2, n);
                            D = ToIndex(start1, n1 - 1, j, n1);
                            E = ToIndex(start1, n1 - 1, j + 1, n1);
                            triangles.Add(B); triangles.Add(A); triangles.Add(D);
                            triangles.Add(B); triangles.Add(D); triangles.Add(E);
                            triangles.Add(B); triangles.Add(E); triangles.Add(C);
                        }
                        A = ToIndex(start, 0, n - 2, n);
                        B = ToIndex(start, 0, n - 1, n);
                        C = ToIndex(start1, n1 - 1, n1 - 1, n1);
                        triangles.Add(A); triangles.Add(C); triangles.Add(B);
                    } else if (n < n1)
                    {
                        for (int j = 0; j < n - 1; j++)
                        {
                            A = ToIndex(start1, n1 - 1, 2 * j, n1);
                            B = ToIndex(start1, n1 - 1, 2 * j + 1, n1);
                            C = ToIndex(start1, n1 - 1, 2 * j + 2, n1);
                            D = ToIndex(start, 0, j, n);
                            E = ToIndex(start, 0, j + 1, n);
                            triangles.Add(B); triangles.Add(D); triangles.Add(A);
                            triangles.Add(B); triangles.Add(E); triangles.Add(D);
                            triangles.Add(B); triangles.Add(C); triangles.Add(E);
                        }
                        A = ToIndex(start1, n1 - 1, n1 - 2, n1);
                        B = ToIndex(start1, n1 - 1, n1 - 1, n1);
                        C = ToIndex(start, 0, n - 1, n);
                        triangles.Add(A); triangles.Add(B); triangles.Add(C);
                    } else
                    {
                        for (int j = 0; j < n - 1; j++)
                        {
                            A = ToIndex(start1, n - 1, j, n);
                            C = ToIndex(start1, n - 1, j + 1, n);
                            D = ToIndex(start, 0, j, n);
                            E = ToIndex(start, 0, j + 1, n);
                            triangles.Add(D); triangles.Add(A); triangles.Add(E);
                            triangles.Add(C); triangles.Add(E); triangles.Add(A);
                        }
                    }
                }
                //   Z间距补齐
                if (b + bN  > 0)
                {
                    start2 = blockStartIdx[a + bN, b - 1 + bN];
                    n2 = blockSize[a + bN, b - 1 + bN];
                    if (n > n2)
                    {
                        for (int i = 0; i < n2 - 1; i++)
                        {
                            A = ToIndex(start, 2 * i, 0, n);
                            B = ToIndex(start, 2 * i + 1, 0, n);
                            C = ToIndex(start, 2 * i + 2, 0, n);
                            D = ToIndex(start2, i, n2 - 1, n2);
                            E = ToIndex(start2, i + 1, n2 - 1, n2);
                            triangles.Add(B); triangles.Add(D); triangles.Add(A);
                            triangles.Add(B); triangles.Add(E); triangles.Add(D);
                            triangles.Add(B); triangles.Add(C); triangles.Add(E);
                        }
                        A = ToIndex(start, n - 2, 0, n);
                        B = ToIndex(start, n - 1, 0, n);
                        C = ToIndex(start2, n2 - 1, n2 - 1, n2);
                        triangles.Add(A); triangles.Add(B); triangles.Add(C);
                    }
                    else if (n < n2)
                    {
                        for (int i = 0; i < n - 1; i++)
                        {
                            A = ToIndex(start2, 2 * i, n2 - 1, n2);
                            B = ToIndex(start2, 2 * i + 1, n2 - 1, n2);
                            C = ToIndex(start2, 2 * i + 2, n2 - 1, n2);
                            D = ToIndex(start, i, 0, n);
                            E = ToIndex(start, i + 1, 0, n);
                            triangles.Add(B); triangles.Add(A); triangles.Add(D);
                            triangles.Add(B); triangles.Add(D); triangles.Add(E);
                            triangles.Add(B); triangles.Add(E); triangles.Add(C);
                        }
                        A = ToIndex(start2, n2 - 2, n2 - 1, n2);
                        B = ToIndex(start2, n2 - 1, n2 - 1, n2);
                        C = ToIndex(start, n - 1, 0, n);
                        triangles.Add(A); triangles.Add(C); triangles.Add(B);
                    }
                    else
                    {
                        for (int i = 0; i < n - 1; i++)
                        {
                            A = ToIndex(start2, i, n - 1, n);
                            C = ToIndex(start2, i + 1, n - 1, n);
                            D = ToIndex(start, i, 0, n);
                            E = ToIndex(start, i + 1, 0, n);
                            triangles.Add(D); triangles.Add(E); triangles.Add(A);
                            triangles.Add(C); triangles.Add(A); triangles.Add(E);
                        }
                    }
                }
                //   十字交叉处补齐
                if (a + bN > 0 && b + bN > 0)
                {
                    start1 = blockStartIdx[a - 1 + bN, b + bN];
                    n1 = blockSize[a - 1 + bN, b + bN];
                    start2 = blockStartIdx[a + bN, b - 1 + bN];
                    n2 = blockSize[a + bN, b - 1 + bN];
                    start3 = blockStartIdx[a - 1 + bN, b - 1 + bN];
                    n3 = blockSize[a - 1 + bN, b - 1 + bN];
                    A = start;
                    B = ToIndex(start1, n1 - 1, 0, n1);
                    C = ToIndex(start3, n3 - 1, n3 - 1, n3);
                    D = ToIndex(start2, 0, n2 - 1, n2);
                    triangles.Add(A); triangles.Add(D); triangles.Add(B);
                    triangles.Add(C); triangles.Add(B); triangles.Add(D);
                }
                //   普通三角形
                for (int i = 1; i < n; i++)
                    for (int j = 1; j < n; j++)
                    {
                        A = ToIndex(start, i, j, n);
                        B = ToIndex(start, i - 1, j, n);
                        C = ToIndex(start, i - 1, j - 1, n);
                        D = ToIndex(start, i, j - 1, n);
                        triangles.Add(A); triangles.Add(C); triangles.Add(B);
                        triangles.Add(A); triangles.Add(D); triangles.Add(C);
                    }
            }

        //   网格对象
        Mesh mesh = new Mesh();
        GetComponent<MeshFilter>().mesh = mesh;
        mesh.vertices = vertices.ToArray();
        mesh.uv = uv.ToArray();
        mesh.triangles = triangles.ToArray();
        Debug.Log(vertices.Count);
    }

    private void CreateTexture4f(ref RenderTexture txt)
    {
        txt = new RenderTexture(N, N, 0, RenderTextureFormat.ARGBFloat);
        txt.enableRandomWrite = true;
        txt.wrapMode = TextureWrapMode.Repeat;
        txt.Create();
    }

    // Use this for initialization
    void Start()
    {
        mc = GameObject.FindGameObjectWithTag("MainCamera");
        // 1. 生成网格
        cameraXFloor = Mathf.Floor(mc.transform.position.x / dd) * dd;
        cameraZFloor = Mathf.Floor(mc.transform.position.z / dd) * dd;
        BuildMeshes(cameraXFloor, cameraZFloor);

        // 2. 初始化 buffers & textures 并绑定到 shader
        //   Buffers & Textures
        spectrumBuffer = new ComputeBuffer(N * N, 2 * sizeof(float));
        spectrumBuffer.SetData(spectrumSource.bytes);
        semiFinishedBuffer = new ComputeBuffer(N * N * 2, 4 * sizeof(float));
        CreateTexture4f(ref waveform);
        CreateTexture4f(ref waveformNormal);
        //   Compute Shader
        shaderCWInitialIdx = shaderComputeWave.FindKernel("InitialMain");
        shaderComputeWave.SetBuffer(shaderCWInitialIdx, "spectrumBuffer", spectrumBuffer);
        shaderComputeWave.SetBuffer(shaderCWInitialIdx, "semiFinishedBuffer", semiFinishedBuffer);
        shaderCWFinalIdx = shaderComputeWave.FindKernel("FinalMain");
        shaderComputeWave.SetBuffer(shaderCWFinalIdx, "semiFinishedBuffer", semiFinishedBuffer);
        shaderComputeWave.SetTexture(shaderCWFinalIdx, "waveform", waveform);
        shaderComputeWave.SetTexture(shaderCWFinalIdx, "waveformNormal", waveformNormal);
        shaderCNIdx = shaderComputeNormal.FindKernel("CSMain");
        shaderComputeNormal.SetTexture(shaderCNIdx, "waveform", waveform);
        shaderComputeNormal.SetTexture(shaderCNIdx, "waveformNormal", waveformNormal);
        //   Unlit Shader: 
        GetComponent<MeshRenderer>().sharedMaterial.SetTexture("_Waveform", waveform);
        GetComponent<MeshRenderer>().sharedMaterial.SetTexture("_WaveformNormal", waveformNormal);
    }

    // Update is called once per frame
    void Update()
    {
        // 1. 更新 mesh
        float cameraXFloorNew = Mathf.Floor(mc.transform.position.x / dd) * dd;
        float cameraZFloorNew = Mathf.Floor(mc.transform.position.z / dd) * dd;
        if (cameraXFloorNew!= cameraXFloor || cameraZFloorNew != cameraZFloor)
        {
            cameraXFloor = cameraXFloorNew;
            cameraZFloor = cameraZFloorNew;
            BuildMeshes(cameraXFloor, cameraZFloor);
        }
 
        // 2. 更新波形
        shaderComputeWave.SetFloat("dtime", Time.deltaTime);
        shaderComputeWave.Dispatch(shaderCWInitialIdx, 1, N , 1);
        shaderComputeWave.Dispatch(shaderCWFinalIdx, 1, N, 1);
        shaderComputeNormal.Dispatch(shaderCNIdx, N / 8, N / 8, 1);
    }

    private void OnDisable()
    {
        if (spectrumBuffer != null)
            spectrumBuffer.Release();
        if (semiFinishedBuffer != null)
            semiFinishedBuffer.Release();
    }
}
