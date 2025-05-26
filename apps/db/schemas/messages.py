from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime
from bson import ObjectId
from .users import PyObjectId

class Message(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    sender_id: PyObjectId = Field(..., description="发送者用户ID")
    recipient_id: Optional[PyObjectId] = Field(None, description="接收者用户ID，群聊时为None")
    room_id: str = Field(..., description="房间ID")
    message_type: Literal["text", "image", "system"] = Field(default="text", description="消息类型")
    content: str = Field(..., description="消息内容")
    attachments: list[str] = Field(default_factory=list, description="附件URL列表")
    is_private: bool = Field(default=False, description="是否为私信")
    is_deleted: bool = Field(default=False, description="是否已删除")
    read_by: list[PyObjectId] = Field(default_factory=list, description="已读用户列表")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    deleted_at: Optional[datetime] = None
    
    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str} 