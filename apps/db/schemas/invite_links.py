from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime
from bson import ObjectId
from .users import PyObjectId

class InviteLink(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    code: str = Field(..., description="邀请码")
    created_by: PyObjectId = Field(..., description="创建者用户ID")
    max_uses: int = Field(default=1, description="最大使用次数")
    current_uses: int = Field(default=0, description="当前使用次数")
    expires_at: datetime = Field(..., description="过期时间")
    is_active: bool = Field(default=True, description="是否激活")
    target_role: Literal["member"] = Field(default="member", description="目标角色")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    used_by: list[PyObjectId] = Field(default_factory=list, description="使用者列表")
    
    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
        
    @property
    def is_valid(self) -> bool:
        """检查邀请链接是否有效"""
        return (
            self.is_active and 
            self.current_uses < self.max_uses and 
            self.expires_at > datetime.utcnow()
        ) 