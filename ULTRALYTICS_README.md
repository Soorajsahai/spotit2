Run the ultralytics detection server used by the Flutter app

1. Create and activate a Python virtualenv (recommended):

```bash
python -m venv .venv
source .venv/bin/activate   # macOS / Linux
.venv\Scripts\activate     # Windows (PowerShell)
```

2. Install dependencies:

```bash
pip install ultralytics fastapi uvicorn python-multipart pillow
```

3. (Optional) Download or provide a YOLO weights file and set `YOLO_MODEL` env var.
   Default is `yolov8n.pt` which will be downloaded automatically by ultralytics.

4. Run the server:

```bash
uvicorn tools.ultralytics_server:app --host 0.0.0.0 --port 8000
```

5. The Flutter app expects the detection endpoint at `http://127.0.0.1:8000/detect`.
   On a real device, point the app to the machine's IP (e.g. `http://192.168.1.42:8000`).
