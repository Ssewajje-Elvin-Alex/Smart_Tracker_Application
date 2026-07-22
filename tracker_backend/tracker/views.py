from django.conf import settings
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeviceConfig, TrackerData
from .serializers import DeviceConfigSerializer, TrackerDataSerializer


class TrackerDataCreateView(generics.CreateAPIView):
    """ESP32 posts each GPS/geofence/emergency event here."""

    queryset = TrackerData.objects.all()
    serializer_class = TrackerDataSerializer

    def create(self, request, *args, **kwargs):
        submitted_key = request.data.get("api_key")

        if not settings.DEVICE_API_KEY:
            raise PermissionDenied("Server has no DEVICE_API_KEY configured.")

        if submitted_key != settings.DEVICE_API_KEY:
            raise PermissionDenied("Invalid or missing api_key.")

        response = super().create(request, *args, **kwargs)

        # Only clear a pending Refresh request when the device returns the exact
        # request ID. Ordinary periodic location updates must not consume it.
        submitted_request_id = request.data.get("location_request_id")
        if response.status_code == status.HTTP_201_CREATED and submitted_request_id:
            config, _ = DeviceConfig.objects.get_or_create(
                device_id=request.data.get("device_id", "SMART-GUARDIAN-001")
            )
            try:
                request_id = int(submitted_request_id)
            except (TypeError, ValueError):
                request_id = -1

            if request_id == config.location_request_id:
                config.location_request_pending = False
                config.save(update_fields=["location_request_pending", "updated_at"])

        return response


class LatestTrackerDataView(generics.RetrieveAPIView):
    """Flutter app polls this for the most recent event/location."""

    queryset = TrackerData.objects.all()
    serializer_class = TrackerDataSerializer

    def get_object(self):
        obj = TrackerData.objects.order_by("-timestamp").first()
        if obj is None:
            from rest_framework.exceptions import NotFound

            raise NotFound("No tracker data has been received yet.")
        return obj

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        response["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response["Pragma"] = "no-cache"
        return response


class DeviceConfigView(generics.RetrieveUpdateAPIView):
    """
    GET -> app/ESP32 reads settings and pending device commands.
    PUT/PATCH -> guardian saves new settings from the app.
    """

    serializer_class = DeviceConfigSerializer

    def get_object(self):
        obj, _ = DeviceConfig.objects.get_or_create(
            device_id="SMART-GUARDIAN-001"
        )
        return obj

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        response["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response["Pragma"] = "no-cache"
        return response


class LocationRefreshRequestView(APIView):
    """Guardian app asks the ESP32 to POST a fresh GPS location now."""

    def post(self, request, *args, **kwargs):
        config, _ = DeviceConfig.objects.get_or_create(
            device_id="SMART-GUARDIAN-001"
        )
        config.location_request_id += 1
        config.location_request_pending = True
        config.location_request_at = timezone.now()
        config.save(
            update_fields=[
                "location_request_id",
                "location_request_pending",
                "location_request_at",
                "updated_at",
            ]
        )

        return Response(
            {
                "location_request_id": config.location_request_id,
                "location_request_pending": True,
                "requested_at": config.location_request_at,
            },
            status=status.HTTP_202_ACCEPTED,
        )
