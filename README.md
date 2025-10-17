# 1. Clonar repositorio (si no lo tienes local)
clon git https://github.com/cgabrielaramos-web/Calculadora-cientifica.git
cd Calculadora científica

# 2. Crear rama de trabajo
git checkout -b feature/calculadora científica

# 3. Backend: crear estructura y entorno virtual (Linux/macOS)
mkdir backend
backend de cd
python3 -m venv .venv
fuente .venv/bin/activate

# 4. Crear el archivo requisitos.txt (ver más abajo) e instalar dependencias
printf "fastapi\nuvicorn[estándar]\nsympy\nsqlmodel\npython-dotenv\n" > requisitos.txt
pip install -r requisitos.txt

# 5. Crear estructura del backend
mkdir -p aplicación
# (los archivos de ejemplo están listados abajo; puedes crear main.py y models.py)
# 6. Ejecutar servidor de desarrollo (backend)
aplicación uvicorn.main:app --reload --host 0.0.0.0 --puerto 8000 y

# 7. Frontend: desde la raíz del repositorio crea app con Vite + React + TypeScript
cd ..
npm create vite@latest calculadora-frontend -- --template react-ts
interfaz de calculadora de cd
instalación de npm
# instalar axios y react-katex (opcional para visualización de fórmulas)
npm instalar axios react-katex katex

# 8. Ejecutar frontend en modo dev (puerto 5173)
npm ejecuta dev &

# 9. Git: agregar, confirmar y empujar la rama
cd ../
git agregar .
git commit -m "feat: andamiaje backend (FastAPI + SymPy) y frontend (Vite React)"
git push -u origin feature/calculadora científica

# 10. Opcional: compilación y producción con Docker Compose
# (ver docker-compose.yml abajo)
docker-compose up --build -d
