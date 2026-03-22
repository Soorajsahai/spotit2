from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
import tempfile
import os
import numpy as np

# ultralytics (yolov8) import
from ultralytics import YOLO

app = FastAPI(title="Ultralytics YOLO Detection Server")

# Use env var YOLO_MODEL or default to a local .pt file
MODEL_PATH = "best.pt"
model = None
try:
    model = YOLO(MODEL_PATH)
except Exception as e:
    # Keep startup going but mark model as unavailable; requests will return 500.
    print(f"Failed to load model {MODEL_PATH}: {e}")
    model = None

@app.post("/detect")
async def detect(file: UploadFile = File(...), conf: float = 0.25, iou: float = 0.45, imgsz: int = 640):
    # save upload to a temp file
    suffix = os.path.splitext(file.filename)[1] or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        content = await file.read()
        tmp.write(content)

    try:
        if model is None:
            raise RuntimeError(f"Model not loaded. Set YOLO_MODEL env or ensure {MODEL_PATH} is present.")
        results = model.predict(source=tmp_path, imgsz=imgsz, conf=conf, iou=iou, save=False)
        out = {"detections": [], "model": MODEL_PATH}

        for res in results:  # usually one result per image
            boxes = getattr(res, "boxes", None)
            if boxes is None:
                continue

            # try to extract arrays from boxes
            # boxes.xyxy, boxes.conf, boxes.cls
            xyxy = getattr(boxes, "xyxy", None)
            confs = getattr(boxes, "conf", None)
            clss = getattr(boxes, "cls", None)

            try:
                arr_xyxy = xyxy.cpu().numpy() if hasattr(xyxy, "cpu") else np.asarray(xyxy)
            except Exception:
                try:
                    arr_xyxy = np.asarray(xyxy)
                except Exception:
                    arr_xyxy = []

            try:
                arr_conf = confs.cpu().numpy() if hasattr(confs, "cpu") else np.asarray(confs)
            except Exception:
                arr_conf = np.asarray(confs) if confs is not None else np.array([])

            try:
                arr_cls = clss.cpu().numpy() if hasattr(clss, "cpu") else np.asarray(clss)
            except Exception:
                arr_cls = np.asarray(clss) if clss is not None else np.array([])

            # normalize lengths
            n = len(arr_xyxy)
            for i in range(n):
                x1, y1, x2, y2 = [float(v) for v in arr_xyxy[i]]
                score = float(arr_conf[i]) if i < len(arr_conf) else 0.0
                class_id = int(arr_cls[i]) if i < len(arr_cls) else 0
                label = model.names.get(class_id, str(class_id)) if hasattr(model, "names") else str(class_id)

                # Ensure native Python types (no numpy types) and provide both
                # `label` (friendly name) and `class` for compatibility.
                out["detections"].append({
                    "box": [float(x1), float(y1), float(x2), float(y2)],
                    "score": float(score),
                    "class_id": int(class_id),
                    "class": str(label),
                    "label": str(label),
                })

        return JSONResponse(content=out)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass

if __name__ == "__main__":
    # Railway (and other PaaS platforms) assign a PORT env var dynamically.
    # Fall back to 8000 for local development.
    import os
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)