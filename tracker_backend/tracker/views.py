from django.conf import settings
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from .models import TrackerData
from .serializers import TrackerDataSerializer


class TrackerDataCreateView(generics.CreateAPIView):
    """ESP32 posts each GPS/geofence/emergency event here."""

    queryset = TrackerData.objects.all()
    serializer_class = TrackerDataSerializer

    def create(self, request, *args, **kwargs):
        submitted_key = request.data.get("api_key")

        if not settings.DEVICE_API_KEY:
            # Fail closed: refuse to accept data if no key is configured
            # server-side, rather than silently accepting anything.
            raise PermissionDenied("Server has no DEVICE_API_KEY configured.")

        if submitted_key != settings.DEVICE_API_KEY:
            raise PermissionDenied("Invalid or missing api_key.")

        return super().create(request, *args, **kwargs)


class LatestTrackerDataView(generics.RetrieveAPIView):
    """Flutter app polls this for the most recent event."""

    queryset = TrackerData.objects.all()
    serializer_class = TrackerDataSerializer

    def get_object(self):
        obj = TrackerData.objects.order_by("-timestamp").first()
        if obj is None:
            from rest_framework.exceptions import NotFound
            raise NotFound("No tracker data has been received yet.")
        return obj
