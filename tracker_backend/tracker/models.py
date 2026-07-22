from django.db import models

EVENT_TYPE_CHOICES = [
    ("LOCATION_UPDATE", "Location Update"),
    ("EMERGENCY_BUTTON", "Emergency Button"),
    ("GEOFENCE_EXIT", "Geofence Exit"),
    ("GEOFENCE_RETURN", "Geofence Return"),
    ("BACKEND_TEST", "Backend Test"),
]


class TrackerData(models.Model):
    device_id = models.CharField(max_length=64, default="SMART-GUARDIAN-001")
    device_name = models.CharField(max_length=64, blank=True, default="")

    event_type = models.CharField(
        max_length=32,
        choices=EVENT_TYPE_CHOICES,
        default="LOCATION_UPDATE",
    )

    latitude = models.FloatField()
    longitude = models.FloatField()
    distance_metres = models.FloatField(null=True, blank=True)
    satellites = models.IntegerField(null=True, blank=True)
    map_url = models.URLField(max_length=255, blank=True, default="")
    battery_level = models.IntegerField(default=100)

    # The ESP32 sends these state flags on every location record so the app can
    # remain in EMERGENCY state without repeating emergency event types.
    emergency_active = models.BooleanField(default=False)
    geofence_outside = models.BooleanField(default=False)

    # Present only when a location was posted in response to the app's Refresh
    # command. It lets the app verify that it received the requested fresh fix.
    location_request_id = models.PositiveBigIntegerField(null=True, blank=True)

    timestamp = models.DateTimeField(auto_now_add=True)

    @property
    def emergency(self) -> bool:
        return (
            self.emergency_active
            or self.geofence_outside
            or self.event_type in {"EMERGENCY_BUTTON", "GEOFENCE_EXIT"}
        )

    def __str__(self):
        return (
            f"{self.device_id} [{self.event_type}] "
            f"({self.latitude}, {self.longitude})"
        )

    class Meta:
        ordering = ["-timestamp"]


class DeviceConfig(models.Model):
    """Guardian-editable settings and lightweight device commands."""

    device_id = models.CharField(
        max_length=64,
        unique=True,
        default="SMART-GUARDIAN-001",
    )

    guardian_phone = models.CharField(max_length=20, blank=True, default="")
    device_phone = models.CharField(max_length=20, blank=True, default="")

    geofence_latitude = models.FloatField(default=0.0)
    geofence_longitude = models.FloatField(default=0.0)
    geofence_radius_m = models.FloatField(default=500.0)

    # The app increments this counter when Refresh is pressed. The ESP32 polls
    # the config endpoint, sees the pending request and POSTs a fresh GPS fix
    # carrying the same request ID.
    location_request_id = models.PositiveBigIntegerField(default=0)
    location_request_pending = models.BooleanField(default=False)
    location_request_at = models.DateTimeField(null=True, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Config for {self.device_id}"
