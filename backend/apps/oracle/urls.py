from django.urls import path

from . import api

urlpatterns = [
    path("personalities/", api.personalities),
    path("sessions/", api.Sessions.as_view()),
    path("sessions/<uuid:session_id>/", api.session),
    path("sessions/<uuid:session_id>/cards/", api.cards),
    path("sessions/<uuid:session_id>/synthesize/", api.synthesize),
    path("sessions/<uuid:session_id>/messages/", api.messages),
    path("sessions/<uuid:session_id>/clarifiers/<int:position>/", api.clarify),
]
