from django.urls import path
from .views import TrackerDataCreateView, LatestTrackerDataView, DeviceConfigView

urlpatterns = [
    path('location/', TrackerDataCreateView.as_view(), name='send-location'),
    path('location/latest/', LatestTrackerDataView.as_view(), name='latest-location'),
    path('config/', DeviceConfigView.as_view(), name='device-config'),
]
