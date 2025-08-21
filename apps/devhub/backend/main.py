from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
import os
from pymongo import MongoClient

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("MONGO_DB", "devhub")
COLLECTION = os.getenv("MONGO_COLLECTION", "orders")

client = MongoClient(MONGO_URI)
db = client[DB_NAME]
orders = db[COLLECTION]

app = FastAPI(title="DevHub API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class EnvOrder(BaseModel):
    owner: str = Field(..., description="Developer name")
    project: str = Field(..., description="Project identifier")
    language: str = Field(..., description="Primary language")
    size: str = Field(..., description="Env size: small/medium/large")
    notes: Optional[str] = None

class EnvOrderOut(EnvOrder):
    id: str
    created_at: datetime

@app.get("/api/healthz")
def healthz():
    return {"status": "ok"}

@app.post("/api/orders", response_model=EnvOrderOut)
def create_order(req: EnvOrder):
    doc = req.dict()
    doc["created_at"] = datetime.utcnow()
    result = orders.insert_one(doc)
    return {"id": str(result.inserted_id), **doc}

@app.get("/api/orders", response_model=List[EnvOrderOut])
def list_orders():
    docs = []
    for d in orders.find().sort("created_at", -1):
        d["id"] = str(d.pop("_id"))
        docs.append(d)
    return docs
