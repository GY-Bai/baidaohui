from pydantic import BaseModel, Field
from typing import Optional, Literal, Any
from datetime import datetime
from bson import ObjectId
from .users import PyObjectId

class ShopEvent(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    event_type: Literal["product_created", "product_updated", "product_deleted", "order_created", "order_updated", "seller_registered", "seller_approved"] = Field(..., description="事件类型")
    user_id: Optional[PyObjectId] = Field(None, description="相关用户ID")
    prestashop_id: Optional[int] = Field(None, description="PrestaShop中的ID")
    
    # 事件数据
    event_data: dict[str, Any] = Field(default_factory=dict, description="事件相关数据")
    
    # 处理状态
    processed: bool = Field(default=False, description="是否已处理")
    processed_at: Optional[datetime] = Field(None, description="处理时间")
    error_message: Optional[str] = Field(None, description="错误信息")
    retry_count: int = Field(default=0, description="重试次数")
    
    # 时间戳
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str} 