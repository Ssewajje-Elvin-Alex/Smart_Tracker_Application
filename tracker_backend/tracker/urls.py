from django.urls import path
from .views import TrackerDataCreateView,LatestTrackerDataView
urlpatterns=[
    path('location/',TrackerDataCreateView.as_view(),name='send-location'),
    path('location/latest/',LatestTrackerDataView.as_view(),name='latest-location')
]