from pydantic import BaseModel, Field
from typing import Optional, Literal, List
from datetime import datetime
from decimal import Decimal
from bson import ObjectId
from .users import PyObjectId

class PaymentScreenshot(BaseModel):
    """付款截图记录"""
    url: str = Field(..., description="截图URL")
    uploaded_at: datetime = Field(default_factory=datetime.utcnow, description="上传时间")
    modification_number: int = Field(..., description="第几次修改时上传的")

class OrderModification(BaseModel):
    """订单修改记录"""
    modification_number: int = Field(..., description="修改次数")
    images: List[str] = Field(default_factory=list, description="本次修改的正文图片")
    description: str = Field(..., description="本次修改的描述")
    amount: Decimal = Field(..., description="本次修改的金额")
    currency: str = Field(..., description="本次修改的货币")
    is_child_urgent: bool = Field(default=False, description="本次修改的小孩危急选项")
    payment_screenshots: List[str] = Field(default_factory=list, description="本次修改的付款截图")
    modified_at: datetime = Field(default_factory=datetime.utcnow, description="修改时间")

class FortuneOrder(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    user_id: PyObjectId = Field(..., description="用户ID")
    order_number: str = Field(..., description="订单号")
    
    # 申请信息（当前版本，显示最新的内容）
    images: list[str] = Field(default_factory=list, description="上传图片URL列表，最多3张（最新版本）")
    description: str = Field(..., max_length=800, description="用户描述，最多800字（最新版本）")
    is_child_urgent: bool = Field(default=False, description="小孩危急选项（最新版本）")
    
    # 支付信息（当前版本）
    amount: Decimal = Field(..., description="金额（最新版本）")
    currency: Literal["CNY", "USD", "CAD", "SGD", "AUD"] = Field(..., description="货币（最新版本）")
    payment_status: Literal["pending", "paid", "refunded"] = Field(default="pending", description="支付状态")
    payment_id: Optional[str] = Field(None, description="支付平台订单ID")
    
    # 修改历史和限制
    modification_count: int = Field(default=0, description="已修改次数")
    max_modifications: int = Field(default=5, description="最大允许修改次数")
    modification_history: List[OrderModification] = Field(default_factory=list, description="修改历史记录")
    all_payment_screenshots: List[PaymentScreenshot] = Field(default_factory=list, description="所有付款截图历史")
    
    # 处理状态
    status: Literal["pending", "queued", "processing", "completed", "refunded", "cancelled"] = Field(default="pending", description="订单状态")
    queue_position: Optional[int] = Field(None, description="队列位置")
    queue_percentage: Optional[float] = Field(None, description="排队百分比")
    
    # AI关键词
    ai_keywords: Optional[str] = Field(None, description="AI生成的关键词")
    ai_generated_at: Optional[datetime] = Field(None, description="AI关键词生成时间")
    
    # 回复信息
    reply_content: Optional[str] = Field(None, description="算命师回复内容")
    reply_images: list[str] = Field(default_factory=list, description="回复图片URL列表")
    reply_draft: Optional[str] = Field(None, description="回复草稿")
    replied_by: Optional[PyObjectId] = Field(None, description="回复者ID")
    replied_at: Optional[datetime] = Field(None, description="回复时间")
    
    # 时间戳
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str, Decimal: str}
        
    @property
    def can_be_modified(self) -> bool:
        """检查订单是否可以修改"""
        return (
            self.status in ['pending', 'queued'] and 
            self.modification_count < self.max_modifications and
            self.status != 'refunded'
        )
        
    @property
    def remaining_modifications(self) -> int:
        """剩余可修改次数"""
        return max(0, self.max_modifications - self.modification_count)
        
    @property
    def priority_score(self) -> float:
        """计算优先级分数，用于排队排序"""
        base_score = float(self.amount)
        
        # 小孩危急加权
        if self.is_child_urgent:
            base_score *= 2.0
            
        # 时间因子（越早提交分数越高）
        hours_since_creation = (datetime.utcnow() - self.created_at).total_seconds() / 3600
        time_factor = 1.0 + (hours_since_creation * 0.1)
        
        return base_score * time_factor 