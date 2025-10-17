echo "Creando estructura de archivos en: $WORKDIR"

# Crear directorios
mkdir -p "$WORKDIR/backend/app"
mkdir -p "$WORKDIR/calculadora-frontend/src"
mkdir -p "$WORKDIR/.github"
cd "$WORKDIR"

# backend/app/__init__.py
cat > backend/app/__init__.py <<'PY'
# Package init for backend app
PY

# backend/app/models.py
cat > backend/app/models.py <<'PY'
from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime

class Calculation(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    input_expr: str
    result: str
    calc_type: str  # "evaluate" | "differentiate" | "integrate"
    created_at: datetime
PY

# backend/app/main.py
cat > backend/app/main.py <<'PY'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import sympy as sp
from sqlmodel import SQLModel, Field, Session, create_engine, select
from .models import Calculation

DATABASE_URL = "sqlite:///./calculations.db"
engine = create_engine(DATABASE_URL, echo=False)

app = FastAPI(title="Calculadora Científica API")

@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)

class ExprRequest(BaseModel):
    expr: str
    save: Optional[bool] = True

class DiffRequest(BaseModel):
    expr: str
    var: Optional[str] = "x"
    order: Optional[int] = 1
    save: Optional[bool] = True

class IntRequest(BaseModel):
    expr: str
    var: Optional[str] = "x"
    lower: Optional[str] = None
    upper: Optional[str] = None
    save: Optional[bool] = True

@app.post("/api/evaluate")
def evaluate(req: ExprRequest):
    try:
        expr = sp.sympify(req.expr)
        result = sp.simplify(expr)
        result_str = str(result)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error al evaluar: {e}")

    if req.save:
        with Session(engine) as session:
            calc = Calculation(
                input_expr=req.expr,
                result=result_str,
                calc_type="evaluate",
                created_at=datetime.utcnow()
            )
            session.add(calc)
            session.commit()
            session.refresh(calc)
            return {"result": result_str, "saved_id": calc.id}
    return {"result": result_str}

@app.post("/api/differentiate")
def differentiate(req: DiffRequest):
    try:
        var = sp.symbols(req.var)
        expr = sp.sympify(req.expr)
        deriv = sp.diff(expr, var, req.order)
        result_str = str(sp.simplify(deriv))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error al derivar: {e}")

    if req.save:
        with Session(engine) as session:
            calc = Calculation(
                input_expr=f"d^{req.order}/d{req.var}^{req.order} {req.expr}",
                result=result_str,
                calc_type="differentiate",
                created_at=datetime.utcnow()
            )
            session.add(calc)
            session.commit()
            session.refresh(calc)
            return {"result": result_str, "saved_id": calc.id}
    return {"result": result_str}

@app.post("/api/integrate")
def integrate(req: IntRequest):
    try:
        var = sp.symbols(req.var)
        expr = sp.sympify(req.expr)
        if req.lower is not None and req.upper is not None:
            lower = sp.sympify(req.lower)
            upper = sp.sympify(req.upper)
            integ = sp.integrate(expr, (var, lower, upper))
        else:
            integ = sp.integrate(expr, var)
        result_str = str(sp.simplify(integ))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error al integrar: {e}")

    if req.save:
        with Session(engine) as session:
            calc = Calculation(
                input_expr=f"∫ {req.expr} d{req.var}" + (f" [{req.lower}, {req.upper}]" if req.lower and req.upper else ""),
                result=result_str,
                calc_type="integrate",
                created_at=datetime.utcnow()
            )
            session.add(calc)
            session.commit()
            session.refresh(calc)
            return {"result": result_str, "saved_id": calc.id}
    return {"result": result_str}

@app.get("/api/history", response_model=List[Calculation])
def get_history(limit: int = 100):
    with Session(engine) as session:
        stmt = select(Calculation).order_by(Calculation.created_at.desc()).limit(limit)
        results = session.exec(stmt).all()
        return results

@app.delete("/api/history/{calc_id}")
def delete_history(calc_id: int):
    with Session(engine) as session:
        calc = session.get(Calculation, calc_id)
        if not calc:
            raise HTTPException(status_code=404, detail="Cálculo no encontrado")
        session.delete(calc)
        session.commit()
        return {"ok": True}
PY

# backend/requirements.txt
cat > backend/requirements.txt <<'PYREQ'
fastapi
uvicorn[standard]
sympy
sqlmodel
python-dotenv
PYREQ

# backend/Dockerfile
cat > backend/Dockerfile <<'PYDOCK'
FROM python:3.11-slim
WORKDIR /app
COPY ./requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY . /app
ENV PYTHONUNBUFFERED=1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
PYDOCK

# frontend files (Vite + React + TypeScript minimal)
cat > calculadora-frontend/package.json <<'PJ'
{
  "name": "calculadora-frontend",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.4.0",
    "katex": "^0.16.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-katex": "^3.1.0"
  },
  "devDependencies": {
    "typescript": "^5.1.0",
    "vite": "^5.0.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0"
  }
}
PJ

# calculadora-frontend/index.html
cat > calculadora-frontend/index.html <<'HTML'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Calculadora Científica</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
HTML

# calculadora-frontend/src/main.tsx
cat > calculadora-frontend/src/main.tsx <<'TS'
import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
TS

# calculadora-frontend/src/App.tsx
cat > calculadora-frontend/src/App.tsx <<'TSX'
import React, { useState, useEffect } from "react";
import axios from "axios";

function App() {
  const [expr, setExpr] = useState("");
  const [result, setResult] = useState<string | null>(null);
  const [history, setHistory] = useState<any[]>([]);

  const api = axios.create({
    baseURL: "http://localhost:8000/api"
  });

  useEffect(() => {
    fetchHistory();
  }, []);

  async function fetchHistory() {
    try {
      const res = await api.get("/history");
      setHistory(res.data);
    } catch (e) {
      console.error(e);
    }
  }

  async function handleEvaluate() {
    try {
      const res = await api.post("/evaluate", { expr, save: true });
      setResult(res.data.result);
      fetchHistory();
    } catch (e: any) {
      setResult("Error: " + (e.response?.data?.detail || e.message));
    }
  }

  return (
    <div style={{ padding: 20 }}>
      <h1>Calculadora Científica (ingeniería)</h1>
      <div>
        <input
          value={expr}
          onChange={(e) => setExpr(e.target.value)}
          placeholder="Escribe una expresión en SymPy (ej: sin(x)**2 + cos(x)**2)"
          style={{ width: "80%" }}
        />
        <button onClick={handleEvaluate}>Evaluar</button>
      </div>
      <div>
        <h2>Resultado</h2>
        <pre>{result}</pre>
      </div>
      <div>
        <h2>Historial</h2>
        <ul>
          {history.map((h) => (
            <li key={h.id}>
              [{h.calc_type}] {h.input_expr} =&gt; {h.result}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default App;
TSX

# calculadora-frontend/tsconfig.json
cat > calculadora-frontend/tsconfig.json <<'TSC'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM"],
    "jsx": "react-jsx",
    "module": "ESNext",
    "moduleResolution": "Node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src"]
}
TSC

# README.md (root)
cat > README.md <<'MARKDOWN'
```markdown
# Calculadora Científica (Scaffold)

Esta repo contiene un scaffold para una calculadora científica orientada a ingeniería.

Backend:
- FastAPI (puerto 8000)
- SymPy para álgebra simbólica, derivadas e integrales
- SQLite + SQLModel para guardar historial

Frontend:
- React + Vite (puerto 5173)
- Llamadas a la API para evaluar expresiones y ver historial

Comandos rápidos:

Backend dev:
  cd backend
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Frontend dev:
  cd calculadora-frontend
  npm install
  npm run dev

Docker:
  docker-compose up --build -d

API endpoints:
- POST /api/evaluate { expr: string, save?: boolean }
- POST /api/differentiate { expr, var?, order?, save? }
- POST /api/integrate { expr, var?, lower?, upper?, save? }
- GET /api/history
- DELETE /api/history/{id}

Notas de seguridad:
- sympify puede ejecutar código no deseado: en producción valida/sanea entradas y restringe funciones.
- Para multiusuario, añade autenticación y una base de datos robusta (Postgres).
