from django.conf import settings
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from .models import TrackerData, DeviceConfig
from .serializers import TrackerDataSerializer, DeviceConfigSerializer


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


class DeviceConfigView(generics.RetrieveUpdateAPIView):
    """
    GET  -> app shows current settings, ESP32 polls this to check for changes.
    PUT/PATCH -> guardian saves new settings from the app.

    Single-device project: there's always exactly one config row, created
    with defaults on first request if it doesn't exist yet.

    NOTE: unlike /location/, this endpoint does not check DEVICE_API_KEY —
    the app has no login/auth system yet, so anyone with the URL can read
    or change settings. Fine for a prototype/demo; add real auth before
    using this with a real child's data.
    """

    serializer_class = DeviceConfigSerializer

    def get_object(self):
        obj, _ = DeviceConfig.objects.get_or_create(
            device_id="SMART-GUARDIAN-001"
        )
        return obj
