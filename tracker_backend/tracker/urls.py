from django.urls import path

from .views import (
    DeviceConfigView,
    LatestTrackerDataView,
    LocationRefreshRequestView,
    TrackerDataCreateView,
)

urlpatterns = [
    path("location/", TrackerDataCreateView.as_view(), name="send-location"),
    path(
        "location/latest/",
        LatestTrackerDataView.as_view(),
        name="latest-location",
    ),
    path("config/", DeviceConfigView.as_view(), name="device-config"),
    path(
        "config/request-location/",
        LocationRefreshRequestView.as_view(),
        name="request-location-refresh",
    ),
]
