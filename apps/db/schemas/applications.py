from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime
from bson import ObjectId
from .users import PyObjectId

class Application(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    user_id: PyObjectId = Field(..., description="申请用户ID")
    application_type: Literal["verification", "seller"] = Field(..., description="申请类型")
    status: Literal["pending", "approved", "rejected"] = Field(default="pending", description="申请状态")
    content: dict = Field(default_factory=dict, description="申请内容")
    submitted_at: datetime = Field(default_factory=datetime.utcnow)
    reviewed_at: Optional[datetime] = None
    reviewed_by: Optional[PyObjectId] = None
    review_notes: Optional[str] = None
    
    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str} 