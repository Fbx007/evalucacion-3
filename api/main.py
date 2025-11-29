
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy import create_engine, Column, Integer, String, TIMESTAMP, ForeignKey, DECIMAL, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List, Optional
import hashlib 
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles 
import shutil
import os
import requests 

#1 CONFIGURACIoN INICIAL
# configurado a la bd 'bd_paquexpress' 
DATABASE_URL = "mysql+pymysql://root:root@localhost:3306/bd_paquexpress" 
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True) 

app = FastAPI(title="API_PAQUEXPRESS_U3")

# la configuracion de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"], 
    allow_headers=["*"], 
)

# crearla carpeta estatica para las fotos 
app.mount(f"/{UPLOAD_DIR}", StaticFiles(directory=UPLOAD_DIR), name=UPLOAD_DIR)

#2 MODELOS DE BASE DE DATOS SQLAlchemy 
#los nmbres de tabla 
class Agente(Base):
    __tablename__ = "agentes"
    id_agente = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    username = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False) 

class Paquete(Base):
    __tablename__ = "paquetes"
    id_paquete = Column(String(50), primary_key=True) 
    direccion_destino = Column(String(255), nullable=False) 
    id_agente_asignado = Column(Integer, ForeignKey("agentes.id_agente"), nullable=True)
    estado = Column(Enum('ASIGNADO', 'ENTREGADO', 'FALLIDO'), default='ASIGNADO', nullable=False)

class Entrega(Base):
    __tablename__ = "entregas"
    id_registro = Column(Integer, primary_key=True, index=True)
    id_paquete = Column(String(50), ForeignKey("paquetes.id_paquete"), unique=True, nullable=False)
    fecha_hora = Column(TIMESTAMP, default=datetime.utcnow)
    latitud = Column(DECIMAL(10, 8), nullable=False)
    longitud = Column(DECIMAL(10, 8), nullable=False)
    foto_evidencia_url = Column(String(255), nullable=False)

#3 MODELOS DE VALIDACION Pydantic
class RegisterModel(BaseModel):
    username: str
    password: str
    nombre: str

class LoginModel(BaseModel):
    username: str
    password: str

class PaqueteAsignadoSchema(BaseModel):
    id_paquete: str
    direccion_destino: str
    estado: str
    
    class Config:
        from_attributes = True

class PaqueteInsertModel(BaseModel):
    id_paquete: str
    direccion_destino: str
    id_agente_asignado: Optional[int] = None 

class PaqueteAsignacionModel(BaseModel):
    id_paquete: str
    id_agente: int


# 4. UTILIDADES Y DEPENDENCIAS
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def md5_hash(password: str) -> str:
    return hashlib.md5(password.encode()).hexdigest() 

# 5 LOSENDPOINTS DE LA API 

@app.get("/")
def health_check():
    return {"status": "activo", "api": "Paquexpress Entregas", "version": "U3"}

#  1er endpoint de Registro de Agente 
@app.post("/register/")
def register(data: RegisterModel, db: Session = Depends(get_db)):
    """Registra un nuevo agente con contraseña hasheada MD5."""
    hashed_pw = md5_hash(data.password)
    agente = Agente(
        username=data.username,
        password_hash=hashed_pw, 
        nombre=data.nombre
    )
    
    try:
        db.add(agente)
        db.commit()
        db.refresh(agente) 
        
        
        return {"msg": "Agente registrado. Debe asignar paquetes manualmente.", "id_agente": agente.id_agente}
    except Exception as e:
        db.rollback()
        if "Duplicate entry" in str(e):
             raise HTTPException(status_code=400, detail="El nombre de usuario ya existe.")
        raise HTTPException(status_code=500, detail=f"Error interno al registrar: {str(e)}")


# el 2do endpoint es de Login de Agente 
@app.post("/login/")
def login(data: LoginModel, db: Session = Depends(get_db)):
    """Inicio de sesion seguro para el agente."""
    user = db.query(Agente).filter(Agente.username == data.username).first()
    
    if not user or user.password_hash != md5_hash(data.password):
        raise HTTPException(status_code=401, detail="Las credenciales son invalidas")
    
    return {"msg": "EL login ha sido exitoso", "id_agente": user.id_agente}


# el 3er endpointes de  Obtener lista de paquetes ASIGNADOS 
@app.get("/paquetes/{id_agente}", response_model=List[PaqueteAsignadoSchema])
def get_paquetes_asignados(id_agente: int, db: Session = Depends(get_db)):
    """Obtiene los paquetes ASIGNADOS PENDIENTES de entrega para un agente."""
    paquetes = db.query(Paquete).filter(
        Paquete.id_agente_asignado == id_agente,
        Paquete.estado == 'ASIGNADO'
    ).all()
    
    if not paquetes:
        raise HTTPException(status_code=404, detail="No hay paquetes ASIGNADOS para este agente.")
    
    return paquetes


# el 4to endpoint es de el Insertar Paquetes de prueba 
@app.post("/insert_paquete/")
def insert_paquete(data: PaqueteInsertModel, db: Session = Depends(get_db)):
    """Inserta un nuevo paquete en la bd."""
    paquete = Paquete(
        id_paquete=data.id_paquete,
        direccion_destino=data.direccion_destino,
        id_agente_asignado=data.id_agente_asignado,
    )
    try:
        db.add(paquete)
        db.commit()
        db.refresh(paquete)
        return {"msg": f"EL Paquete: {data.id_paquete} ha sido insertado.", "id_paquete": data.id_paquete}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error al insertar paquete: {str(e)}")

# el 5to endpoint de Asignar Paquete a Agente
@app.post("/asignar_paquete/")
def asignar_paquete(data: PaqueteAsignacionModel, db: Session = Depends(get_db)):
    """Asigna un paquete existente a un agente especifico."""
    paquete = db.query(Paquete).filter(Paquete.id_paquete == data.id_paquete).first()
    agente = db.query(Agente).filter(Agente.id_agente == data.id_agente).first()

    if not paquete:
        raise HTTPException(status_code=404, detail=f"Paquete con ID {data.id_paquete} no encontrado.")
    if not agente:
        raise HTTPException(status_code=404, detail=f"Agente con ID {data.id_agente} no encontrado.")

    paquete.id_agente_asignado = data.id_agente
    paquete.estado = 'ASIGNADO' # esto parasegurar estado para entrega
    
    db.commit()
    return {"msg": f"Paquete {data.id_paquete} asignado exitosamente al Agente ID {data.id_agente}."}


# Endpoint: Registro de Entrega la combinacion de P9:GPS y P10:Archivos)
@app.post("/entrega/")
async def registrar_entrega(
    id_paquete: str = Form(...), 
    latitud: float = Form(...),   
    longitud: float = Form(...),  
    file: UploadFile = File(...), 
    db: Session = Depends(get_db)
):
    """Registra la entrega de un paquete con evidencia fotografica y GPS."""
    
    # validar el paquete y que si ya esta entregado
    paquete = db.query(Paquete).filter(Paquete.id_paquete == id_paquete).first()
    if not paquete:
        raise HTTPException(status_code=404, detail=f"Paquete con ID {id_paquete} no encontrado.")
    if paquete.estado == 'ENTREGADO':
        raise HTTPException(status_code=400, detail="El paquete ya fue marcado como entregado.")

    # se guarda la foto
    file_extension = os.path.splitext(file.filename)[1] 
    file_name_clean = f"{id_paquete}_evidencia_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}{file_extension}"
    ruta_servidor = os.path.join(UPLOAD_DIR, file_name_clean)
    
    try:
        with open(ruta_servidor, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # registrar la entrega en la bd
        nueva_entrega = Entrega(
            id_paquete=id_paquete,
            fecha_hora=datetime.utcnow(),
            latitud=latitud,
            longitud=longitud,
            foto_evidencia_url=f"/{UPLOAD_DIR}/{file_name_clean}" 
        )
        
        # se actualizar el estado del paquete a Paquete entregado
        paquete.estado = 'ENTREGADO'
        
        db.add(nueva_entrega)
        db.commit()
        db.refresh(nueva_entrega)
        
        return {
            "msg": "El paaquete ha sido entregado y con evidencia guardada",
            "id_registro": nueva_entrega.id_registro,
            "foto_url": nueva_entrega.foto_evidencia_url,
            "lat": latitud,
            "lon": longitud
        }

    except Exception as e:
        db.rollback()
        if os.path.exists(ruta_servidor):
            os.remove(ruta_servidor)
        raise HTTPException(status_code=500, detail=f"Error al procesar la entrega: {str(e)}")