from fastapi import Header, HTTPException, status
from app.core.security import decode_access_token
from typing import List

def verify_token_and_role(authorization: str = Header(None), allowed_roles: List[str] = None):
    """
    ميدلوير الأمان والحماية المتقدمة:
    يمنع أي مستخدم أو هكر من الوصول إلى أي وظيفة بدون رمز دخول صحيح وصلاحيات مناسبة لدوره (CLIENT, VENDOR, ADMIN).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز الدخول مفقود أو غير صحيح. يرجى تسجيل الدخول أولاً."
        )

    token = authorization.split(" ")[1]
    payload = decode_access_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز الدخول غير صالح أو منتهي الصلاحية."
        )

    user_role = payload.get("role")
    if allowed_roles and user_role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"غير مصرح لك بالوصول لهذه الصفحة/الوظيفة. الصلاحية المطلوبة: {allowed_roles}"
        )

    return payload
