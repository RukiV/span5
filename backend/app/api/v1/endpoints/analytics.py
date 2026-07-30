from fastapi import APIRouter, Depends
from sqlmodel import Session
from datetime import datetime

from ....db.database import getSession
from ....auth.permissions import get_current_user, require_right
from ....models.user import User
from ....models.analytics import AnalyticsRequest, AnalyticsResponse, Suggestion, ChatRequest, ChatResponse
from ....services.analytics_service import generate_insights, _execute_suggestion, answer_chat_query

router = APIRouter()


@router.post("/analytics/insights", response_model=AnalyticsResponse)
def get_insights(
    req: AnalyticsRequest,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("analytics.view")),
):
    date_from = None
    date_to = None
    if req.date_from:
        date_from = datetime.fromisoformat(req.date_from)
    if req.date_to:
        date_to = datetime.fromisoformat(req.date_to)
    return generate_insights(req.page, session, date_from, date_to)


@router.post("/analytics/suggestions/execute")
def execute_suggestion(
    suggestion: Suggestion,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("analytics.view")),
):
    return _execute_suggestion(suggestion, session, user.user_id)


@router.post("/analytics/chat", response_model=ChatResponse)
def chat_with_analytics(
    req: ChatRequest,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("analytics.view")),
):
    answer = answer_chat_query(req.page, req.query, req.history, session)
    return ChatResponse(answer=answer)