from django.db import models

EVENT_TYPE_CHOICES = [
    ("EMERGENCY_BUTTON", "Emergency Button"),
    ("GEOFENCE_EXIT", "Geofence Exit"),
    ("GEOFENCE_RETURN", "Geofence Return"),
    ("BACKEND_TEST", "Backend Test"),
]

# Event types that should flip the app into "EMERGENCY" state.
EMERGENCY_EVENT_TYPES = {"EMERGENCY_BUTTON", "GEOFENCE_EXIT"}


class TrackerData(models.Model):
    device_id = models.CharField(max_length=64, default="SMART-GUARDIAN-001")
    device_name = models.CharField(max_length=64, blank=True, default="")

    event_type = models.CharField(
        max_length=32,
        choices=EVENT_TYPE_CHOICES,
        default="BACKEND_TEST",
    )

    latitude = models.FloatField()
    longitude = models.FloatField()
    distance_metres = models.FloatField(null=True, blank=True)
    satellites = models.IntegerField(null=True, blank=True)
    map_url = models.URLField(max_length=255, blank=True, default="")

    # Kept for the app UI; the sketch doesn't send this yet, so it just
    # keeps whatever was last recorded (see serializer default handling).
    battery_level = models.IntegerField(default=100)

    timestamp = models.DateTimeField(auto_now_add=True)

    @property
    def emergency(self) -> bool:
        return self.event_type in EMERGENCY_EVENT_TYPES

    def __str__(self):
        return f"{self.device_id} [{self.event_type}] ({self.latitude}, {self.longitude})"

    class Meta:
        ordering = ["-timestamp"]
